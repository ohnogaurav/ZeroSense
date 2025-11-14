import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiService {
  // Put your API key here
  final String _apiKey = "APIKEY HERE";

  // Example: OpenAI chat completions endpoint
  final String _url = "https://api.openai.com/v1/chat/completions";
  final String _model = "gpt-4o-mini"; // change if needed

  Future<int> getScore(String target, String guess) async {
    // exact quick check
    if (target.toLowerCase() == guess.toLowerCase()) return 0;

    final system =
        "You are a semantic distance calculator. Return only a single integer 0-100 (0 exact match, 100 unrelated).";
    final user = "Target word: $target\nGuess: $guess\nReturn only the integer.";

    try {
      final body = {
        'model': _model,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user}
        ],
        'max_tokens': 10,
        'temperature': 0.0
      };

      final resp = await http.post(
        Uri.parse(_url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(body),
      );

      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body);
        final content = j['choices'][0]['message']['content'] as String;
        final num = RegExp(r'\d+').firstMatch(content)?.group(0);
        if (num != null) return int.parse(num);
      } else {
        debugPrint('API score failed ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('API score exception $e');
    }

    // fallback random
    return 30 + Random().nextInt(50);
  }

  Future<String> getStartupHint(String target) async {
    final system =
        "You are a clue generator. Provide one sentence hint about the category or concept of the secret word without using the word itself. Return only the sentence.";
    final user = "Secret word: $target";

    try {
      final body = {
        'model': _model,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user}
        ],
        'max_tokens': 60,
        'temperature': 0.7
      };

      final resp = await http.post(Uri.parse(_url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode(body));

      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body);
        final content = j['choices'][0]['message']['content'] as String;
        return content.replaceAll('"', '').trim();
      } else {
        debugPrint('Startup hint failed ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('Startup hint exception $e');
    }
    return "A common English concept.";
  }

  Future<String> getCloserHint(String target, int bestScore) async {
    final system =
        "You are a hint generator. Given a secret word and a numeric semantic score (0-100, lower is closer), return a single English word that is semantically closer than the given score. Return only the word.";
    final user = "Secret: $target\nCurrent best score: $bestScore";

    try {
      final body = {
        'model': _model,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user}
        ],
        'max_tokens': 10,
        'temperature': 0.5
      };

      final resp = await http.post(Uri.parse(_url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode(body));

      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body);
        String content = j['choices'][0]['message']['content'] as String;
        // keep letters only
        content = content.replaceAll(RegExp(r'[^a-zA-Z]'), '');
        return content.toLowerCase();
      }
    } catch (e) {
      debugPrint('Closer hint exception $e');
    }
    return "word";
  }

  Future<String> getRandomWord() async {
    final system =
        "Return one common English noun (lowercase) between 4 and 8 letters. Return only the word.";
    final user = "Give a random noun.";

    try {
      final body = {
        'model': _model,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user}
        ],
        'max_tokens': 10,
        'temperature': 1.0
      };

      final resp = await http.post(Uri.parse(_url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode(body));

      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body);
        final content = j['choices'][0]['message']['content'] as String;
        final word = content.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();
        if (word.length >= 4) return word;
      }
    } catch (e) {
      debugPrint('random word exc $e');
    }
    return "planet";
  }
}
