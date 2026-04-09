import 'package:flutter/material.dart';

class DownloadProgressTile extends StatelessWidget {
  final String modelName;
  final int progress;
  final String status;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;

  const DownloadProgressTile({
    super.key,
    required this.modelName,
    required this.progress,
    required this.status,
    this.onPause,
    this.onResume,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.download),
      title: Text(modelName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(status),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: progress / 100),
          Text('$progress%'),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == 'Downloading')
            IconButton(icon: const Icon(Icons.pause), onPressed: onPause)
          else if (status == 'Paused')
            IconButton(icon: const Icon(Icons.play_arrow), onPressed: onResume),
          IconButton(icon: const Icon(Icons.close), onPressed: onCancel),
        ],
      ),
      isThreeLine: true,
    );
  }
}
