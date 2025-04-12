import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

class AzureTTSService {
  final String subscriptionKey;
  final String region;
  final String voiceName;
  final AudioPlayer audioPlayer;

  AzureTTSService({
    required this.subscriptionKey,
    required this.region,
    this.voiceName = 'it-IT-ElsaNeural',
  }) : audioPlayer = AudioPlayer() {
    audioPlayer.setReleaseMode(ReleaseMode.release);
  }

  Future<void> speak(String text) async {
    try {
      await audioPlayer.stop();

      final ssml = '''
        <speak version='1.0' xml:lang='it-IT'>
          <voice name='$voiceName'>
            $text
          </voice>
        </speak>
      ''';

      final endpoint =
          'https://$region.tts.speech.microsoft.com/cognitiveservices/v1';

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Ocp-Apim-Subscription-Key': subscriptionKey,
          'Content-Type': 'application/ssml+xml',
          'X-Microsoft-OutputFormat': 'audio-24khz-48kbitrate-mono-mp3',
          'User-Agent': 'MedicalInterviewApp',
        },
        body: ssml,
      );

      if (response.statusCode == 200) {
        await _playAudio(response.bodyBytes);
      } else {
        debugPrint('Errore TTS: ${response.statusCode} - ${response.body}');
        throw Exception('Errore nella sintesi vocale: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Errore durante la sintesi vocale: $e');
      rethrow;
    }
  }

  Future<void> _playAudio(List<int> audioData) async {
    try {
      final tempDir = await Directory.systemTemp.createTemp();
      final file = File('${tempDir.path}/tts_audio.mp3');
      await file.writeAsBytes(audioData);

      await audioPlayer.play(DeviceFileSource(file.path));

      audioPlayer.onPlayerComplete.listen((_) async {
        if (await file.exists()) {
          await file.delete();
        } else {
          debugPrint("File temporaneo non trovato, impossibile eliminarlo.");
        }
        await tempDir.delete();
      });
    } catch (e) {
      debugPrint('Errore nella riproduzione audio: $e');
      throw Exception('Impossibile riprodurre l\'audio');
    }
  }

  Future<void> dispose() async {
    await audioPlayer.dispose();
  }
}
