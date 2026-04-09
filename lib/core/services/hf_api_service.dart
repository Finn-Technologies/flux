import '../../constants/mock_models.dart';

class HfApiService {
  // TODO: Replace with real HF API calls using the `huggingface_hub` package.
  // Endpoints to implement:
  //   - Search models: GET /api/models?search={query}&filter={capability}
  //   - Model info: GET /api/models/{modelId}
  //   - Download model files: GET /api/models/{modelId}/resolve/{filename}
  // No authentication token needed for public model browsing.

  Future<List<HFModel>> searchModels({
    String? query,
    String? capability,
  }) async {
    // TODO: Wire to HF Hub API via huggingface_hub package.
    // Example:
    //   final api = HfApi();
    //   final results = await api.listModels(
    //     search: query,
    //     filter: capability,
    //     sort: ModelsSortParameter.Downloads,
    //     direction: SortDirection.Descending,
    //     limit: 20,
    //   );
    //   return results.map((r) => HFModel(...)).toList();

    await Future.delayed(const Duration(milliseconds: 300));
    var models = getMockModels();
    if (query != null && query.isNotEmpty) {
      models = models
          .where((m) => m.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    if (capability != null && capability.isNotEmpty) {
      models = models
          .where((m) => m.capabilities.contains(capability))
          .toList();
    }
    return models;
  }

  Future<HFModel?> getModelInfo(String modelId) async {
    // TODO: Fetch model metadata from HF Hub API.
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      return getMockModels().firstWhere((m) => m.id == modelId);
    } catch (_) {
      return null;
    }
  }
}
