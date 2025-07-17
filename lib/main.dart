import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'chat_provider.dart';
import 'chatwidget.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carica le variabili d'ambiente
  await dotenv.load(fileName: ".env");

  // Debug: verifica che le chiavi Azure siano state caricate
  debugPrint(
      "AZURE_OPENAI_KEY loaded: ${dotenv.env['AZURE_OPENAI_KEY']?.isNotEmpty ?? false}");
  debugPrint(
      "AZURE_SEARCH_KEY loaded: ${dotenv.env['AZURE_SEARCH_KEY']?.isNotEmpty ?? false}");
  debugPrint(
      "AZURE_KEY (TTS) loaded: ${dotenv.env['AZURE_KEY']?.isNotEmpty ?? false}");

  // Inizializza il provider
  final chatProvider = ChatProvider();
  await chatProvider.initialize();

  // Verifica le connessioni ai servizi Azure
  final connectionSuccess = await chatProvider.testConnections();
  if (!connectionSuccess) {
    debugPrint("Errore nella connessione ai servizi Azure");
  }

  runApp(
    ChangeNotifierProvider.value(
      value: chatProvider,
      child: const AzureAIChatApp(),
    ),
  );
}

class AzureAIChatApp extends StatelessWidget {
  const AzureAIChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Azure AI Chat',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor:
              const Color.fromARGB(255, 100, 181, 246), // Colore blu Azure
        ),
      ),
      home: const ChatScreen(title: 'Azure AI Chat'),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.title});
  final String title;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAppInfo(context),
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: const ChatWidget(),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          return Column(
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 0, 120, 215), // Colore Azure
                ),
                child: Text(
                  'Cronologia Chat',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: chatProvider.chatHistory.length,
                  itemBuilder: (context, index) {
                    final chat = chatProvider.chatHistory[index];
                    return ListTile(
                      title: Text(
                        chat['title'] ?? 'Nuova chat',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        chat['lastUpdated']?.substring(0, 16) ?? '',
                      ),
                      onTap: () {
                        chatProvider.loadSpecificChat(index);
                        Navigator.pop(context);
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () =>
                            _confirmDelete(context, chatProvider, index),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Nuova Chat'),
                  onPressed: () {
                    chatProvider.startNewChat();
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, ChatProvider provider, int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: const Text('Eliminare questa chat dalla cronologia?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteChat(index);
              Navigator.pop(ctx);
            },
            child: const Text('Elimina', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAppInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Informazioni'),
        content: const Text('Chatbot basato sui servizi Azure AI:\n'
            '• Azure OpenAI (GPT-4) per generare risposte contestuali\n'
            '• Azure Cognitive Search per recuperare dati aziendali indicizzati\n'
            '• Voce di Azure (Azure Speech Service) per leggere le risposte vocalmente\n'
            '• Account di Archiviazione Azure come sorgente dati\n\n'
            'I dati delle conversazioni rimangono memorizzati solo sul tuo dispositivo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
