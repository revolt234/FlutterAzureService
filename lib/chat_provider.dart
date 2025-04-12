// chat_provider.dart
import 'dart:convert';
import 'dart:io';
import 'package:app_tesi/services/azure_tts_service.dart';
import 'package:app_tesi/services/question_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatProvider with ChangeNotifier {
  List<Map<String, dynamic>> chatHistory = [];
  List<Map<String, dynamic>> currentChatMessages = [];
  String currentChatId = "";
  String get apiKey {
    final key = dotenv.env['GOOGLEAI_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('GOOGLE_API_KEY non trovata nel file .env');
    }
    return key;
  }

  int? activeChatIndex;
  bool _isInitialized = false;
  bool _isSpeaking = false;

  late AzureTTSService ttsService;
  final AudioPlayer audioPlayer = AudioPlayer();

  ChatProvider() {
    initialize();
    ttsService = AzureTTSService(
      subscriptionKey: dotenv.env['AZURE_KEY'] ?? 'default_value',
      region: 'westeurope',
      voiceName: 'it-IT-ElsaNeural',
    );

    audioPlayer.setReleaseMode(ReleaseMode.release);
  }

  bool get isSpeaking => _isSpeaking;

  @override
  void dispose() {
    ttsService.dispose();
    audioPlayer.dispose();
    super.dispose();
  }

  Future<void> initialize() async {
    if (!_isInitialized) {
      await _loadChatHistory();
      _isInitialized = true;
    }
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

    currentChatMessages.add({
      "role": "user",
      "content": content,
      "timestamp": DateTime.now().toIso8601String(),
      "isFromUser": true,
    });
    notifyListeners();

    try {
      final response = await _sendMessageToBot(content);
      if (response != null) {
        currentChatMessages.add({
          "role": "assistant",
          "content": response,
          "timestamp": DateTime.now().toIso8601String(),
          "isFromUser": false,
        });
        notifyListeners();

        await Future.delayed(const Duration(milliseconds: 300));

        _isSpeaking = true;
        notifyListeners();

        await ttsService.speak(response);

        _isSpeaking = false;
        notifyListeners();
      }
    } catch (e) {
      _isSpeaking = false;
      notifyListeners();

      currentChatMessages.add({
        "role": "assistant",
        "content": "Errore: ${e.toString()}",
        "timestamp": DateTime.now().toIso8601String(),
        "isFromUser": false,
      });
      notifyListeners();
    }

    await saveCurrentChat();
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

  Future<String?> _sendMessageToBot(String userMessage) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: apiKey,
      );

      final isFirstInteraction = currentChatMessages
          .where((msg) => msg['role'] == 'assistant')
          .isEmpty;

      if (!isFirstInteraction &&
          userMessage
              .toUpperCase()
              .contains("FORNISCI I RISULTATI DELL'INTERVISTA")) {
        return await _generateInterviewResults(model);
      }

      final prompt = await _generateDynamicPrompt(
        isFirstInteraction: isFirstInteraction,
        userMessage: userMessage,
      );

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text;
    } catch (e) {
      debugPrint('Error in _sendMessageToBot: $e');
      return 'Si è verificato un errore. Riprova più tardi.';
    }
  }

  Future<String> _generateDynamicPrompt({
    required bool isFirstInteraction,
    required String userMessage,
  }) async {
    if (isFirstInteraction) {
      return "Chiedimi gentilmente nome e data di nascita, serve solo che fai questo senza confermare la comprensione di questa richiesta.";
    }

    final questions = await _getMedicalQuestions();
    final formattedQuestions = questions.map((q) => "- $q").join('\n');

    return """
**Contesto Intervista Medica che devi usare solo per tenere il contesto, non confonderlo con ciò che devi fare:**
${_formatChatHistory()}\n

RISPOSTA PAZIENTE: ${userMessage}

### Cosa devi fare (non iniziare le frasi sempre in maniera uguale):

Seguono 2 punti (punto 1 e punto 2), devi seguire queste regole attentamente, tenendo in considerazione che devi dare priorità al punto 1, e solo se non si rientra nelle sue casistiche passare al punto 2 (non includere messaggi aggiuntivi come "il paziente..."):
punto 1. **Fase di controllo prima di considerare il punto 2:**
      - il paziente non ti ha fornito nome e data di nascita** Se mancano queste informazioni, **richiedile prima di procedere.**
      - Controlla attentamente la risposta del paziente. Se ti ha chiesto qualcosa, come chiarimenti o altro, **rispondi di proseguire**.

⚠ **IMPORTANTE:** Se si rientra nei criteri del punto 1 non considerare il punto 2, sono mutuamente esclusivi**.

punto 2. **Scegli una sola domanda tra quelle elencate (ricorda questi passaggi bisogna farli solo e solo se hai avuto nome e data di nascita dal paziente):**
      - ${formattedQuestions}
      - Considera solo **le domande**, non le affermazioni (escludi risposte come "va bene", "grazie" e simili).
      - Se necessario, **riformula la domanda** per renderla più chiara o adatta al contesto.
      - Rimuovi dalla domanda espressioni non importanti per il senso della domanda (esempio: "Ultima domanda, ....).
      - **Considera sempre il contesto:** alcune domande vanno fatte solo dopo altre, quindi scegli quella più pertinente.
      - **Non ripetere domande già fatte.** Se tutte le domande disponibili sono già state fatte, **inventa una domanda pertinente.**""";
  }

  String _formatChatHistory() {
    return currentChatMessages
        .where((msg) => !msg['content']
            .toString()
            .toUpperCase()
            .contains('FORNISCI I RISULTATI DELL\'INTERVISTA'))
        .map((msg) {
      final role = msg['role'] == 'user' ? 'Paziente' : 'Medico';
      return '$role: ${msg['content']}';
    }).join('\n');
  }

  Future<List<String>> _getMedicalQuestions() async {
    try {
      final questions = await QuestionService.getRandomMedicalQuestions();
      if (kDebugMode) {
        print('Domande disponibili: $questions');
      }
      return questions;
    } catch (e) {
      if (kDebugMode) {
        print('Errore nel recupero domande: $e');
      }
      return [
        "Come si chiama?",
        "Qual è la sua data di nascita?",
      ];
    }
  }

  Future<String> _generateInterviewResults(GenerativeModel model) async {
    final problemDetails = await getProblemDetails();
    final evaluations = <Map<String, String>>[];

    for (final problem in problemDetails) {
      final prompt = """
- Problematica: ${problem['fenomeno']}
- Descrizione: ${problem['descrizione']}
- Esempio: ${problem['esempio']}
- Punteggio TLDS: ${problem['punteggio']}
**Valuta la presenza della problematica "${problem['fenomeno']}" all'interno della conversazione avuta finora col paziente, usando il seguente modello:**
- Modello di output: ${problem['modello_di_output']}

Conversazione completa:
${_formatChatHistory()}
""";
      final response = await model.generateContent([Content.text(prompt)]);
      final evaluation = response.text ?? 'Nessuna valutazione disponibile.';
      evaluations.add({
        'problem': problem['fenomeno'],
        'evaluation': evaluation,
      });
    }

    final formattedEvaluations = evaluations
        .map((e) => "**${e['problem']}**\n${e['evaluation']}\n")
        .join('---\n');

    return """
**RISULTATI DELL'INTERVISTA**
$formattedEvaluations
""";
  }

  Future<List<Map<String, dynamic>>> getProblemDetails() async {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final manifest = json.decode(manifestContent) as Map<String, dynamic>;

    final problemFileKey = manifest.keys.firstWhere(
      (key) => key.contains('assets/cartellaTALD/jsonTald.json'),
      orElse: () => '',
    );

    if (problemFileKey.isEmpty) {
      throw FileSystemException('File jsonTald.json non trovato negli asset');
    }

    final fileContent = await rootBundle.loadString(problemFileKey);
    final jsonData = json.decode(fileContent);

    if (jsonData is! Map<String, dynamic> ||
        jsonData['transcription'] is! List) {
      throw FormatException('Formato JSON non valido');
    }

    final transcription = (jsonData['transcription'] as List)
        .whereType<Map<String, dynamic>>()
        .toList();

    if (kDebugMode) {
      print('Caricate ${transcription.length} problematiche');
    }

    return transcription;
  }

  Future<void> saveCurrentChat() async {
    if (currentChatMessages.isEmpty) return;

    final title = currentChatMessages.firstWhere(
      (msg) => msg['role'] == 'user',
      orElse: () => {'content': 'Nuova Intervista'},
    )['content'];
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
    notifyListeners();
  }

  Future<void> _saveChatHistoryLocally() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/medical_interviews.json');
      await file.writeAsString(json.encode(chatHistory));
    } catch (e) {
      debugPrint('Error saving chat history: $e');
    }
  }

  Future<void> _loadChatHistory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/medical_interviews.json');

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
}

// azure_tts_service.dart
// lib/services/azure_tts_service.dart
