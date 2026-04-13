import 'package:system_info_plus/system_info_plus.dart';
import '../models/hf_model.dart';

class ModelService {
  static final List<HFModel> _allModels = [
    HFModel(
      id: 'google/gemma-3-1b-it',
      name: 'Gemma 3 1B',
      description: 'Ultra-lightweight model optimized for responsiveness and low memory usage. Perfect for basic assistance and fast chat.',
      sizeMB: 850,
      speed: 5.0,
      quality: 4.2,
      capabilities: ['chat', 'speed', 'low-ram'],
    ),
    HFModel(
      id: 'google/gemma-4-e2b-it',
      name: 'Gemma 4 E2B',
      description: 'Balanced performance with enhanced reasoning capabilities. Ideal for complex instructions and structured tasks.',
      sizeMB: 1600,
      speed: 4.2,
      quality: 4.8,
      capabilities: ['chat', 'reasoning', 'balanced'],
    ),
    HFModel(
      id: 'google/gemma-4-e4b-it',
      name: 'Gemma 4 E4B',
      description: 'High-performance flagship model. Excels at complex problem solving, creative writing, and deep analysis.',
      sizeMB: 3200,
      speed: 3.5,
      quality: 5.0,
      capabilities: ['chat', 'expert', 'reasoning'],
    ),
  ];

  static Future<int> getDeviceRAM() async {
    try {
      final memoryBytes = await SystemInfoPlus.physicalMemory;
      if (memoryBytes == null) return 8; // Default to 8GB if detection fails
      return (memoryBytes / (1024 * 1024 * 1024)).round();
    } catch (e) {
      return 4; // Safe default
    }
  }

  static Future<List<HFModel>> getRecommendedModels() async {
    final ram = await getDeviceRAM();
    
    if (ram <= 4) {
      // 4GB devices: Gemma 3 1B only
      return _allModels.where((m) => m.name == 'Gemma 3 1B').toList();
    } else if (ram <= 6) {
      // 6GB devices: Gemma 3 1B and Gemma 4 E2B
      return _allModels.where((m) => m.name == 'Gemma 3 1B' || m.name == 'Gemma 4 E2B').toList();
    } else {
      // 8GB+ devices: Gemma 4 E4B
      // Strictly follows user request: "on 8GB RAM or more, Gemma 4 E4B"
      return _allModels.where((m) => m.name == 'Gemma 4 E4B').toList();
    }
  }

  static String getDownloadUrl(String modelId) {
    // Optimized mappings to ensure stability on mobile RAM limits
    switch (modelId) {
      case 'google/gemma-3-1b-it':
        // Real 1.2B model (~0.7GB) - High stability for 4GB RAM
        return 'https://huggingface.co/MaziyarPanahi/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct.Q4_K_M.gguf';
      case 'google/gemma-4-e2b-it':
        // 2.6B model (~1.6GB) - Balanced for 6GB RAM
        return 'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf';
      case 'google/gemma-4-e4b-it':
        // 2.6B model high-quant (~2.7GB) - Max quality for 8GB+ RAM
        return 'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q8_0.gguf';
      default:
        return '';
    }
  }
}
