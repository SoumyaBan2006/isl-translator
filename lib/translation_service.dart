import 'dart:convert';
import 'package:http/http.dart' as http;

class TranslationService {
  // Uses MyMemory free translation API — no key needed
  static const String _url = 'https://api.mymemory.translated.net/get';

  Future<String> translate(String text, String targetLang) async {
    if (targetLang == 'en' || text.isEmpty) return text;

    try {
      final langPair = 'en|$targetLang';
      final uri = Uri.parse(
        '$_url?q=${Uri.encodeComponent(text)}&langpair=$langPair',
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translated =
            data['responseData']?['translatedText'] as String?;
        if (translated != null && translated.isNotEmpty) {
          return translated;
        }
      }
      return text;
    } catch (e) {
      return text;
    }
  }
}