import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<void> saveChatLocally(List<Map<String, String>> messages) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/chat_history.json');

  List<Map<String, String>> savedMessages = [];
  if (await file.exists()) {
    String fileContent = await file.readAsString();
    savedMessages = List<Map<String, String>>.from(json.decode(fileContent));
  }

  savedMessages.addAll(messages);

  await file.writeAsString(json.encode(savedMessages));
}

Future<List<String>> loadChatHistory() async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/chat_history.json');

  if (await file.exists()) {
    String fileContent = await file.readAsString();
    List<Map<String, String>> savedMessages =
        List<Map<String, String>>.from(json.decode(fileContent));
    return savedMessages.map((message) => message['content'] ?? '').toList();
  }

  return [];
}
