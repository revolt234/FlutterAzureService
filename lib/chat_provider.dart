import 'dart:convert';
import 'dart:io';
import 'package:app_tesi/services/azure_tts_service.dart';
import 'package:app_tesi/services/azure_openai_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatProvider with ChangeNotifier {
  List<Map<String, dynamic>> chatHistory = [];
  List<Map<String, dynamic>> currentChatMessages = [];
  String currentChatId = "";

  late AzureOpenAIService openAIService;
  late AzureTTSService ttsService;
  final AudioPlayer audioPlayer = AudioPlayer();

  int? activeChatIndex;
  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _isLoading = false;

  // Configurazione da .env
  String get openAiEndpoint => dotenv.env['AZURE_OPENAI_ENDPOINT'] ?? '';
  String get openAiKey => dotenv.env['AZURE_OPENAI_KEY'] ?? '';
  String get deploymentName =>
      dotenv.env['AZURE_OPENAI_DEPLOYMENT'] ?? 'gpt-4o-mini';
  String get searchEndpoint => dotenv.env['AZURE_SEARCH_ENDPOINT'] ?? '';
  String get searchKey => dotenv.env['AZURE_SEARCH_KEY'] ?? '';
  String get searchIndex =>
      dotenv.env['AZURE_SEARCH_INDEX'] ?? 'azureblob-index';

  ChatProvider() {
    initialize();
    _initServices();
  }

  bool get isSpeaking => _isSpeaking;
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    if (!_isInitialized) {
      await _loadChatHistory();
      _isInitialized = true;
    }
  }

  void _initServices() {
    ttsService = AzureTTSService(
      subscriptionKey: dotenv.env['AZURE_KEY'] ?? '',
      region: 'italynorth',
      voiceName: 'it-IT-ElsaNeural',
    );

    openAIService = AzureOpenAIService(
      openAiEndpoint: openAiEndpoint,
      openAiApiKey: openAiKey,
      deploymentName: deploymentName,
      searchEndpoint: searchEndpoint,
      searchApiKey: searchKey,
      searchIndexName: searchIndex,
    );

    audioPlayer.setReleaseMode(ReleaseMode.release);
  }

  @override
  void dispose() {
    ttsService.dispose();
    audioPlayer.dispose();
    super.dispose();
  }

  String _generateChatId() => DateTime.now().millisecondsSinceEpoch.toString();

  void startNewChat() {
    currentChatMessages.clear();
    currentChatId = _generateChatId();
    activeChatIndex = null;
    notifyListeners();
  }

  Future<void> submitUserMessage(String content) async {
    if (content.trim().isEmpty) return;

    // Aggiungi messaggio utente
    currentChatMessages.add({
      "role": "user",
      "content": content,
      "timestamp": DateTime.now().toIso8601String(),
      "isFromUser": true,
    });
    notifyListeners();

    try {
      _isLoading = true;
      notifyListeners();

      // Ottieni risposta da Azure OpenAI con contesto dal CSV
      final response =
          await openAIService.sendMessage(content, currentChatMessages);

      // Aggiungi risposta al bot
      currentChatMessages.add({
        "role": "assistant",
        "content": response,
        "timestamp": DateTime.now().toIso8601String(),
        "isFromUser": false,
      });

      // Riproduci la risposta vocalmente
      await Future.delayed(const Duration(milliseconds: 300));
      _isSpeaking = true;
      notifyListeners();

      await ttsService.speak(response);
    } catch (e) {
      _showError('Impossibile ottenere una risposta: ${e.toString()}');
      debugPrint('Error in submitUserMessage: $e');
    } finally {
      _isLoading = false;
      _isSpeaking = false;
      notifyListeners();
      await saveCurrentChat();
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await ttsService.audioPlayer.stop();
      _isSpeaking = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping speech: $e');
    }
  }

  void _showError(String message) {
    currentChatMessages.add({
      "role": "assistant",
      "content": "⚠️ $message",
      "timestamp": DateTime.now().toIso8601String(),
      "isFromUser": false,
    });
    notifyListeners();
  }

  // Gestione cronologia chat
  Future<void> saveCurrentChat() async {
    if (currentChatMessages.isEmpty) return;

    final title = currentChatMessages
            .where((msg) => msg['role'] == 'user')
            .firstOrNull?['content'] ??
        'Nuova Chat';

    final chatData = {
      'chatId': currentChatId,
      'title': title.length > 30 ? '${title.substring(0, 30)}...' : title,
      'messages': List<Map<String, dynamic>>.from(currentChatMessages),
      'lastUpdated': DateTime.now().toIso8601String(),
    };

    if (activeChatIndex != null) {
      chatHistory[activeChatIndex!] = chatData;
    } else {
      chatHistory.add(chatData);
      activeChatIndex = chatHistory.length - 1;
    }

    await _saveChatHistoryLocally();
  }

  Future<void> _saveChatHistoryLocally() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/chat_history.json');
      await file.writeAsString(json.encode(chatHistory));
    } catch (e) {
      debugPrint('Error saving chat history: $e');
      _showError('Impossibile salvare la cronologia');
    }
  }

  Future<void> _loadChatHistory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/chat_history.json');

      if (await file.exists()) {
        final contents = await file.readAsString();
        chatHistory = List<Map<String, dynamic>>.from(json.decode(contents));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading chat history: $e');
    }
  }

  void loadSpecificChat(int index) {
    if (index < 0 || index >= chatHistory.length) return;

    final chat = chatHistory[index];
    currentChatMessages =
        List<Map<String, dynamic>>.from(chat['messages'] ?? []);
    currentChatId = chat['chatId']?.toString() ?? _generateChatId();
    activeChatIndex = index;
    notifyListeners();
  }

  Future<void> deleteChat(int index) async {
    if (index < 0 || index >= chatHistory.length) return;

    chatHistory.removeAt(index);
    if (activeChatIndex == index) {
      startNewChat();
    } else if (activeChatIndex != null && activeChatIndex! > index) {
      activeChatIndex = activeChatIndex! - 1;
    }
    await _saveChatHistoryLocally();
    notifyListeners();
  }

  // Metodo per verificare la connessione ai servizi
  Future<bool> testConnections() async {
    try {
      // Test Azure OpenAI
      final modelTest = await openAIService.sendMessage("Test connection", []);
      if (modelTest.isEmpty) return false;

      // Test Azure AI Search
      final searchTest = await openAIService.sendMessage("Cerca 'test'", []);

      return true;
    } catch (e) {
      debugPrint('Connection test failed: $e');
      return false;
    }
  }
}
