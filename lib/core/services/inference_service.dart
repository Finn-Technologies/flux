import 'dart:async';
import 'dart:io';
import 'package:llamadart/llamadart.dart';

class InferenceService {
  static final InferenceService _instance = InferenceService._internal();
  factory InferenceService() => _instance;
  InferenceService._internal() {
    LlamaEngine.configureLogging(level: LlamaLogLevel.none);
  }

  LlamaEngine? _engine;
  String? _loadedModelPath;
  final int _cpuCount = Platform.numberOfProcessors;

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

        final threads = _cpuCount > 1 ? _cpuCount - 1 : 1;
        final batchThreads = _cpuCount;

        _engine = LlamaEngine(LlamaBackend());

        await _engine!.loadModel(
          localPath,
          modelParams: ModelParams(
            numberOfThreads: threads,
            numberOfThreadsBatch: batchThreads,
            contextSize: 16384,
            gpuLayers: 99,
            batchSize: 2048,
            microBatchSize: 1024,
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

      // Build prompt efficiently with fewer allocations
      const int maxHistoryChars = 12000;
      final parts = <String>[];
      parts.add("<|im_start|>system\n$systemMessage\n<|im_end|>\n");

      if (history.isNotEmpty) {
        int historyChars = 0;
        for (final turn in history) {
          final role = turn['role'] ?? 'user';
          final content = turn['content'] ?? '';
          final segment = "<|im_start|>$role\n$content\n<|im_end|>\n";
          historyChars += segment.length;
          if (historyChars > maxHistoryChars) break;
          parts.add(segment);
        }
      }

      parts.add("<|im_start|>user\n$prompt\n<|im_end|>\n<|im_start|>assistant\n");
      final fullPrompt = parts.join();

      // Pre-compute stop markers for faster matching
      const stopSequences = [
        "<|im_end|>",
        "<|endoftext|>",
        "\nuser",
        "\nUser",
      ];

      final stream = _engine!.generate(
        fullPrompt,
        params: GenerationParams(
          temp: 0.1,
          maxTokens: maxTokens,
          penalty: 1.1,
          stopSequences: stopSequences,
        ),
      );

      // Batch tokens to reduce async yield overhead
      String accumulated = "";
      String batch = "";
      int batchCount = 0;
      const int batchSize = 4;

      await for (final token in stream) {
        accumulated += token;
        batch += token;
        batchCount++;

        if (batchCount >= batchSize) {
          // Check stop sequences only at tail of accumulated text
          final tailLen = accumulated.length < 20 ? accumulated.length : 20;
          bool shouldStop = false;
          for (final marker in stopSequences) {
            if (accumulated.indexOf(marker, accumulated.length - tailLen) != -1) {
              shouldStop = true;
              break;
            }
          }

          if (shouldStop) break;
          yield batch;
          batch = "";
          batchCount = 0;
        }
      }

      // Yield remaining batched tokens
      if (batch.isNotEmpty) {
        yield batch;
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
