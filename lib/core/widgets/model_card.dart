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
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.memory,
                    size: 22,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${(model.sizeMB / 1024).toStringAsFixed(1)} GB',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _ActionButton(model: model, onInstall: onInstall),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              model.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.secondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            _CapabilityTag(capabilities: model.capabilities),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MetricBar(
                    label: 'Speed',
                    value: model.speed,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _MetricBar(
                    label: 'Quality',
                    value: model.quality,
                    color: colorScheme.primary,
                  ),
                ),
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
      spacing: 8,
      runSpacing: 6,
      children: capabilities.map((c) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            c.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.secondary,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MetricBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MetricBar({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            Text(
              '${(value * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
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
            child: const Text('Use', style: TextStyle(fontSize: 14)),
          ),
          TextButton(
            onPressed: () {},
            child: Text(
              'Delete',
              style: TextStyle(fontSize: 14, color: colorScheme.error),
            ),
          ),
        ],
      );
    }

    if (model.progress > 0 && model.progress < 100) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${model.progress}%', style: const TextStyle(fontSize: 13)),
          IconButton(icon: const Icon(Icons.pause, size: 20), onPressed: () {}),
        ],
      );
    }

    return FilledButton(
      onPressed: onInstall,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text(
        'Install',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }
}
