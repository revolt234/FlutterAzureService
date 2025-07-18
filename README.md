# Esame di Cloud

## Getting Started

Questo progetto è un'applicazione chatbot realizzata con Dart e Flutter.
Integra i servizi Azure OpenAI per la generazione delle risposte e Azure TTS per la sintesi vocale, permettendo conversazioni sia testuali che vocali con lo stesso assistente.

Se vuoi approfondire Flutter e iniziare a sviluppare applicazioni simili, ecco alcune risorse utili:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

Per una guida completa allo sviluppo con Flutter, consulta la
[documentazione online](https://docs.flutter.dev/), dove troverai tutorial, esempi, linee guida per lo sviluppo mobile e il riferimento completo alle API.

## 🤖 Azure AI Assistant Flutter

Un assistente intelligente sviluppato in **Flutter** che sfrutta:

- **Azure OpenAI (GPT-4)** per generare risposte contestuali
- **Azure Cognitive Search** per recuperare dati aziendali indicizzati
- **Voce di Azure (Azure Speech Service)** per leggere le risposte vocalmente
- **Account di Archiviazione Azure** come sorgente dati (es. file CSV in un container)

Il risultato è un assistente AI professionale che **risponde esclusivamente sulla base dei dati aziendali interni**, aggiornabili facilmente tramite l'archiviazione cloud.

---

## 🧠 Funzionalità principali

✅ Risposte AI basate solo sui dati aziendali forniti  
✅ Integrazione con Azure OpenAI (GPT-4, GPT-4o, ecc.)  
✅ **Contesto dinamico e aggiornabile** dai dati del container di Archiviazione Azure  
✅ Recupero dati tramite Azure Cognitive Search  
✅ Sintesi vocale naturale con **Voce di Azure (ElsaNeural)**  
✅ Gestione completa della cronologia chat in locale  
✅ Supporto configurazioni sicure via `.env`  
✅ Stato reattivo e aggiornabile via `Provider`

---

## 🏗️ Architettura

| Componente               | Descrizione                                                                 |
|--------------------------|-----------------------------------------------------------------------------|
| **Azure OpenAI**         | Elabora i messaggi e genera risposte contestuali                           |
| **Azure Cognitive Search** | Interroga i dati strutturati nel container del tuo Account di Archiviazione Azure |
| **Voce di Azure**        | Sintetizza vocalmente le risposte del modello                              |
| **ChatProvider**         | Coordina lo stato, la voce, la cronologia e i messaggi                     |
| **Storage locale**       | Salva cronologia e chat via `path_provider`    

## Esempio di utilizzo
<img src="image.png" alt="alt text" width="35%" />
Come si può vedere, il Bot può essere utilizzato da qualsiasi supermercato o negozio per creare un assistente virtuale personalizzato, in grado di tenere i clienti sempre aggiornati.
È importante che un responsabile si occupi della gestione del contenitore di informazioni, per garantire l’accuratezza dei dati ed evitare eventuali disagi ai clienti.

## 🚀 Funzionalità ChatWidget.dart
- Interfaccia chat moderna  
- Visualizzazione della cronologia completa dei messaggi  
- Supporto a invio e ricezione messaggi  
- Scroll automatico su nuovi messaggi  
- Indicatore di elaborazione messaggio
- Timestamp visibile  
  
 