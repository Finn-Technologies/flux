import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/hf_model.dart';

class ModelService {
  static const _channel = MethodChannel('com.example.flux/storage');

  // New Flux lineup with Qwen 3.5 models
  static final List<HFModel> _allModels = [
    HFModel(
      id: 'flux-lite-qwen-3.5-0.8b',
      name: 'Flux Lite',
      baseModel: 'Qwen 3.5 0.8B',
      description: 'Ultra-lightweight model for basic assistance and fast chat. Perfect for devices with limited RAM.',
      sizeMB: 500,
      requiredRAM: 4,
      speed: 5.0,
      quality: 4.0,
      capabilities: ['chat', 'speed', 'low-ram'],
    ),
    HFModel(
      id: 'flux-steady-qwen-3.5-2b',
      name: 'Flux Steady',
      baseModel: 'Qwen 3.5 2B',
      description: 'Balanced performance with enhanced reasoning. Ideal for complex instructions and structured tasks.',
      sizeMB: 1300,
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
      sizeMB: 2600,
      requiredRAM: 8,
      speed: 3.5,
      quality: 5.0,
      capabilities: ['chat', 'expert', 'reasoning', 'creative'],
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
        return 'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf';
      case 'flux-steady-qwen-3.5-2b':
        return 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf';
      case 'flux-smart-qwen-3.5-4b':
        return 'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf';
      default:
        return '';
    }
  }

  /// Delete a downloaded model from the device
  static Future<bool> deleteModel(String modelId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory('${appDir.path}/models');
      
      if (!await modelsDir.exists()) {
        return false;
      }

      // Find and delete the model file
      final modelFile = File('${modelsDir.path}/${modelId.replaceAll('/', '_')}.gguf');
      if (await modelFile.exists()) {
        await modelFile.delete();
        return true;
      }

      return false;
    } catch (e) {
      print('Error deleting model: $e');
      return false;
    }
  }

  /// Get the local path for a model if downloaded
  static Future<String?> getModelLocalPath(String modelId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelFile = File('${appDir.path}/models/${modelId.replaceAll('/', '_')}.gguf');
    
    if (await modelFile.exists()) {
      return modelFile.path;
    }
    return null;
  }
}
