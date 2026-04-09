import 'package:flutter/material.dart';

class VoiceInputButton extends StatefulWidget {
  const VoiceInputButton({Key? key}) : super(key: key);

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton> {
  bool _recording = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(
        _recording ? Icons.mic : Icons.mic_none,
        color: _recording ? colorScheme.error : colorScheme.onSurfaceVariant,
      ),
      onPressed: () {
        setState(() => _recording = !_recording);
      },
      tooltip: _recording ? 'Stop recording' : 'Voice input',
    );
  }
}
