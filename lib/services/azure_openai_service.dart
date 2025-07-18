// azure_openai_service.dart

import 'dart:convert'; // Usato per codificare/decodificare JSON
import 'package:http/http.dart'
    as http; // Pacchetto HTTP per effettuare richieste web

/// Servizio per integrare Azure OpenAI e Azure Cognitive Search
class AzureOpenAIService {
  // Endpoint per accedere all'istanza OpenAI su Azure
  final String openAiEndpoint;

  // Chiave API per autenticarsi con OpenAI
  final String openAiApiKey;

  // Nome del deployment del modello OpenAI su Azure
  final String deploymentName;

  // Endpoint per accedere al servizio Azure Cognitive Search
  final String searchEndpoint;

  // Chiave API per accedere a Cognitive Search
  final String searchApiKey;

  // Nome dell’indice usato in Azure Cognitive Search
  final String searchIndexName;

  /// Costruttore della classe che inizializza tutti i campi necessari
  AzureOpenAIService({
    required this.openAiEndpoint,
    required this.openAiApiKey,
    required this.deploymentName,
    required this.searchEndpoint,
    required this.searchApiKey,
    required this.searchIndexName,
  });

  /// Recupera tutto il contesto (i dati) dai documenti indicizzati su Azure Cognitive Search
  Future<String> _getQueryContext() async {
    // Costruisce l’URL per interrogare l’indice di ricerca
    final url = Uri.parse(
      '$searchEndpoint/indexes/$searchIndexName/docs/search?api-version=2023-11-01',
    );

    // Esegue una POST per cercare tutti i documenti usando "*" come jolly
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'api-key': searchApiKey,
      },
      body: jsonEncode({
        "search": "*", // Cerca tutti i documenti
        "queryType": "simple", // Usa la sintassi di query semplice
        "select": "*", // Seleziona tutti i campi
        "top": 1000, // Limita il risultato a 1000 documenti
      }),
    );

    // Se la richiesta ha successo (status 200)
    if (response.statusCode == 200) {
      // Decodifica il JSON e prende l'elenco dei documenti
      final results = jsonDecode(response.body)['value'] as List;

      // Se non ci sono risultati, restituisce un messaggio appropriato
      if (results.isEmpty) return "Nessun dato disponibile.";

      // Costruisce una stringa di contesto con i dati estratti
      String context = "Tutti i dati disponibili:\n";
      for (var doc in results) {
        context += "---\n";
        // Itera su ogni campo del documento e lo aggiunge alla stringa
        doc.forEach((key, value) {
          context += "$key: $value\n";
        });
      }
      return context;
    } else {
      // In caso di errore, lancia un’eccezione con dettagli
      throw Exception(
        'Errore nella ricerca: ${response.statusCode} - ${response.body}',
      );
    }
  }

  /// Invia un messaggio all’assistente basato su Azure OpenAI,
  /// includendo il contesto aziendale ottenuto da Cognitive Search
  Future<String> sendMessage(
    String message,
    List<Map<String, dynamic>> chatHistory,
  ) async {
    try {
      // Recupera il contesto da Azure Cognitive Search
      final context = await _getQueryContext();

      // Costruisce l’URL per inviare la richiesta al modello OpenAI
      final url = Uri.parse(
        '$openAiEndpoint/openai/deployments/$deploymentName/chat/completions?api-version=2023-12-01-preview',
      );

      // Costruisce la lista dei messaggi (incluso il messaggio utente e lo storico)
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
        // Aggiunge i messaggi precedenti della chat
        ...chatHistory.map((msg) => {
              "role": msg["role"] == "user" ? "user" : "assistant",
              "content": msg["content"]
            }),
        // Aggiunge il messaggio attuale dell’utente
        {"role": "user", "content": message}
      ];

      // Invia la richiesta al modello
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'api-key': openAiApiKey,
        },
        body: jsonEncode({
          "messages": messages,
          "max_tokens": 800, // Limite di token nella risposta
          "temperature": 0.3, // Creatività limitata (risposte più prevedibili)
          "top_p": 0.5, // Controlla la diversità delle risposte
        }),
      );

      // Se la risposta è OK, restituisce il testo generato dal modello
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return decoded['choices'][0]['message']['content'];
      } else {
        // Altrimenti lancia un errore dettagliato
        throw Exception(
          'Errore OpenAI: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      // Gestione degli errori generici
      throw Exception('Errore durante il recupero della risposta: $e');
    }
  }
}
