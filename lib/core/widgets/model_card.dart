import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/hf_model.dart';
import '../providers/download_provider.dart';

class ModelCard extends ConsumerWidget {
  final HFModel model;

  const ModelCard({super.key, required this.model});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final downloadList = ref.watch(downloadProvider);
    final activeModel = downloadList.firstWhere((m) => m.id == model.id, orElse: () => model);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        activeModel.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${(activeModel.sizeMB / 1024).toStringAsFixed(1)} GB',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _ActionButton(model: activeModel),
              ],
            ),
            if (activeModel.downloadStatus == 'downloading') ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: activeModel.progress / 100,
                  minHeight: 4,
                  backgroundColor: colorScheme.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${activeModel.progress}% • ${activeModel.downloadSpeed?.toStringAsFixed(1) ?? '0.0'} MB/s',
                    style: TextStyle(fontSize: 11, color: colorScheme.secondary),
                  ),
                  Text(
                    '${((activeModel.sizeMB * activeModel.progress) / 102400).toStringAsFixed(1)} GB / ${(activeModel.sizeMB / 1024).toStringAsFixed(1)} GB',
                    style: TextStyle(fontSize: 11, color: colorScheme.secondary),
                  ),
                ],
              ),
            ],
            if (activeModel.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                activeModel.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.secondary,
                  height: 1.4,
                ),
              ),
            ],
            if (activeModel.capabilities.isNotEmpty) ...[
              const SizedBox(height: 12),
              _CapabilityTag(capabilities: activeModel.capabilities.take(5).toList()),
            ],
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

class _ActionButton extends ConsumerWidget {
  final HFModel model;

  const _ActionButton({required this.model});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    if (model.downloaded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Installed',
          style: TextStyle(
            color: colorScheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (model.downloadStatus == 'downloading') {
      return IconButton(
        icon: const Icon(Icons.pause_circle_outline),
        color: colorScheme.secondary,
        onPressed: () {},
      );
    }

    return FilledButton(
      onPressed: () => ref.read(downloadProvider.notifier).startDownload(model),
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
