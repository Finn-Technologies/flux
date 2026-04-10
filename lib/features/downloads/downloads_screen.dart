import 'package:flutter/material.dart';
import '../../core/widgets/flux_drawer.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final List<_DownloadItem> _downloads = [
    _DownloadItem(name: 'Gemma 4 E2B', status: 'Downloading', progress: 0.65),
    _DownloadItem(name: 'Phi-3-mini', status: 'Completed', progress: 1.0),
    _DownloadItem(name: 'Llama 3.2 3B', status: 'Paused', progress: 0.3),
  ];

  void _togglePause(int index) {
    setState(() {
      final item = _downloads[index];
      item.status = item.status == 'Paused' ? 'Downloading' : 'Paused';
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const usedGB = 2.3;
    const totalGB = 8.0;
    const usedFraction = usedGB / totalGB;

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(7),
              ),
              child:
                  Icon(Icons.download, size: 15, color: colorScheme.onPrimary),
            ),
            const SizedBox(width: 10),
            const Text('Downloads',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(Icons.menu, color: colorScheme.onSurface),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),
      drawer: const FluxDrawer(currentItem: NavItem.downloads),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Storage',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant)),
                    Text(
                        '${usedGB.toStringAsFixed(1)} GB / ${totalGB.toStringAsFixed(0)} GB',
                        style: TextStyle(
                            fontSize: 12, color: colorScheme.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: usedFraction,
                    backgroundColor:
                        colorScheme.outlineVariant.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StorageDot(color: colorScheme.primary, label: 'Used'),
                    const SizedBox(width: 16),
                    _StorageDot(
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.5),
                        label: 'Free'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Active downloads',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(
              _downloads.length,
              (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _DownloadTile(
                      item: _downloads[i],
                      onToggle: () => _togglePause(i),
                    ),
                  )),
        ],
      ),
    );
  }
}

class _StorageDot extends StatelessWidget {
  final Color color;
  final String label;
  const _StorageDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style:
                TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _DownloadItem {
  final String name;
  String status;
  final double progress;
  _DownloadItem(
      {required this.name, required this.status, required this.progress});
}

class _DownloadTile extends StatelessWidget {
  final _DownloadItem item;
  final VoidCallback onToggle;

  const _DownloadTile({required this.item, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDone = item.progress >= 1.0;
    final isPaused = item.status == 'Paused';
    final isDownloading = item.status == 'Downloading';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDownloading
              ? colorScheme.primary.withValues(alpha: 0.3)
              : colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDone
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isDone ? Icons.check : Icons.memory,
              size: 20,
              color: isDone
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 6),
                if (!isDone) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: item.progress,
                      backgroundColor:
                          colorScheme.primary.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPaused ? 'Paused' : '${(item.progress * 100).toInt()}%',
                    style: TextStyle(
                        fontSize: 11, color: colorScheme.onSurfaceVariant),
                  ),
                ] else
                  Text('Ready to use',
                      style:
                          TextStyle(fontSize: 12, color: colorScheme.primary)),
              ],
            ),
          ),
          if (isDone)
            Icon(Icons.check_circle, color: colorScheme.primary, size: 22)
          else
            IconButton(
              icon: Icon(isPaused ? Icons.play_arrow : Icons.pause, size: 22),
              color: colorScheme.onSurfaceVariant,
              onPressed: onToggle,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
