import '../models/hf_model.dart';

class HfApiService {
  Future<List<HFModel>> searchModels(
      {String? query, String? capability}) async {
    // TODO: Replace with real HF API via huggingface_hub package.
    // No authentication token needed for public model browsing.
    //   - Search: api.listModels(search: query, filter: capability)
    //   - Info: api.modelInfo(modelId)
    //
    // Example:
    //   final api = HfApi();
    //   final models = await api.listModels(search: query);
    return [];
  }

  Future<HFModel?> getModelInfo(String modelId) async {
    return null;
  }
}
