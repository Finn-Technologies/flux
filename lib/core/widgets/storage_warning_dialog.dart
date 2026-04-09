import 'package:flutter/material.dart';

class StorageWarningDialog extends StatelessWidget {
  final int usedMB;
  final int freeMB;
  const StorageWarningDialog({required this.usedMB, required this.freeMB});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Low storage'),
      content: Text(
        'Used: ${usedMB} MB, Free: ${freeMB} MB. Consider clearing cache.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
