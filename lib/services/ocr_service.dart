import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../state/ocr_state.dart';

part 'ocr_service.g.dart';

class OcrService {
  final String apiHost;
  final int apiPort;
  final String modelName;
  final String apiMode;

  OcrService({
    required this.apiHost,
    required this.apiPort,
    required this.modelName,
    required this.apiMode,
  });

  Future<String> transcribeImage({
    required Uint8List imageBytes,
    required String prompt,
  }) async {
    final base64Image = base64Encode(imageBytes);

    if (apiMode == 'ollama') {
      final url = Uri.parse('http://$apiHost:$apiPort/api/generate');
      final payload = {
        'model': modelName,
        'prompt': prompt,
        'images': [base64Image],
        'stream': false,
        'options': {
          'temperature': 0.1,
        }
      };

      try {
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        );

        if (response.statusCode == 200) {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
          final content = decoded['response'] as String;
          return content;
        } else {
          throw Exception('Ollama server responded with status: ${response.statusCode}\nBody: ${response.body}');
        }
      } catch (e) {
        throw Exception('Ollama OCR request failed: $e');
      }
    } else {
      // MLX mode
      final dataUri = 'data:image/png;base64,$base64Image';
      final url = Uri.parse('http://$apiHost:$apiPort/chat/completions');
      final payload = {
        'model': modelName,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {'url': dataUri}
              },
              {
                'type': 'text',
                'text': prompt,
              }
            ]
          }
        ],
        'temperature': 0.1,
      };

      try {
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        );

        if (response.statusCode == 200) {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
          final choices = decoded['choices'] as List<dynamic>;
          if (choices.isNotEmpty) {
            final firstChoice = choices[0] as Map<String, dynamic>;
            final message = firstChoice['message'] as Map<String, dynamic>;
            final content = message['content'] as String;
            return content;
          }
          throw Exception('Response choices list is empty.');
        } else {
          throw Exception('MLX server responded with status: ${response.statusCode}\nBody: ${response.body}');
        }
      } catch (e) {
        throw Exception('MLX OCR request failed: $e');
      }
    }
  }

  Future<bool> testConnection() async {
    try {
      if (apiMode == 'ollama') {
        final url = Uri.parse('http://$apiHost:$apiPort/');
        final response = await http.get(url).timeout(const Duration(seconds: 2));
        return response.statusCode == 200;
      } else {
        // MLX mode: try root '/', since it is OpenAI compatible it might return 200, 404, or 405.
        // As long as we get a response and no socket error, the server is active.
        final url = Uri.parse('http://$apiHost:$apiPort/');
        await http.get(url).timeout(const Duration(seconds: 2));
        return true;
      }
    } catch (_) {
      return false;
    }
  }
}

@riverpod
OcrService ocrService(OcrServiceRef ref) {
  final settings = ref.watch(ocrSettingsNotifierProvider);
  return OcrService(
    apiHost: settings.apiHost,
    apiPort: settings.apiPort,
    modelName: settings.modelName,
    apiMode: settings.apiMode,
  );
}
