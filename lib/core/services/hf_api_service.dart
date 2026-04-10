import '../../constants/mock_models.dart';

class HfApiService {
  // TODO: Replace with real HF API via huggingface_hub package.
  // No authentication token needed for public model browsing.
  //   - Search: api.listModels(search: query, filter: capability)
  //   - Info: api.modelInfo(modelId)

  Future<List<HFModel>> searchModels(
      {String? query, String? capability}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    var models = getMockModels();
    if (query != null && query.isNotEmpty) {
      models = models
          .where((m) => m.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    if (capability != null && capability.isNotEmpty) {
      models =
          models.where((m) => m.capabilities.contains(capability)).toList();
    }
    return models;
  }

  Future<HFModel?> getModelInfo(String modelId) async {
    try {
      return getMockModels().firstWhere((m) => m.id == modelId);
    } catch (_) {
      return null;
    }
  }
}
