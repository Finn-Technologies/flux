import 'package:flutter/material.dart';

class AttachmentPreview extends StatelessWidget {
  final String name;
  final String type;
  const AttachmentPreview({required this.name, required this.type});

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$type: $name'));
  }
}
