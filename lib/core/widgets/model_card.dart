import 'package:flutter/material.dart';
import '../../constants/mock_models.dart';

class ModelCard extends StatelessWidget {
  final HFModel model;
  final VoidCallback? onInstall;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onDelete;

  const ModelCard({
    super.key,
    required this.model,
    this.onInstall,
    this.onPause,
    this.onResume,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.memory, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    model.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${(model.sizeMB / 1024).toStringAsFixed(1)} GB',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(model.description),
            const SizedBox(height: 8),
            Row(children: [_CapabilityTag(capabilities: model.capabilities)]),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _SpeedBar(speed: model.speed)),
                const SizedBox(width: 16),
                Expanded(child: _QualityBar(quality: model.quality)),
              ],
            ),
            const SizedBox(height: 12),
            _ActionButton(model: model),
          ],
        ),
      ),
    );
  }
}

class _CapabilityTag extends StatelessWidget {
  final List<String> capabilities;
  const _CapabilityTag({required this.capabilities});
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: capabilities.map((c) {
        return Chip(
          label: Text(c, style: const TextStyle(fontSize: 11)),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }
}

class _SpeedBar extends StatelessWidget {
  final double speed;
  const _SpeedBar({required this.speed});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Speed', style: Theme.of(context).textTheme.labelSmall),
        LinearProgressIndicator(value: speed),
      ],
    );
  }
}

class _QualityBar extends StatelessWidget {
  final double quality;
  const _QualityBar({required this.quality});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quality', style: Theme.of(context).textTheme.labelSmall),
        LinearProgressIndicator(value: quality),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final HFModel model;
  const _ActionButton({required this.model});
  @override
  Widget build(BuildContext context) {
    if (model.downloaded) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(onPressed: () {}, child: const Text('Use')),
          TextButton(onPressed: () {}, child: const Text('Delete')),
        ],
      );
    }
    if (model.progress > 0 && model.progress < 100) {
      return Row(
        children: [
          Expanded(child: LinearProgressIndicator(value: model.progress / 100)),
          Text(' ${model.progress}%'),
          TextButton(onPressed: () {}, child: const Text('Pause')),
        ],
      );
    }
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton(onPressed: () {}, child: const Text('Install')),
    );
  }
}
