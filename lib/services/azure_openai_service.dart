// azure_openai_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class AzureOpenAIService {
  final String openAiEndpoint;
  final String openAiApiKey;
  final String deploymentName;
  final String searchEndpoint;
  final String searchApiKey;
  final String searchIndexName;

  AzureOpenAIService({
    required this.openAiEndpoint,
    required this.openAiApiKey,
    required this.deploymentName,
    required this.searchEndpoint,
    required this.searchApiKey,
    required this.searchIndexName,
  });

  Future<String> _getQueryContext() async {
    final url = Uri.parse(
        '$searchEndpoint/indexes/$searchIndexName/docs/search?api-version=2023-11-01');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'api-key': searchApiKey,
      },
      body: jsonEncode({
        "search": "*", // Usa il carattere jolly "*" per ottenere tutti i dati
        "queryType": "simple", // Usa la ricerca semplice
        "select": "*", // Seleziona tutti i campi
        "top":
            1000, // Recupera fino a 1000 documenti (puoi cambiarlo in base alla tua necessità)
      }),
    );

    if (response.statusCode == 200) {
      final results = jsonDecode(response.body)['value'] as List;
      if (results.isEmpty) return "Nessun dato disponibile.";

      String context = "Tutti i dati disponibili:\n";
      for (var doc in results) {
        context += "---\n";
        // Stampa tutti i campi di ciascun documento
        doc.forEach((key, value) {
          context +=
              "$key: $value\n"; // Stampa il nome del campo e il suo valore
        });
      }
      return context;
    } else {
      throw Exception(
          'Errore nella ricerca: ${response.statusCode} - ${response.body}');
    }
  }

  Future<String> sendMessage(
      String message, List<Map<String, dynamic>> chatHistory) async {
    try {
      // Ottieni tutto il contesto dai dati CSV
      final context = await _getQueryContext();

      final url = Uri.parse(
          '$openAiEndpoint/openai/deployments/$deploymentName/chat/completions?api-version=2023-12-01-preview');

      final messages = [
        {
          "role": "system",
          "content": """
        Sei un assistente intelligente che risponde alle domande basandosi sui dati aziendali forniti.
        Ecco tutti i dati disponibili:
        $context
        
        Istruzioni:
        1. Rispondi PRIMARIAMENTE basandoti sui dati forniti
        2. Se la risposta non è nei dati, dillo chiaramente
        3. Mantieni un tono professionale
        4. Se rilevante, cita la fonte dei dati
        5. Parla del prodotto senza aggiungere asterischi
        """
        },
        ...chatHistory.map((msg) => {
              "role": msg["role"] == "user" ? "user" : "assistant",
              "content": msg["content"]
            }),
        {"role": "user", "content": message}
      ];

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'api-key': openAiApiKey,
        },
        body: jsonEncode({
          "messages": messages,
          "max_tokens": 800,
          "temperature": 0.3,
          "top_p": 0.5,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['choices'][0]['message']['content'];
      } else {
        throw Exception(
            'Errore OpenAI: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Errore durante il recupero della risposta: $e');
    }
  }
}
