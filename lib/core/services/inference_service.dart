import 'dart:async';
import 'dart:io';
import 'package:llamadart/llamadart.dart';

class InferenceService {
  LlamaEngine? _engine;
  String? _loadedModelPath;

  Stream<String> streamChat({
    required String modelId,
    required String prompt,
    String? localPath,
    String? systemPrompt,
  }) async* {
    if (localPath == null || !File(localPath).existsSync()) {
      yield "Error: Local model file not found at $localPath.";
      return;
    }

    try {
      if (_loadedModelPath != localPath) {
        if (_engine != null) await _engine!.dispose();
        
        _engine = LlamaEngine(LlamaBackend());
        await _engine!.loadModel(localPath);
        _loadedModelPath = localPath;
      }

      if (_engine == null) {
        yield "Error: Failed to load model engine.";
        return;
      }

      final systemMessage = systemPrompt ?? "Extremely concise mode. Respond in 1-5 words. Zero filler.";
      final fullPrompt = "### System:\n$systemMessage\n\n### User:\n$prompt\n\n### Assistant:\n";

      final stream = _engine!.generate(
        fullPrompt,
        params: GenerationParams(
          temp: 0.7,
          maxTokens: 512,
        ),
      );

      // Manual stop sequence handling
      final stopMarkers = ["### User:", "###", "User:", "\n\n"];
      String accumulated = "";

      await for (final token in stream) {
        accumulated += token;
        
        // Check if any stop marker is now in our accumulated text
        bool shouldStop = false;
        for (final marker in stopMarkers) {
          if (accumulated.contains(marker)) {
            shouldStop = true;
            break;
          }
        }

        if (shouldStop) {
          // If we hit a stop marker, we yield only the part before the marker
          // but for extreme conciseness, we can just stop here as the marker likely started after the answer.
          break;
        }

        yield token;
      }

    } catch (e) {
      if (e.toString().contains('Failed to load model')) {
        yield "Error: Model Architecture Unsupported. Please try a standard 'Llama 3.2' or 'Qwen' model for now.";
      } else {
        yield "Inference Error: $e";
      }
      print('llamadart error: $e');
    }
  }

  Future<void> dispose() async {
    await _engine?.dispose();
    _engine = null;
  }
}
