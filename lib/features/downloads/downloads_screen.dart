import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  double _usedStorageGB = 0.0;
  double _totalStorageGB = 0.0;

  @override
  void initState() {
    super.initState();
    _loadStorageInfo();
  }

  Future<void> _loadStorageInfo() async {
    // TODO: Load actual storage info from ModelManager
    setState(() {
      _usedStorageGB = 0.0;
      _totalStorageGB = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final usedFraction =
        _totalStorageGB > 0 ? _usedStorageGB / _totalStorageGB : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Downloads',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Storage',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.secondary,
                      ),
                    ),
                    Text(
                      _totalStorageGB > 0
                          ? '${_usedStorageGB.toStringAsFixed(1)} GB / ${_totalStorageGB.toStringAsFixed(0)} GB'
                          : '0 GB',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: usedFraction,
                    backgroundColor:
                        colorScheme.outlineVariant.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _StorageIndicator(
                        color: colorScheme.primary, label: 'Used'),
                    const SizedBox(width: 24),
                    _StorageIndicator(
                        color: colorScheme.outlineVariant, label: 'Free'),
                  ],
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 350.ms)
              .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.download_outlined,
                    size: 36,
                    color: colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'No downloads yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Downloaded models will appear here.',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.secondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ).animate().fadeIn(delay: 150.ms, duration: 350.ms),
          ),
        ],
      ),
    );
  }
}

class _StorageIndicator extends StatelessWidget {
  final Color color;
  final String label;

  const _StorageIndicator({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: colorScheme.secondary),
        ),
      ],
    );
  }
}
