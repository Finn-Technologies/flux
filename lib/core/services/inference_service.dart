class InferenceService {
  // TODO: Wire to real on-device inference using llama.cpp / fllama / mlc-llm.
  // Temperature is hard-coded to 0.0 — deterministic output.
  // No advanced parameters exposed in the UI.
  //
  // Integration points:
  //   - Load model: LlamaModel.fromFile(path)
  //   - Stream chat: model.startChat() -> stream tokens
  //   - Run action: model.runTool(action, params)
  //   - Audio input: use record + whisper.cpp pipeline
  //   - Attachments: preprocess images/pdf/audio before feeding to model

  static const double temperature = 0.0;

  Stream<String> streamChat({
    required String modelId,
    required String prompt,
    List<String>? attachments,
  }) async* {
    // TODO: Replace with real inference:
    //   final model = LlamaModel.fromFile('models/$modelId.gguf');
    //   final session = model.startChat();
    //   session.prompt(
    //     prompt,
    //     temperature: temperature,
    //     onToken: (token) => yield token,
    //   );

    // Mock streaming: simulate token-by-token output with a delay.
    final mockResponse = _mockResponse(prompt);
    for (var i = 0; i < mockResponse.length; i++) {
      await Future.delayed(const Duration(milliseconds: 30));
      yield mockResponse[i];
    }
  }

  Future<String> runAction({
    required String modelId,
    required String action,
    Map<String, dynamic>? params,
  }) async {
    // TODO: Run tool-use model for actions like "set timer", "turn on flashlight".
    //   final result = model.runTool(action, params);
    //   return result;

    await Future.delayed(const Duration(seconds: 1));
    return _mockActionResult(action);
  }

  String _mockResponse(String prompt) {
    if (prompt.toLowerCase().contains('hello')) {
      return "Hello! I'm Flux, running locally on your device. How can I help you today?";
    }
    if (prompt.toLowerCase().contains('summarize')) {
      return "Here's a summary: Mock response demonstrates the streaming UI. "
          "The actual inference would be powered by a local llama.cpp model. "
          "Your data stays on your device.";
    }
    return "This is a mock response. "
        "Temperature is set to 0.0 for deterministic output. "
        "Real inference with local model would produce an actual answer here. "
        "The streaming animation shows how tokens appear one by one.";
  }

  String _mockActionResult(String action) {
    switch (action) {
      case 'set_timer':
        return 'Timer set for 5 minutes (mock)';
      case 'turn_on_flashlight':
        return 'Flashlight turned on (mock)';
      case 'summarize_page':
        return 'Page summarized: Flux is a private AI assistant (mock)';
      default:
        return 'Action "$action" completed (mock)';
    }
  }
}
