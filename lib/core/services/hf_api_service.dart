// THIS SERVICE HAS BEEN REMOVED
// The Hugging Face API integration is currently disabled to resolve loading issues.
// All references to this service should be removed throughout the app.

class HfApiService {
  // Empty class to avoid breaking existing imports that might linger before full refactor
  Future<List<dynamic>> searchModels({String? query, String? capability}) async => [];
  Future<String?> getGgufFileUrl(String modelId) async => null;
}
