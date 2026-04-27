import 'dart:io';
import 'package:flutter/services.dart';
import '../models/hf_model.dart';

class ModelService {
  static const _channel = MethodChannel('com.example.flux/storage');

  // Flux lineup with Qwen 3.5 models (Unsloth GGUF quantizations)
  static final List<HFModel> _allModels = [
    HFModel(
      id: 'flux-lite-qwen-3.5-0.8b',
      name: 'Flux Lite',
      baseModel: 'Qwen 3.5 0.8B',
      description: 'Ultra-lightweight model for basic assistance and fast chat. Perfect for devices with limited RAM.',
      sizeMB: 533,
      requiredRAM: 4,
      speed: 5.0,
      quality: 4.0,
      capabilities: ['chat', 'speed', 'low-ram'],
    ),
    HFModel(
      id: 'flux-creative-qwen-3.5-0.8b',
      name: 'Flux Creative',
      baseModel: 'Qwen 3.5 0.8B',
      description: 'Optimized for creations and coding tasks. SOTA performance for HTML/CSS/JS in the sub-1B class.',
      sizeMB: 890,
      requiredRAM: 4,
      speed: 4.8,
      quality: 4.5,
      capabilities: ['code', 'creative', 'low-ram'],
    ),
    HFModel(
      id: 'flux-steady-qwen-3.5-2b',
      name: 'Flux Steady',
      baseModel: 'Qwen 3.5 2B',
      description: 'Balanced performance with enhanced reasoning. Ideal for complex instructions and structured tasks.',
      sizeMB: 1280,
      requiredRAM: 6,
      speed: 4.2,
      quality: 4.6,
      capabilities: ['chat', 'reasoning', 'balanced'],
    ),
    HFModel(
      id: 'flux-smart-qwen-3.5-4b',
      name: 'Flux Smart',
      baseModel: 'Qwen 3.5 4B',
      description: 'High-performance flagship model. Excels at complex problem solving, creative writing, and deep analysis.',
      sizeMB: 2740,
      requiredRAM: 8,
      speed: 3.5,
      quality: 5.0,
      capabilities: ['chat', 'expert', 'reasoning', 'creative'],
    ),
  ];

  static Future<int> getDeviceRAM() async {
    // Desktop platforms have ample RAM — no need for mobile method channel
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return 16;
    }
    try {
      final memoryBytes = await _channel.invokeMethod<int>('getDeviceRAM');
      if (memoryBytes == null || memoryBytes <= 0) return 4;
      return (memoryBytes / (1024 * 1024 * 1024)).round();
    } on PlatformException {
      return 4;
    } catch (_) {
      return 4;
    }
  }

  /// Get models available for the device's RAM
  /// 4GB: Only Flux Lite
  /// 6GB: Flux Lite + Steady
  /// 8GB+: All three
  static Future<List<HFModel>> getAvailableModels() async {
    final ram = await getDeviceRAM();
    return _allModels.where((m) => m.requiredRAM <= ram).toList();
  }

  /// Alias for getAvailableModels - used by UI components
  static Future<List<HFModel>> getRecommendedModels() async {
    return getAvailableModels();
  }

  /// Get all models (for settings/models page)
  static List<HFModel> getAllModels() => List.from(_allModels);

  static String getDownloadUrl(String modelId) {
    switch (modelId) {
      case 'flux-lite-qwen-3.5-0.8b':
        return 'https://huggingface.co/unsloth/Qwen3.5-0.8B-GGUF/resolve/main/Qwen3.5-0.8B-Q4_K_M.gguf';
      case 'flux-creative-qwen-3.5-0.8b':
        return 'https://huggingface.co/unsloth/Qwen3.5-0.8B-GGUF/resolve/main/Qwen3.5-0.8B-Q8_0.gguf';
      case 'flux-steady-qwen-3.5-2b':
        return 'https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/main/Qwen3.5-2B-Q4_K_M.gguf';
      case 'flux-smart-qwen-3.5-4b':
        return 'https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/resolve/main/Qwen3.5-4B-Q4_K_M.gguf';
      default:
        return '';
    }
  }
}
