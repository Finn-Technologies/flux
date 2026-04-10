import 'package:flutter/material.dart';
import '../../constants/mock_models.dart';

class ModelCard extends StatelessWidget {
  final HFModel model;
  final VoidCallback? onInstall;

  const ModelCard({super.key, required this.model, this.onInstall});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.memory,
                      size: 18, color: colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(model.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                        '${(model.sizeMB / 1024).toStringAsFixed(1)} GB',
                        style: TextStyle(
                            fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                _ActionButton(model: model, onInstall: onInstall),
              ],
            ),
            const SizedBox(height: 10),
            Text(model.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13, color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            _CapabilityTag(capabilities: model.capabilities),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _MetricBar(
                        label: 'Speed',
                        value: model.speed,
                        color: colorScheme.primary)),
                const SizedBox(width: 16),
                Expanded(
                    child: _MetricBar(
                        label: 'Quality',
                        value: model.quality,
                        color: colorScheme.tertiary)),
              ],
            ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: capabilities.map((c) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(c,
              style:
                  TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
        );
      }).toList(),
    );
  }
}

class _MetricBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MetricBar(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 11)),
            Text('${(value * 100).toInt()}%',
                style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final HFModel model;
  final VoidCallback? onInstall;

  const _ActionButton({required this.model, this.onInstall});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (model.downloaded) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
              onPressed: () {},
              child: const Text('Use', style: TextStyle(fontSize: 13))),
          TextButton(
            onPressed: () {},
            child: Text('Delete',
                style: TextStyle(fontSize: 13, color: colorScheme.error)),
          ),
        ],
      );
    }

    if (model.progress > 0 && model.progress < 100) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${model.progress}%', style: const TextStyle(fontSize: 12)),
          IconButton(
              icon: const Icon(Icons.pause, size: 20),
              onPressed: () {},
              visualDensity: VisualDensity.compact),
        ],
      );
    }

    return FilledButton.tonal(
      onPressed: onInstall,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text('Install', style: TextStyle(fontSize: 13)),
    );
  }
}
