import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class QuestionService {
  static Future<List<String>> getRandomMedicalQuestions() async {
    try {
      debugPrint('Inizio caricamento AssetManifest.json...');

      // Carica la lista dei file disponibili
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final manifest = json.decode(manifestContent) as Map<String, dynamic>;

      debugPrint(
          'AssetManifest caricato. Numero totale file: ${manifest.keys.length}');

      // Filtra solo i file JSON nella cartella 'cartellaTrascrizioni'
      final questionFiles = manifest.keys
          .where((key) =>
              key.contains('assets/cartellaTrascrizioni/') &&
              key.endsWith('.json'))
          .toList();

      debugPrint(
          'File trovati in cartellaTrascrizioni/: ${questionFiles.length}');
      for (var file in questionFiles) {
        debugPrint(' - $file');
      }

      if (questionFiles.isEmpty) {
        throw Exception('Nessun file di domande trovato');
      }

      // Seleziona un file casuale
      final random = Random();
      final randomFile = questionFiles[random.nextInt(questionFiles.length)];
      debugPrint('File selezionato casualmente: $randomFile');

      // Carica e parsifica il file
      final fileContent = await rootBundle.loadString(randomFile);
      final jsonData = json.decode(fileContent) as Map<String, dynamic>;

      debugPrint('Contenuto JSON caricato con successo.');
      debugPrint('Chiavi presenti nel JSON: ${jsonData.keys.join(', ')}');

      // Estrai solo le domande del medico (role = "medico")
      if (jsonData['transcription'] is List) {
        final transcriptionList = jsonData['transcription'] as List;
        debugPrint(
            'Numero totale di elementi in transcription: ${transcriptionList.length}');

        final questions = transcriptionList
            .where((entry) =>
                entry is Map &&
                entry['role'] == 'medico' &&
                entry['text'] != null)
            .map<String>((entry) => (entry['text'] as String).trim())
            .where((text) => text.isNotEmpty)
            .toList();

        debugPrint('Trovate ${questions.length} domande mediche');

        if (questions.isEmpty) {
          throw Exception('Nessuna domanda medica trovata nel file');
        }

        return questions;
      } else {
        throw Exception(
            'Formato JSON non valido: "transcription" mancante o non è un array');
      }
    } catch (e, stacktrace) {
      debugPrint('❌ Errore nel caricamento domande: $e');
      debugPrint('📌 Stacktrace: $stacktrace');

      // Fallback a domande predefinite
      return [
        "Come si chiama?",
        "Qual è la sua data di nascita?",
        "Da quanto tempo avverte questi sintomi?",
        "Può descrivere il suo problema principale?",
      ];
    }
  }
}
