import 'package:flutter/services.dart';
import '../models/hf_model.dart';

class ModelService {
  static const _channel = MethodChannel('com.example.flux/storage');

  static final List<HFModel> _allModels = [
    HFModel(
      id: 'google/gemma-3-1b-it',
      name: 'Gemma 3 1B',
      description:
          'Ultra-lightweight model optimized for responsiveness and low memory usage. Perfect for basic assistance and fast chat.',
      sizeMB: 850,
      speed: 5.0,
      quality: 4.2,
      capabilities: ['chat', 'speed', 'low-ram'],
    ),
    HFModel(
      id: 'google/gemma-4-e2b-it',
      name: 'Gemma 4 E2B',
      description:
          'Balanced performance with enhanced reasoning capabilities. Ideal for complex instructions and structured tasks.',
      sizeMB: 1600,
      speed: 4.2,
      quality: 4.8,
      capabilities: ['chat', 'reasoning', 'balanced'],
    ),
    HFModel(
      id: 'google/gemma-4-e4b-it',
      name: 'Gemma 4 E4B',
      description:
          'High-performance flagship model. Excels at complex problem solving, creative writing, and deep analysis.',
      sizeMB: 3200,
      speed: 3.5,
      quality: 5.0,
      capabilities: ['chat', 'expert', 'reasoning'],
    ),
  ];

  static Future<int> getDeviceRAM() async {
    try {
      final memoryBytes = await _channel.invokeMethod<int>('getDeviceRAM');
      if (memoryBytes == null || memoryBytes <= 0) return 8;
      return (memoryBytes / (1024 * 1024 * 1024)).round();
    } on PlatformException {
      return 8;
    } catch (_) {
      return 4;
    }
  }

  static Future<List<HFModel>> getRecommendedModels() async {
    final ram = await getDeviceRAM();

    if (ram <= 4) {
      return _allModels.where((m) => m.name == 'Gemma 3 1B').toList();
    } else if (ram <= 6) {
      return _allModels
          .where((m) => m.name == 'Gemma 3 1B' || m.name == 'Gemma 4 E2B')
          .toList();
    } else {
      return List.from(_allModels);
    }
  }

  static String getDownloadUrl(String modelId) {
    switch (modelId) {
      case 'google/gemma-3-1b-it':
        return 'https://huggingface.co/MaziyarPanahi/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct.Q4_K_M.gguf';
      case 'google/gemma-4-e2b-it':
        return 'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf';
      case 'google/gemma-4-e4b-it':
        return 'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q8_0.gguf';
      default:
        return '';
    }
  }
}
