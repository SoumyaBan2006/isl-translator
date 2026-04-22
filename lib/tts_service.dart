import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  final FlutterTts _tts = FlutterTts();
  String? _lastText;
  String _lastLang = 'en-IN';

  TTSService() {
    _tts.setVolume(1.0);
    _tts.setSpeechRate(0.5);
    _tts.setPitch(1.0);
  }

  Future<void> speak(String text, {String languageCode = 'en-IN'}) async {
    if (text.isEmpty) return;
    _lastText = text;
    _lastLang = languageCode;

    await _tts.setLanguage(languageCode);
    await _tts.speak(text);
  }

  Future<void> replayLast() async {
    if (_lastText != null) {
      await speak(_lastText!, languageCode: _lastLang);
    }
  }

  void dispose() {
    _tts.stop();
  }
}