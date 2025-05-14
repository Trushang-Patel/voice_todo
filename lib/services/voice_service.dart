import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/tasks_repository.dart';

/// Service for handling STT, TTS, and passing commands to the repository.
final voiceServiceProvider = Provider<VoiceService>((ref) {
  final repo = TasksRepository();
  return VoiceService(flutterTts: FlutterTts(), speech: stt.SpeechToText(), repo: repo);
});

class VoiceService {
  final FlutterTts _flutterTts;
  final stt.SpeechToText _speech;
  final TasksRepository repo;
  bool _isListening = false;

  VoiceService({required FlutterTts flutterTts, required stt.SpeechToText speech, required this.repo})
      : _flutterTts = flutterTts,
        _speech = speech;

  Future<void> init() async {
    await _flutterTts.setLanguage('en-US');
    // optional: set speechToText locale
  }

  Future<void> startListening() async {
    final available = await _speech.initialize();
    if (available) {
      _isListening = true;
      _speech.listen(onResult: (result) async {
        if (result.finalResult) {
          final txt = result.recognizedWords;
          await repo.handleCommand(txt);
          await _flutterTts.speak('Command received: $txt');
        }
      });
    } else {
      await _flutterTts.speak('Speech recognition not available');
    }
  }

  Future<void> stopListening() async {
    await _speech.stop();
    _isListening = false;
  }
}
