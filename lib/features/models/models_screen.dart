import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/model_service.dart';
import '../../core/models/hf_model.dart';
import '../../core/providers/download_provider.dart';
import '../../core/theme/flux_theme.dart';
import '../../core/widgets/flux_widgets.dart';
import '../../core/widgets/flux_animations.dart';
import '../../l10n/app_localizations.dart';

/// Models — monochrome redesign.
///
/// Clean monochrome cards with soft shadows and no colored accents.
class ModelsScreen extends ConsumerStatefulWidget {
  const ModelsScreen({super.key});

  @override
  ConsumerState<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends ConsumerState<ModelsScreen> {
  List<HFModel> _availableModels = [];
  bool _isLoading = true;
  double _usedStorageGB = 0.0;
  double _totalStorageGB = 128.0;
  final Set<String> _downloadingIds = {};

  @override
  void initState() {
    super.initState();
    // Defer loading until after the page transition finishes (300ms) to prevent jank
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        _loadModels();
        _loadStorageInfo();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final models = ref.read(downloadProvider);
    _downloadingIds.removeWhere(
      (id) => !models.any(
          (m) => m.id == id && m.downloadStatus == 'downloading'),
    );
  }

  Future<void> _loadModels() async {
    final models = await ModelService.getRecommendedModels();
    if (mounted) {
      setState(() {
        _availableModels = models;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStorageInfo() async {
    final storage = await ModelService.getStorageSpace();
    final total = storage['total'] ?? 0;
    final free = storage['free'] ?? 0;
    if (total > 0 && mounted) {
      setState(() {
        _totalStorageGB = total / (1024 * 1024 * 1024);
        _usedStorageGB = (total - free) / (1024 * 1024 * 1024);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final models = ref.watch(downloadProvider);
    final downloading =
        models.where((m) => m.downloadStatus == 'downloading').toList();
    final installed = models.where((m) => m.downloaded).toList();
    final usedFraction =
        _totalStorageGB > 0 ? _usedStorageGB / _totalStorageGB : 0.0;
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final brightness = Theme.of(context).brightness;
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    final loc = AppLocalizations.of(context)!;

    final installedIds = installed.map((m) => m.id).toSet();
    final downloadingIds = downloading.map((m) => m.id).toSet();
    final trulyAvailable = _availableModels
        .where(
            (m) => !installedIds.contains(m.id) && !downloadingIds.contains(m.id))
        .toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: flux.background,
        body: Stack(
            children: [
              Positioned(
                left: 20,
                top: 48,
                child: FluxBackButton(onTap: () => context.pop()),
              ),
              Positioned(
                left: 20,
                top: 100,
                child: FluxTitle(title: loc.models),
              ),
              Positioned.fill(
                left: 20,
                right: 20,
                top: 156,
                child: RefreshIndicator(
                  onRefresh: () async {
                    await _loadModels();
                    await _loadStorageInfo();
                  },
                  color: flux.textPrimary,
                  backgroundColor: flux.surface,
                  child: ListView(
                    padding: EdgeInsets.only(bottom: bottomSafe + 24),
                    cacheExtent: 500,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _StorageCard(
                        used: _usedStorageGB,
                        total: _totalStorageGB,
                        fraction: usedFraction,
                      ),
                      if (downloading.isNotEmpty) ...[
                        const SizedBox(height: 26),
                        _SectionLabel(label: loc.downloading),
                        const SizedBox(height: 12),
                        for (int i = 0; i < downloading.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          _ModelCard(
                            model: downloading[i],
                            onPrimaryTap: () =>
                                _confirmCancel(downloading[i]),
                            isDownloadingHere:
                                _downloadingIds.contains(downloading[i].id),
                          ),
                        ],
                      ],
                      if (installed.isNotEmpty) ...[
                        const SizedBox(height: 26),
                        _SectionLabel(label: loc.installed),
                        const SizedBox(height: 12),
                        for (int i = 0; i < installed.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          _ModelCard(
                            model: installed[i],
                            onPrimaryTap: () => _confirmDelete(installed[i]),
                            isDownloadingHere: false,
                          ),
                        ],
                      ],
                      if (trulyAvailable.isNotEmpty) ...[
                        const SizedBox(height: 26),
                        _SectionLabel(label: loc.available),
                        const SizedBox(height: 12),
                        for (int i = 0; i < trulyAvailable.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          _ModelCard(
                            model: trulyAvailable[i],
                            onPrimaryTap: () =>
                                _startDownload(trulyAvailable[i]),
                            isDownloadingHere: false,
                          ),
                        ],
                      ],
                      if (_isLoading)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: CircularProgressIndicator(
                                color: flux.textPrimary, strokeWidth: 2),
                          ),
                        ),
                      if (!_isLoading &&
                          downloading.isEmpty &&
                          installed.isEmpty &&
                          trulyAvailable.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: FluxEmptyState(
                            icon: Icons.download_outlined,
                            title: loc.noModelsYet,
                            subtitle: loc.downloadModelToStart,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ),
    );
}

  void _startDownload(HFModel model) {
    final hasError = model.downloadStatus == 'error';
    _downloadingIds.add(model.id);
    if (hasError) ref.read(downloadProvider.notifier).clearError(model.id);
    final url = ModelService.getDownloadUrl(model.id);
    ref.read(downloadProvider.notifier).startDownloadWithUrl(model, url);
    HapticFeedback.lightImpact();
  }

  void _confirmDelete(HFModel model) {
    final loc = AppLocalizations.of(context)!;
    _showConfirm(
      title: loc.deleteModelQuestion,
      content: loc.deleteModelQuestion.replaceAll('{model}', model.name),
      actionText: loc.delete,
      destructive: true,
      onAction: () => ref.read(downloadProvider.notifier).deleteModel(model.id),
    );
  }

  void _confirmCancel(HFModel model) {
    final loc = AppLocalizations.of(context)!;
    _showConfirm(
      title: loc.cancelDownloadQuestion,
      content: loc.cancelDownloadQuestion.replaceAll('{model}', model.name),
      cancelText: loc.continueDownload,
      actionText: loc.cancelDownload,
      destructive: true,
      onAction: () {
        ref.read(downloadProvider.notifier).cancelDownload(model.id);
        _downloadingIds.remove(model.id);
      },
    );
  }

  void _showConfirm({
    required String title,
    required String content,
    required String actionText,
    String? cancelText,
    required VoidCallback onAction,
    bool destructive = false,
  }) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: flux.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FluxRadii.dialog)),
        title: Text(title, style: textTheme.headlineMedium),
        content: Text(content, style: textTheme.bodySmall),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Text(cancelText ?? loc.cancel,
                style:
                    textTheme.bodyMedium?.copyWith(color: flux.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              onAction();
              Navigator.pop(context);
            },
            child: Text(actionText,
                style: textTheme.bodyMedium?.copyWith(
                    color: destructive ? Colors.red : flux.textPrimary,
                    fontWeight: FontWeight.w400)),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        label.toUpperCase(),
        style: textTheme.labelLarge?.copyWith(
          color: flux.textSecondary,
          letterSpacing: 1.4,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _StorageCard extends StatelessWidget {
  final double used;
  final double total;
  final double fraction;

  const _StorageCard({
    required this.used,
    required this.total,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final loc = AppLocalizations.of(context)!;
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: flux.surface,
          borderRadius: BorderRadius.circular(FluxRadii.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _StickerChip(icon: Icons.sd_storage_rounded),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc.storage,
                          style: textTheme.bodyLarge),
                      const SizedBox(height: 2),
                      Text(
                        '${used.toStringAsFixed(1)} GB used · ${total.toStringAsFixed(0)} GB total',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0),
                backgroundColor: flux.border,
                valueColor: AlwaysStoppedAnimation(flux.textPrimary),
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  final HFModel model;
  final VoidCallback onPrimaryTap;
  final bool isDownloadingHere;

  const _ModelCard({
    required this.model,
    required this.onPrimaryTap,
    required this.isDownloadingHere,
  });

  String _formatSize(int sizeMB) {
    if (sizeMB >= 1024) return '${(sizeMB / 1024).toStringAsFixed(1)} GB';
    return '$sizeMB MB';
  }

  String _formatDownloadedSize() {
    final totalMB = model.sizeMB;
    final downloadedMB = (totalMB * model.progress / 100).round();
    if (totalMB >= 1024) {
      final dgb = (downloadedMB / 1024).toStringAsFixed(1);
      final tgb = (totalMB / 1024).toStringAsFixed(1);
      return '$dgb / $tgb GB';
    }
    return '$downloadedMB / $totalMB MB';
  }

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final loc = AppLocalizations.of(context)!;
    final isDownloaded = model.downloaded;
    final isDownloading = model.downloadStatus == 'downloading';
    final hasError = model.downloadStatus == 'error';

    IconData primaryIcon;
    if (isDownloaded) {
      primaryIcon = Icons.delete_outline_rounded;
    } else if (isDownloading) {
      primaryIcon = Icons.close_rounded;
    } else if (hasError) {
      primaryIcon = Icons.refresh_rounded;
    } else {
      primaryIcon = Icons.download_rounded;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      decoration: BoxDecoration(
        color: flux.surface,
        borderRadius: BorderRadius.circular(FluxRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ModelIconChip(flux: flux),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(model.name,
                        style: textTheme.bodyLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      '${loc.poweredBy} ${model.baseModel ?? model.name} · ${_formatSize(model.sizeMB)}',
                      style: textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              BouncyTap(
                onTap: onPrimaryTap,
                scaleDown: 0.86,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (isDownloading)
                        RepaintBoundary(
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: CircularProgressIndicator(
                              value: model.progress > 0
                                  ? model.progress / 100
                                  : null,
                              strokeWidth: 2.5,
                              backgroundColor:
                                  flux.textPrimary.withValues(alpha: 0.08),
                              valueColor:
                                  AlwaysStoppedAnimation(flux.textPrimary),
                            ),
                          ),
                        ),
                      Container(
                        width: isDownloading ? 34 : 44,
                        height: isDownloading ? 34 : 44,
                        decoration: BoxDecoration(
                          color: flux.textPrimary.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(primaryIcon,
                            size: isDownloading ? 15 : 18,
                            color: flux.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (isDownloading) ...[
            const SizedBox(height: 10),
            Text(
              '${model.progress}%${model.downloadSpeed != null && model.downloadSpeed! > 0 ? ' · ${model.downloadSpeed!.toStringAsFixed(1)} MB/s' : ''} · ${_formatDownloadedSize()}',
              style: textTheme.bodySmall
                  ?.copyWith(fontSize: 11, color: flux.textSecondary),
            ),
          ],
          if (hasError && model.errorMessage != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline,
                    size: 14, color: flux.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    model.errorMessage!,
                    style: textTheme.bodySmall
                        ?.copyWith(fontSize: 11, color: flux.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// SVG icon chip for model cards.
class _ModelIconChip extends StatelessWidget {
  final FluxColorsExtension flux;

  const _ModelIconChip({required this.flux});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: flux.textPrimary.withValues(alpha: 0.05),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: SvgPicture.asset(
          'assets/images/chip.svg',
          width: 22,
          height: 22,
          colorFilter: ColorFilter.mode(flux.textPrimary, BlendMode.srcIn),
        ),
      ),
    );
  }
}

/// Simple monochrome rounded icon container.
class _StickerChip extends StatelessWidget {
  final IconData icon;

  const _StickerChip({required this.icon});

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: flux.textPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Center(
        child: Icon(icon, size: 20, color: flux.textPrimary),
      ),
    );
  }
}
