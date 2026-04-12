void main() {
  final queryParams = <String, dynamic>{
    'limit': '30',
    'expand': ['gguf', 'pipeline_tag', 'tags']
  };
  final uri = Uri.https('huggingface.co', '/api/models', queryParams);
  print(uri.toString());
}
