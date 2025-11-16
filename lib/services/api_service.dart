// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

/// ApiResult<T> - unified result returned by ApiService
/// - value: parsed/cleaned value (null if parsing failed)
/// - fromAI: true if AI responded successfully
/// - raw: raw assistant text returned by model (or null)
/// - error: human-readable error (or null)
class ApiResult<T> {
  final T? value;
  final bool fromAI;
  final String? raw;
  final String? error;
  ApiResult({this.value, required this.fromAI, this.raw, this.error});
}

class ApiService {
  String? _apiKey;
  String _model = "llama-3.1-8b-instant";
  final String _url = "https://groq-proxy.groqzeroapi.workers.dev";


  /// set your API key
  void setApiKey(String key) => _apiKey = key;

  /// optional: change model if you want
  void setModel(String model) => _model = model;

  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception("API key missing");
    }

    final uri = Uri.parse(_url);

    final resp = await http
        .post(uri,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode(body))
        .timeout(const Duration(seconds: 12), onTimeout: () {
      throw Exception("Request timed out");
    });

    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } else {
      throw Exception("API error ${resp.statusCode}: ${resp.body}");
    }
  }

  // -----------------------------
  // Helper: read assistant text safely
  // -----------------------------
  String _extractAssistantText(Map<String, dynamic> j) {
    try {
      final choices = j['choices'] as List<dynamic>?;
      if (choices != null && choices.isNotEmpty) {
        final message = choices[0]['message'] as Map<String, dynamic>?;
        if (message != null) {
          final content = (message['content'] ?? '').toString();
          return content.trim();
        }
      }
    } catch (_) {}
    return '';
  }

  // -----------------------------
  // SCORE
  // -----------------------------
  Future<ApiResult<int>> getScore(String target, String guess) async {
    final body = {
      "model": _model,
      "messages": [
        {
          "role": "system",
          "content":
          "You are a semantic distance calculator. Return EXACTLY one integer between 0 and 100 (0 = exact match, 100 = unrelated). Reply with the integer only — no extra text, no punctuation."
        },
        {
          "role": "user",
          "content": "Target: $target\nGuess: $guess\nRespond with one integer (0-100)."
        }
      ],
      "max_tokens": 6,
      "temperature": 0.0
    };

    try {
      final j = await _post(body);
      final raw = _extractAssistantText(j);

      final matches = RegExp(r'\d{1,3}')
          .allMatches(raw)
          .map((m) => m.group(0))
          .where((x) => x != null);
      for (final s in matches) {
        final n = int.tryParse(s!);
        if (n != null && n >= 0 && n <= 100) {
          return ApiResult<int>(value: n, fromAI: true, raw: raw, error: null);
        }
      }

      return ApiResult<int>(
          value: null,
          fromAI: false,
          raw: raw,
          error: "Could not parse integer 0-100 from AI response");
    } catch (e) {
      return ApiResult<int>(value: null, fromAI: false, raw: null, error: e.toString());
    }
  }

  // -----------------------------
  // STARTUP HINT (one sentence)
  // -----------------------------
  Future<ApiResult<String>> getStartupHint(String target) async {
    final body = {
      "model": _model,
      "messages": [
        {
          "role": "system",
          "content":
          "You are a clue generator. Return EXACTLY one short English sentence (no quotes) that hints at the category or concept of the secret word WITHOUT using the secret word itself. Output only the sentence."
        },
        {"role": "user", "content": "Secret word: $target\nReturn one sentence."}
      ],
      "max_tokens": 60,
      "temperature": 0.6
    };

    try {
      final j = await _post(body);
      final raw = _extractAssistantText(j);
      if (raw.isNotEmpty) return ApiResult<String>(value: raw.trim(), fromAI: true, raw: raw, error: null);
      return ApiResult<String>(value: null, fromAI: false, raw: raw, error: "Empty hint from AI");
    } catch (e) {
      return ApiResult<String>(value: null, fromAI: false, raw: null, error: e.toString());
    }
  }

  // -----------------------------
  // CLOSER HINT (single word) - NEW SIGNATURE
  // - desiredScore: integer target for semantic distance the AI should aim for (0..100)
  // - avoidWords: list of words AI must avoid returning (already used hints)
  // -----------------------------
  Future<ApiResult<String>> getCloserHint(String target, int desiredScore, List<String> avoidWords) async {
    // Compose avoid list text for the prompt
    final avoidText = (avoidWords.isEmpty) ? "none" : avoidWords.join(", ");

    final body = {
      "model": _model,
      "messages": [
        {
          "role": "system",
          "content":
          "Return EXACTLY ONE valid English word (letters only, no punctuation, no explanation, no quotes). The word must be semantically closer to the secret word than the given score indicates and should aim to have a semantic distance close to the desiredScore provided by the user. Do NOT return any of the words in the avoid list. Output the single word only."
        },
        {
          "role": "user",
          "content":
          "Secret: $target\nDesired semantic distance (0-100, lower is closer): $desiredScore\nAvoid words: $avoidText\nReturn exactly one lowercase word only."
        }
      ],
      "max_tokens": 8,
      "temperature": 0.45
    };

    try {
      final j = await _post(body);
      final raw = _extractAssistantText(j);

      final token = raw.split(RegExp(r'\s+')).firstWhere((t) => t.trim().isNotEmpty, orElse: () => '');
      final cleaned = token.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();

      if (cleaned.isNotEmpty && !avoidWords.contains(cleaned)) {
        return ApiResult<String>(value: cleaned, fromAI: true, raw: raw, error: null);
      } else {
        // fallback: search any word inside raw
        final m = RegExp(r'[A-Za-z]{2,}').firstMatch(raw);
        if (m != null) {
          final found = m.group(0)!.toLowerCase();
          if (!avoidWords.contains(found)) {
            return ApiResult<String>(value: found, fromAI: true, raw: raw, error: "Used fallback cleaning to extract word");
          }
        }
        return ApiResult<String>(value: null, fromAI: false, raw: raw, error: "Could not extract single valid word or AI returned an avoided word");
      }
    } catch (e) {
      return ApiResult<String>(value: null, fromAI: false, raw: null, error: e.toString());
    }
  }

  // -----------------------------
  // RANDOM WORD (single noun 4-8 letters)
  // -----------------------------
  Future<ApiResult<String>> getRandomWord() async {
    final body = {
      "model": _model,
      "messages": [
        {
          "role": "system",
          "content":
          "Return EXACTLY ONE common English noun, lowercase, 4-8 letters. Output the word only — no quotes or punctuation."
        },
        {"role": "user", "content": "Give a random noun 4-8 letters."}
      ],
      "max_tokens": 8,
      "temperature": 1.0
    };

    try {
      final j = await _post(body);
      final raw = _extractAssistantText(j);
      final cleaned = raw.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();

      if (cleaned.length >= 4 && cleaned.length <= 8) {
        return ApiResult<String>(value: cleaned, fromAI: true, raw: raw, error: null);
      } else {
        return ApiResult<String>(value: null, fromAI: false, raw: raw, error: "Returned word not 4-8 letters");
      }
    } catch (e) {
      return ApiResult<String>(value: null, fromAI: false, raw: null, error: e.toString());
    }
  }
}
