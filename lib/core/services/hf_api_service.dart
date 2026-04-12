import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:system_info_plus/system_info_plus.dart';
import '../models/hf_model.dart';
class HfApiService {
  Future<List<HFModel>> searchModels(
      {String? query, String? capability}) async {
    try {
      final queryParams = {
        'limit': '30',
        'sort': 'downloads',
        'direction': '-1',
        'expand': 'gguf',
      };

      if (query != null && query.isNotEmpty) {
        queryParams['search'] = query;
      }

      final filters = ['gguf', 'text-generation'];
      if (capability != null && capability.isNotEmpty) {
        if (capability == 'vision') {
          filters.add('image-to-text'); // Typical tag for vision models
        } else if (capability != 'chat') {
          filters.add(capability);
        }
      }
      
      queryParams['filter'] = filters.join(',');

      final uri = Uri.https('huggingface.co', '/api/models', queryParams);
      final response = await http.get(uri, headers: {
        'User-Agent': 'FluxApp/1.0 (Flutter; OpenSource)',
      });

      if (response.statusCode == 200) {
        int? deviceRamMB;
        try {
          deviceRamMB = await SystemInfoPlus.physicalMemory;
        } catch (_) {}
        
        // Handle fallback and byte-to-MB conversion
        if (deviceRamMB == null || deviceRamMB <= 0) {
          deviceRamMB = 8192; // Default to 8GB baseline
        } else if (deviceRamMB > 1000000) {
          deviceRamMB = deviceRamMB ~/ (1024 * 1024);
        }

        final List<dynamic> data = jsonDecode(response.body);
        final models = <HFModel>[];

        for (final json in data) {
          final tags = List<String>.from(json['tags'] ?? []);
          final ggufData = json['gguf'];
          
          int estimatedSizeMB = 0;
          if (ggufData != null && ggufData['totalFileSize'] != null) {
            // totalFileSize is often the sum of ALL quants in the repo.
            // We'll estimate a single model size as ~1/4 of the total or cap it.
            int totalMB = (ggufData['totalFileSize'] as int) ~/ (1024 * 1024);
            estimatedSizeMB = totalMB > 20000 ? totalMB ~/ 8 : totalMB ~/ 2;
          }
          
          if (estimatedSizeMB == 0) estimatedSizeMB = 4096; // 4GB default fallback

          // Filtering logic based on RAM requirements
          double maxAllowedMB;
          if (deviceRamMB <= 3500) {
            maxAllowedMB = deviceRamMB / 2;
          } else if (deviceRamMB <= 4500) {
            maxAllowedMB = deviceRamMB / 2;
          } else if (deviceRamMB <= 6500) {
            maxAllowedMB = deviceRamMB / 2;
          } else {
            maxAllowedMB = (deviceRamMB - 4096).toDouble();
          }

          if (estimatedSizeMB > maxAllowedMB) continue;

          models.add(HFModel(
            id: json['modelId'] ?? json['id'] ?? '',
            name: (json['modelId'] ?? json['id'] ?? '').split('/').last,
            description: json['pipeline_tag'] ?? 'Chat Model',
            sizeMB: estimatedSizeMB,
            speed: 0.0,
            quality: 0.0,
            capabilities: tags,
          ));
        }
        return models;
      } else {
        print('HF API Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching models: $e');
    }
    return [];
  }

  Future<String?> getGgufFileUrl(String modelId) async {
    try {
      final uri = Uri.https('huggingface.co', '/api/models/$modelId/tree/main');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List<dynamic> files = jsonDecode(response.body);
        // Look for common quantizations in order of preference
        final preferences = [
          'q4_k_m.gguf',
          'q4_0.gguf',
          'q5_k_m.gguf',
          'q8_0.gguf',
          'f16.gguf',
        ];

        for (final pref in preferences) {
          final match = files.firstWhere(
            (f) => (f['path'] as String).toLowerCase().endsWith(pref),
            orElse: () => null,
          );
          if (match != null) {
            return 'https://huggingface.co/$modelId/resolve/main/${match['path']}';
          }
        }

        // Fallback: any .gguf file
        final anyGguf = files.firstWhere(
          (f) => (f['path'] as String).toLowerCase().endsWith('.gguf'),
          orElse: () => null,
        );
        if (anyGguf != null) {
          return 'https://huggingface.co/$modelId/resolve/main/${anyGguf['path']}';
        }
      }
    } catch (e) {
      print('Error finding GGUF file: $e');
    }
    return null;
  }
}
