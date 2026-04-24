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
        
        final threads = Platform.numberOfProcessors > 4 ? 4 : 2;
        _engine = LlamaEngine(LlamaBackend());
        // Disable noisy logs for production stability
        LlamaEngine.configureLogging(level: LlamaLogLevel.none);
        
        await _engine!.loadModel(
          localPath,
          modelParams: ModelParams(
            numberOfThreads: threads,
            numberOfThreadsBatch: threads,
            contextSize: 1024,
            gpuLayers: 0,
            batchSize: 512,
            microBatchSize: 512,
          ),
        );
        _loadedModelPath = localPath;
      }

      if (_engine == null) {
        yield "Error: Failed to load model engine.";
        return;
      }

      final systemMessage = systemPrompt ?? "You are Flux, an on-device AI. Answer concisely and accurately. Never hallucinate other conversations or users. Stop immediately after answering.";
      final fullPrompt = "<|im_start|>system\n$systemMessage\n<|im_end|>\n<|im_start|>user\n$prompt\n<|im_end|>\n<|im_start|>assistant\n";

      // Aggressive stop sequences to prevent continuation
      final stopSequences = [
        "<|im_end|>",
        "<|endoftext|>",
        "<|end_of_text|>",
        "<|eot_id|>",
        "\nuser",
        "\nUser",
        "\n###",
        "### User:",
        "User:",
      ];

      final stream = _engine!.generate(
        fullPrompt,
        params: GenerationParams(
          temp: 0.1, // Near-deterministic but avoids backend issues with exact 0.0
          maxTokens: 512,
          penalty: 1.1,
          stopSequences: stopSequences,
        ),
      );

      String accumulated = "";
      await for (final token in stream) {
        accumulated += token;

        // Manual backup stop check (some backends might not handle stopSequences perfectly)
        bool shouldStop = false;
        for (final marker in stopSequences) {
          if (accumulated.contains(marker)) {
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
