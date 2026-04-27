import 'dart:async';
import 'dart:io';
import 'package:llamadart/llamadart.dart';

class InferenceService {
  static final InferenceService _instance = InferenceService._internal();
  factory InferenceService() => _instance;
  InferenceService._internal();

  LlamaEngine? _engine;
  String? _loadedModelPath;

  Stream<String> streamChat({
    required String modelId,
    required String prompt,
    String? localPath,
    String? systemPrompt,
    List<Map<String, String>> history = const [],
    int maxTokens = 262144,
  }) async* {
    if (localPath == null || !File(localPath).existsSync()) {
      yield "Error: Local model file not found at $localPath.";
      return;
    }

    try {
      if (_loadedModelPath != localPath) {
        if (_engine != null) {
          await _engine!.dispose();
          _engine = null;
        }

        // Use up to 6 threads for batch processing, but cap interactive at 4
        // to leave headroom for UI and system tasks.
        final cpuCount = Platform.numberOfProcessors;
        final threads = cpuCount > 4 ? 4 : (cpuCount > 1 ? cpuCount : 2);
        final batchThreads = cpuCount > 6 ? 6 : (cpuCount > 2 ? cpuCount : 2);

        _engine = LlamaEngine(LlamaBackend());
        // Disable noisy logs for production stability
        LlamaEngine.configureLogging(level: LlamaLogLevel.none);

        await _engine!.loadModel(
          localPath,
          modelParams: ModelParams(
            numberOfThreads: threads,
            numberOfThreadsBatch: batchThreads,
            contextSize: 16384,
            gpuLayers: 0,
            batchSize: 1024,
            microBatchSize: 512,
          ),
        );
        _loadedModelPath = localPath;
      }

      if (_engine == null) {
        yield "Error: Failed to load model engine.";
        return;
      }

      final systemMessage = systemPrompt ??
          "You are Flux, an on-device AI. "
          "IMPORTANT: You have perfect memory of this conversation. "
          "The full conversation history is provided to you with every message, "
          "so you can reference anything said earlier. "
          "Never claim you do not remember something from this chat — you do. "
          "Answer concisely and accurately. Never hallucinate other conversations or users. "
          "Stop immediately after answering.";

      // Build the full prompt with conversation history for memory.
      // We keep a rough token budget: system prompt (~60 tokens) + history + current prompt.
      // With 16k context, we can afford a generous history and still have room for long responses.
      const int maxHistoryChars = 18000;
      final buffer = StringBuffer();
      buffer.write("<|im_start|>system\n$systemMessage\n<|im_end|>\n");

      if (history.isNotEmpty) {
        int historyChars = 0;
        for (final turn in history) {
          final role = turn['role'] ?? 'user';
          final content = turn['content'] ?? '';
          final segment = "<|im_start|>$role\n$content\n<|im_end|>\n";
          historyChars += segment.length;
          if (historyChars > maxHistoryChars) break;
          buffer.write(segment);
        }
      }

      buffer.write("<|im_start|>user\n$prompt\n<|im_end|>\n<|im_start|>assistant\n");
      final fullPrompt = buffer.toString();

      // Aggressive stop sequences to prevent continuation
      final stopSequences = [
        "<|im_end|>",
        "<|endoftext|>",
        "<|end_of_text|>",
        "<|eot_id|>",
        "\nuser",
        "\nUser",
        "\n### User:",
      ];

      final stream = _engine!.generate(
        fullPrompt,
        params: GenerationParams(
          temp: 0.1, // Near-deterministic but avoids backend issues with exact 0.0
          maxTokens: maxTokens,
          penalty: 1.1,
          stopSequences: stopSequences,
        ),
      );

      String accumulated = "";
      await for (final token in stream) {
        accumulated += token;

        // Manual backup stop check (some backends might not handle stopSequences perfectly)
        // We only check the end of the string to avoid cutting off if the AI mentions 
        // these sequences in the middle of a valid response.
        bool shouldStop = false;
        final tail = accumulated.length > 20 
            ? accumulated.substring(accumulated.length - 20) 
            : accumulated;

        for (final marker in stopSequences) {
          if (tail.contains(marker)) {
            shouldStop = true;
            break;
          }
        }

        if (shouldStop) break;
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
    _loadedModelPath = null;
  }
}
