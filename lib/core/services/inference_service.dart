import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:llamadart/llamadart.dart';
import 'package:path_provider/path_provider.dart';
import 'model_service.dart';

class InferenceService {
  static final InferenceService _instance = InferenceService._internal();
  factory InferenceService() => _instance;
  InferenceService._internal() {
    LlamaEngine.configureLogging(level: LlamaLogLevel.none);
  }

  LlamaEngine? _engine;
  String? _loadedModelPath;

  double _lastPromptTokPerSec = 0;
  double _lastOutputTokPerSec = 0;
  int _lastPromptTokens = 0;
  int _lastOutputTokens = 0;

  double get lastPromptTokPerSec => _lastPromptTokPerSec;
  double get lastOutputTokPerSec => _lastOutputTokPerSec;
  int get lastPromptTokens => _lastPromptTokens;
  int get lastOutputTokens => _lastOutputTokens;

  bool get isLoaded => _engine != null && _loadedModelPath != null;

  String? get modelName =>
      _loadedModelPath?.split('/').last.replaceAll('.gguf', '');

  String? get modelPath => _loadedModelPath;

  int get contextSize => _contextSize ?? 2048;
  int? _contextSize;

  /// Detect optimal GPU layers for the current device.
  /// On desktop with sufficient RAM (8GB+), offload some layers to GPU.
  /// On mobile and low-RAM desktops, keep all layers on CPU.
  /// The layer counts are intentionally higher than most model architectures;
  /// llama.cpp safely clamps to the actual layer count of the loaded model.
  static int _detectOptimalGpuLayers() {
    if (Platform.isAndroid || Platform.isIOS) return 0;
    try {
      final totalMem = _deviceTotalMemoryMB();
      // 8GB+ RAM: aggressive GPU offload (safe upper bound, clamped by engine)
      if (totalMem >= 8192) return 33;
      // 6-8GB RAM: conservative GPU offload
      if (totalMem >= 6000) return 16;
    } catch (_) {}
    return 0;
  }

  static int _deviceTotalMemoryMB() {
    try {
      if (Platform.isMacOS) {
        final result = Process.runSync('sysctl', ['-n', 'hw.memsize']);
        if (result.exitCode == 0) {
          final memBytes = int.tryParse(result.stdout.toString().trim()) ?? 0;
          return memBytes ~/ (1024 * 1024);
        }
      } else if (Platform.isLinux) {
        final result = Process.runSync('free', ['-b']);
        if (result.exitCode == 0) {
          final lines = result.stdout.toString().trim().split('\n');
          if (lines.length > 1) {
            final parts = lines[1].split(RegExp(r'\s+'));
            if (parts.length > 1) {
              return (int.tryParse(parts[1]) ?? 0) ~/ (1024 * 1024);
            }
          }
        }
      }
    } catch (_) {}
    return 0;
  }

  Future<String> loadModel(String localPath) async {
    if (!File(localPath).existsSync()) {
      throw Exception('Model file not found: $localPath');
    }

    if (_loadedModelPath == localPath && _engine != null) {
      return localPath;
    }

    if (_engine != null) {
      await _engine!.dispose();
      _engine = null;
    }

    final fileSizeMB = File(localPath).lengthSync() ~/ (1024 * 1024);
    final mmProjPath = localPath.replaceAll('.gguf', '.mmproj');
    final hasVision = File(mmProjPath).existsSync();

    // Dynamically scale context size based on platform and available RAM to optimize memory on mobile
    int ctx = 2048;
    if (Platform.isAndroid || Platform.isIOS) {
      final ram = await ModelService.getDeviceRAM();
      if (ram <= 4) {
        ctx = 2048; // Safe fallback to prevent OOM crashes on low-end devices
      } else if (ram <= 8) {
        // OnePlus Nord 1 / typical mid-range device (6GB - 8GB RAM):
        // Lite model can run with 4096 context, Steady/Smart models with 3072 context
        ctx = fileSizeMB < 300 ? 4096 : 3072;
      } else {
        // High-end mobile devices (12GB+ RAM): 4096 context for all models
        ctx = 4096;
      }
    } else {
      // Desktop platforms: keep high context size since there is plenty of memory and swap space
      ctx = fileSizeMB < 300
          ? 4096
          : (fileSizeMB < 1000 ? 6144 : 8192);
    }

    final gpuLayers = _detectOptimalGpuLayers();

    _engine = LlamaEngine(LlamaBackend());

    // Configure model with optimized parameters:
    // - On mobile: enable Flash Attention and Q8_0 KV Cache quantization to reduce RAM by 50%
    final isMobile = Platform.isAndroid || Platform.isIOS;
    await _engine!.loadModel(
      localPath,
      modelParams: ModelParams(
        contextSize: ctx,
        gpuLayers: gpuLayers,
        batchSize: 1024,
        microBatchSize: 512,
        flashAttention: isMobile ? FlashAttention.enabled : FlashAttention.auto,
        cacheTypeK: isMobile ? KvCacheType.q8_0 : KvCacheType.f16,
        cacheTypeV: isMobile ? KvCacheType.q8_0 : KvCacheType.f16,
      ),
    );

    if (hasVision) {
      await _engine!.loadMultimodalProjector(mmProjPath);
    }

    _loadedModelPath = localPath;
    _contextSize = ctx;
    return localPath;
  }

  /// Pre-warm the engine by loading the model in the background.
  /// Call this on app start so the first message is near-instant.
  Future<void> warmUp(String modelId) async {
    // Loads the last-used model in the background so it's ready.
    try {
      final directory = await getApplicationDocumentsDirectory();
      final modelPath = '${directory.path}/models/${modelId.replaceAll('/', '_')}.gguf';
      if (File(modelPath).existsSync()) {
        await loadModel(modelPath);
      }
    } catch (_) {
      // Silently ignore — inference will lazy-load if warmup fails
    }
  }
  Future<void> unloadModel() async {
    if (_engine != null) {
      await _engine!.dispose();
      _engine = null;
    }
    _loadedModelPath = null;
  }

  /// Create a completion stream from pre-built messages and tools.
  /// Used by FluxCodeAgent which manages its own conversation context.
  Stream<LlamaCompletionChunk>? createStream({
    required List<LlamaChatMessage> messages,
    List<ToolDefinition>? tools,
    required String localPath,
    double temp = 0.0,
  }) {
    try {
      if (_loadedModelPath != localPath || _engine == null) return null;

      const stopSequences = [
        "<|im_end|>",
        "<|endoftext|>",
      ];

      final params = GenerationParams(
        temp: temp,
        maxTokens: 4096,
        stopSequences: stopSequences,
        streamBatchTokenThreshold: 8,
        streamBatchByteThreshold: 512,
        reusePromptPrefix: true,
        penalty: 1.0,
      );

      return _engine!.create(messages, params: params, tools: tools);
    } catch (e) {
      return null;
    }
  }

  Stream<String> streamChat({
    required String modelId,
    required String prompt,
    String? localPath,
    String? systemPrompt,
    List<Map<String, String>> history = const [],
    int maxTokens = 4096,
    List<String>? imagePaths,
    List<ToolDefinition>? tools,
  }) async* {
    if (localPath == null || !File(localPath).existsSync()) {
      yield "Error: Local model file not found at $localPath.";
      return;
    }

    try {
      if (_loadedModelPath != localPath) {
        await loadModel(localPath);
      }

      if (_engine == null) {
        yield "Error: Failed to load model engine.";
        return;
      }

      final messages = <LlamaChatMessage>[];

      final effectiveSystem = systemPrompt ??
          "You are Flux, an on-device AI. Answer concisely. Stop after answering.";
      messages.add(LlamaChatMessage.fromText(
        role: LlamaChatRole.system,
        text: effectiveSystem,
      ));

      int historyChars = 0;
      const int maxHistoryChars = 8000;
      for (final turn in history) {
        final role = turn['role'] ?? 'user';
        final content = turn['content'] ?? '';
        historyChars += content.length;
        if (historyChars > maxHistoryChars) break;
        messages.add(LlamaChatMessage.fromText(
          role: role == 'assistant'
              ? LlamaChatRole.assistant
              : LlamaChatRole.user,
          text: content,
        ));
      }

      if (imagePaths != null && imagePaths.isNotEmpty) {
        final parts = <LlamaContentPart>[
          LlamaTextContent(prompt),
          for (final path in imagePaths) LlamaImageContent(path: path),
        ];
        messages.add(LlamaChatMessage.withContent(
          role: LlamaChatRole.user,
          content: parts,
        ));
      } else {
        messages.add(LlamaChatMessage.fromText(
          role: LlamaChatRole.user,
          text: prompt,
        ));
      }

      final totalPromptChars = effectiveSystem.length + historyChars + prompt.length;
      final estimatedPromptTokens = (totalPromptChars / 3.5).round();

      const stopSequences = [
        "<|im_end|>",
        "<|endoftext|>",
      ];

      final baseParams = GenerationParams(
        temp: 0.0,
        maxTokens: maxTokens,
        stopSequences: stopSequences,
        streamBatchTokenThreshold: 1,
        streamBatchByteThreshold: 1,
        reusePromptPrefix: true,
        penalty: 1.0,
      );

      final stopwatch = Stopwatch()..start();
      int tokenCount = 0;
      bool firstTokenEmitted = false;

      const maxToolRounds = 5;
      int consecutiveFailures = 0;

      for (int round = 0; round < maxToolRounds; round++) {
        final stream = _engine!.create(
          messages,
          params: baseParams,
          tools: tools,
        );

        List<LlamaCompletionChunkToolCall>? lastToolCalls;
        bool hasEmittedContent = false;

        await for (final chunk in stream) {
          for (final choice in chunk.choices) {
            if (choice.delta.content != null) {
              final text = choice.delta.content!;
              if (!firstTokenEmitted) {
                final ttftMs = stopwatch.elapsedMilliseconds;
                if (ttftMs > 0) {
                  _lastPromptTokPerSec =
                      estimatedPromptTokens / (ttftMs / 1000.0);
                }
                _lastPromptTokens = estimatedPromptTokens;
                firstTokenEmitted = true;
              }
              tokenCount += (text.length / 3.5).round();
              yield text;
              hasEmittedContent = true;
            }
            if (choice.delta.toolCalls != null &&
                choice.delta.toolCalls!.isNotEmpty) {
              lastToolCalls = choice.delta.toolCalls;
            }
          }
        }

        if (!hasEmittedContent && !firstTokenEmitted) {
          final ttftMs = stopwatch.elapsedMilliseconds;
          if (ttftMs > 0) {
            _lastPromptTokPerSec =
                estimatedPromptTokens / (ttftMs / 1000.0);
          }
          _lastPromptTokens = estimatedPromptTokens;
          firstTokenEmitted = true;
        }

        // No tool calls — done
        if (lastToolCalls == null ||
            lastToolCalls.isEmpty ||
            tools == null ||
            tools.isEmpty) {
          break;
        }

        // Too many consecutive failures — give up
        if (consecutiveFailures >= 5) {
          yield '\n\n(Too many tool errors. Stopping.)';
          break;
        }

        // Add assistant message with the tool calls
        messages.add(LlamaChatMessage.withContent(
          role: LlamaChatRole.assistant,
          content: [
            for (final tc in lastToolCalls)
              LlamaToolCallContent(
                id: tc.id,
                name: tc.function?.name ?? 'unknown',
                arguments: tc.function?.arguments != null
                    ? jsonDecode(tc.function!.arguments!)
                        as Map<String, dynamic>
                    : {},
                rawJson: tc.function?.arguments ?? '{}',
              ),
          ],
        ));

        // Execute each tool call
        var anySuccess = false;
        for (final tc in lastToolCalls) {
          final toolName = tc.function?.name ?? 'unknown';
          final toolArgs = tc.function?.arguments ?? '{}';

          yield '\n> *Running $toolName...*\n';

          String result;
          try {
            final def = tools.firstWhere(
              (t) => t.name == toolName,
              orElse: () => throw Exception('Unknown tool: $toolName'),
            );
            final args = jsonDecode(toolArgs) as Map<String, dynamic>;
            final raw = await def.invoke(args);
            result = raw?.toString() ?? '(no output)';
            anySuccess = true;
          } catch (e) {
            result = 'Error: $e';
          }

          // Show truncated result
          final short = result.length > 400
              ? '${result.substring(0, 400)}\n... (truncated)'
              : result;
          yield '$short\n';

          messages.add(LlamaChatMessage.withContent(
            role: LlamaChatRole.tool,
            content: [
              LlamaToolResultContent(
                id: tc.id,
                name: toolName,
                result: result,
              ),
            ],
          ));
        }

        consecutiveFailures = anySuccess ? 0 : consecutiveFailures + 1;
      }

      final elapsedMs = stopwatch.elapsedMilliseconds;
      if (elapsedMs > 0 && tokenCount > 0) {
        _lastOutputTokPerSec = tokenCount / (elapsedMs / 1000.0);
        _lastOutputTokens = tokenCount;
      }
    } catch (e) {
      yield "Error: ${e.toString()}";
    }
  }

}
