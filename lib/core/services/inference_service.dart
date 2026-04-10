class InferenceService {
  static const double temperature = 0.0;

  Stream<String> streamChat(
      {required String modelId, required String prompt}) async* {
    // TODO: Replace with real on-device inference using llama.cpp / fllama / mlc-llm.
    // Integration points:
    //   - Load model: LlamaModel.fromFile(path)
    //   - Stream chat: model.startChat() -> stream tokens
    //   - Attachments: preprocess images/pdf/audio before feeding to model
    //
    // Example:
    //   final model = LlamaModel.fromFile('models/$modelId.gguf');
    //   final session = model.startChat();
    //   session.prompt(prompt, temperature: temperature, onToken: (token) => yield token);
  }
}
