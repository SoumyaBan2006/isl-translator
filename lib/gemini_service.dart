import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class GeminiService {
  static const String _url =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  Future<String> signsToSentence(List<String> signs) async {
    if (signs.isEmpty) return '';

    // Try up to 2 times in case of network hiccup
    for (int attempt = 0; attempt < 2; attempt++) {
      final result = await _callGemini(signs);
      if (result != null && result.isNotEmpty && !_isRobotic(result, signs)) {
        return result;
      }
    }

    // If Gemini fails both times, use smart fallback
    return _smartFallback(signs);
  }

  Future<String?> _callGemini(List<String> signs) async {
    final signText = signs.join(' ');

    // Very explicit prompt that forces a natural sentence
    final prompt = 'Rewrite this as one natural spoken English sentence '
        'that a person would actually say. Words: $signText. '
        'Rules: 1) Must be a complete sentence with a verb. '
        '2) Must NOT just list the words. '
        '3) Must sound like real human speech. '
        '4) Maximum 12 words. '
        '5) Reply with ONLY the sentence, nothing else.';

    try {
      final response = await http
          .post(
            Uri.parse('$_url?key=${Config.geminiApiKey}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ],
              'generationConfig': {
                'temperature': 0.9,
                'maxOutputTokens': 40,
                'topP': 0.95,
              },
              'safetySettings': [
                {
                  'category': 'HARM_CATEGORY_HARASSMENT',
                  'threshold': 'BLOCK_NONE'
                },
                {
                  'category': 'HARM_CATEGORY_HATE_SPEECH',
                  'threshold': 'BLOCK_NONE'
                },
              ]
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text =
            data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        if (text != null) {
          return (text as String)
              .trim()
              .replaceAll('"', '')
              .replaceAll("'", '')
              .replaceAll('\n', ' ')
              .trim();
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Check if Gemini just listed the words robotically
  bool _isRobotic(String sentence, List<String> signs) {
    final lower = sentence.toLowerCase();
    // If the sentence contains " and " between sign words, it's robotic
    int matchCount = 0;
    for (final sign in signs) {
      if (lower.contains(sign.toLowerCase())) matchCount++;
    }
    // If all signs appear verbatim and sentence has " and ", it's robotic
    if (matchCount == signs.length && lower.contains(' and ')) return true;
    return false;
  }

  // Smart fallback that builds a real sentence without Gemini
  String _smartFallback(List<String> signs) {
    if (signs.isEmpty) return '';

    final lower = signs.map((s) => s.toLowerCase()).toList();

    // Common patterns
    if (lower.contains('hello') && lower.contains('i') && lower.contains('thank you')) {
      return 'Hello, I just wanted to thank you.';
    }
    if (lower.contains('hello') && lower.contains('how are you')) {
      return 'Hello! How are you doing?';
    }
    if (lower.contains('hello') && lower.contains('i')) {
      return 'Hello, it is me!';
    }
    if (lower.contains('i') && lower.contains('thank you')) {
      return 'I really want to thank you.';
    }
    if (lower.contains('i') && lower.contains('help')) {
      return 'I need some help please.';
    }
    if (lower.contains('help') && lower.contains('today')) {
      return 'Can you help me today?';
    }
    if (lower.contains('good morning') && lower.contains('we')) {
      return 'Good morning everyone!';
    }
    if (lower.contains('good morning')) {
      return 'Good morning to you!';
    }
    if (lower.contains('how are you') && lower.contains('you')) {
      return 'Hey, how are you doing?';
    }
    if (lower.contains('i') && lower.contains('you')) {
      return 'I want to talk to you.';
    }
    if (lower.contains('thank you')) {
      return 'Thank you so much!';
    }
    if (lower.contains('hello')) {
      return 'Hello there!';
    }
    if (lower.contains('mother') || lower.contains('father')) {
      final who = lower.contains('mother') ? 'mother' : 'father';
      return 'I want to call my $who.';
    }
    if (lower.contains('we') && lower.contains('today')) {
      return 'We need to do this today.';
    }

    // Last resort — form a minimal readable sentence
    if (signs.length == 1) return '${signs[0]}!';
    final last = signs.last;
    final rest = signs.sublist(0, signs.length - 1).join(', ');
    return 'I want to say $rest and $last.';
  }
}