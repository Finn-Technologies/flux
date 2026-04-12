import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final isDownloading = activeModel.downloadStatus == 'downloading';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: activeModel.downloaded 
                            ? colorScheme.primary.withValues(alpha: 0.1)
                            : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          activeModel.downloaded ? Icons.check_circle : Icons.memory_outlined,
                          size: 24,
                          color: activeModel.downloaded ? colorScheme.primary : colorScheme.secondary,
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
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${(activeModel.sizeMB / 1024).toStringAsFixed(1)} GB • GGUF',
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.secondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _ActionButton(model: activeModel),
                    ],
                  ),
                  if (isDownloading) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: activeModel.progress / 100,
                              minHeight: 8,
                              backgroundColor: colorScheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${activeModel.progress}% • ${activeModel.downloadSpeed?.toStringAsFixed(1) ?? '0.0'} MB/s',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                        Text(
                          '${((activeModel.sizeMB * activeModel.progress) / 102400).toStringAsFixed(1)} GB / ${(activeModel.sizeMB / 1024).toStringAsFixed(1)} GB',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (activeModel.description.isNotEmpty && !isDownloading) ...[
                    const SizedBox(height: 16),
                    Text(
                      activeModel.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.secondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                  if (activeModel.capabilities.isNotEmpty && !isDownloading) ...[
                    const SizedBox(height: 14),
                    _CapabilityTags(capabilities: activeModel.capabilities.take(3).toList()),
                  ],
                ],
              ),
            ),
            if (activeModel.downloaded)
              _DeleteBar(model: activeModel),
          ],
        ),
      ),
    );
  }
}

class _CapabilityTags extends StatelessWidget {
  final List<String> capabilities;
  const _CapabilityTags({required this.capabilities});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: capabilities.map((c) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
          ),
          child: Text(
            c.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              color: colorScheme.secondary,
              fontWeight: FontWeight.w700,
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
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.download_done, color: colorScheme.primary, size: 20),
      );
    }

    if (model.downloadStatus == 'downloading') {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.pause, size: 18),
          onPressed: () {},
        ),
      );
    }

    return FilledButton(
      onPressed: () {
        HapticFeedback.mediumImpact();
        ref.read(downloadProvider.notifier).startDownload(model);
      },
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: const Text('Install', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

class _DeleteBar extends ConsumerWidget {
  final HFModel model;
  const _DeleteBar({required this.model});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          Icon(Icons.storage_rounded, size: 14, color: colorScheme.secondary),
          const SizedBox(width: 8),
          Text(
            'Saved in local storage',
            style: TextStyle(fontSize: 12, color: colorScheme.secondary, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _confirmDelete(context, ref),
            icon: Icon(Icons.delete_outline, size: 16, color: colorScheme.error),
            label: Text('Delete', style: TextStyle(color: colorScheme.error, fontSize: 13, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Model?'),
        content: Text('Are you sure you want to delete ${model.name}? You will need to download it again to use it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(downloadProvider.notifier).deleteModel(model.id);
              Navigator.pop(ctx);
            },
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}
