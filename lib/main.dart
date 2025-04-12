import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'chat_provider.dart';
import 'chatwidget.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Carica PRIMA le variabili d'ambiente
  await dotenv.load(fileName: ".env");

  // 2. Debug: verifica che le chiavi siano state caricate
  debugPrint(
      "GOOGLEAI_API_KEY loaded: ${dotenv.env['GOOGLEAI_API_KEY']?.isNotEmpty ?? false}");
  debugPrint(
      "AZURE_KEY loaded: ${dotenv.env['AZURE_KEY']?.isNotEmpty ?? false}");

  // 3. Solo ora inizializza il provider
  final chatProvider = ChatProvider();
  await chatProvider.initialize();

  runApp(
    ChangeNotifierProvider.value(
      value: chatProvider,
      child: const GenerativeAISample(),
    ),
  );
}

class GenerativeAISample extends StatelessWidget {
  const GenerativeAISample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Medical Interview AI',
      theme: ThemeData(
        useMaterial3: true, // Spostato all'inizio del ThemeData
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color.fromARGB(255, 171, 222, 244),
        ),
      ),
      home: const ChatScreen(title: 'Medical Interview AI'),
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
            onPressed: () => _showInstructions(context),
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
                child: Text('Cronologia Interviste'),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: chatProvider.chatHistory.length,
                  itemBuilder: (context, index) {
                    final chat = chatProvider.chatHistory[index];
                    return ListTile(
                      title: Text(
                        chat['title'] ?? 'Nuova intervista',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        chat['lastUpdated']?.substring(0, 10) ?? '',
                      ),
                      onTap: () {
                        chatProvider.loadSpecificChat(index);
                        Navigator.pop(context);
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () =>
                            _confirmDelete(context, chatProvider, index),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Nuova Intervista'),
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
        content: const Text('Eliminare questa intervista?'),
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
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  void _showInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Istruzioni'),
        content: const Text(
          '1. Inizia fornendo nome e data di nascita\n'
          '2. Rispondi alle domande del sistema\n'
          '3. Scrivi "FORNISCI I RISULTATI" per generare il report',
        ),
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
