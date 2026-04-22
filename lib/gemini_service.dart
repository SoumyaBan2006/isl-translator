import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class GeminiService {
  static const String _url =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  Future<String> signsToSentence(List<String> signs) async {
    if (signs.isEmpty) return '';

    final signText = signs.join(' ');
    final prompt =
        'Convert these Indian Sign Language signs into a natural, '
        'grammatically correct English sentence. '
        'Signs: $signText. '
        'Reply with ONLY the sentence, nothing else.';

    try {
      final response = await http.post(
        Uri.parse('$_url?key=${Config.geminiApiKey}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text =
            data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        return (text as String?)?.trim() ?? signs.join(' ');
      } else {
        return signs.join(' ');
      }
    } catch (e) {
      return signs.join(' ');
    }
  }
}