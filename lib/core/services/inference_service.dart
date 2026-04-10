class InferenceService {
  // TODO: Wire to real on-device inference using llama.cpp / fllama / mlc-llm.
  // Temperature is hard-coded to 0.0 — deterministic output.
  // Integration points:
  //   - Load model: LlamaModel.fromFile(path)
  //   - Stream chat: model.startChat() -> stream tokens
  //   - Attachments: preprocess images/pdf/audio before feeding to model

  static const double temperature = 0.0;

  Stream<String> streamChat(
      {required String modelId, required String prompt}) async* {
    // TODO: Replace with real inference:
    //   final model = LlamaModel.fromFile('models/$modelId.gguf');
    //   final session = model.startChat();
    //   session.prompt(prompt, temperature: temperature, onToken: (token) => yield token);

    final mockResponse = _mockResponse();
    for (var i = 0; i < mockResponse.length; i++) {
      await Future.delayed(const Duration(milliseconds: 30));
      yield mockResponse[i];
    }
  }

  String _mockResponse() {
    return "This is a mock response. "
        "Real inference with a local model would produce an actual answer here. "
        "The streaming animation shows how tokens appear one by one.";
  }
}
