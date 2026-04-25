import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/model_service.dart';
import '../../core/models/hf_model.dart';
import '../../core/providers/download_provider.dart';
import '../../core/theme/flux_theme.dart';
import '../../core/widgets/animated_tap_card.dart';
import '../../core/widgets/flux_widgets.dart';
import '../../l10n/app_localizations.dart';

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

  @override
  void initState() {
    super.initState();
    _loadModels();
    _loadStorageInfo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final models = ref.read(downloadProvider);
    _downloadingIds.removeWhere(
      (id) => !models.any((m) => m.id == id && m.downloadStatus == 'downloading'),
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
    const platform = MethodChannel('com.example.flux/storage');
    try {
      final Map<dynamic, dynamic> result = await platform.invokeMethod('getStorageSpace');
      final total = (result['total'] as int) / (1024 * 1024 * 1024);
      final free = (result['free'] as int) / (1024 * 1024 * 1024);
      
      if (mounted) {
        setState(() {
          _totalStorageGB = total;
          _usedStorageGB = total - free;
        });
      }
    } catch (e) {
      debugPrint('Error getting storage info: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final models = ref.watch(downloadProvider);
    final downloadingModels = models.where((m) => m.downloadStatus == 'downloading').toList();
    final installedModels = models.where((m) => m.downloaded).toList();
    final usedFraction = _totalStorageGB > 0 ? _usedStorageGB / _totalStorageGB : 0.0;
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
      backgroundColor: flux.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: 20,
              top: 48,
              child: FluxBackButton(onTap: () => context.pop()),
            ),

            Positioned(
              left: 20,
              top: 100,
              child: FluxTitle(title: AppLocalizations.of(context)!.models),
            ),

            Positioned(
              left: 20,
              right: 20,
              top: 160,
              bottom: 108,
              child: RefreshIndicator(
                onRefresh: () async {
                  await _loadModels();
                  await _loadStorageInfo();
                },
                color: flux.textPrimary,
                backgroundColor: flux.surface,
                child: ListView(
                padding: EdgeInsets.zero,
                cacheExtent: 500,
                children: [
                  RepaintBoundary(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: flux.surface,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: flux.border,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Storage',
                                style: textTheme.bodySmall,
                              ),
                              Text(
                                '${_usedStorageGB.toStringAsFixed(1)} GB / ${_totalStorageGB.toStringAsFixed(0)} GB',
                                style: textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: usedFraction,
                              backgroundColor: flux.border,
                              valueColor: AlwaysStoppedAnimation(flux.textPrimary),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (downloadingModels.isNotEmpty) ...[
                    Text(
                      AppLocalizations.of(context)!.downloading,
                      style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    ...downloadingModels.asMap().entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildModelCard(entry.value, entry.key),
                    )),
                    const SizedBox(height: 24),
                  ],

                  if (installedModels.isNotEmpty) ...[
                    Text(
                      'Installed',
                      style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    ...installedModels.asMap().entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildModelCard(entry.value, entry.key),
                    )),
                    const SizedBox(height: 24),
                  ],

                  if (_isLoading)
                    Center(
                      child: CircularProgressIndicator(color: flux.textPrimary),
                    )
                  else ...[
                    Builder(builder: (context) {
                      final installedIds = installedModels.map((m) => m.id).toSet();
                      final downloadingIds = downloadingModels.map((m) => m.id).toSet();
                      final trulyAvailable = _availableModels.where((m) {
                        return !installedIds.contains(m.id) && !downloadingIds.contains(m.id);
                      }).toList();
                      
                      if (trulyAvailable.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Available',
                            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          ...trulyAvailable.asMap().entries.map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildModelCard(entry.value, entry.key),
                          )),
                        ],
                      );
                    }),
                  ],

                  if (downloadingModels.isEmpty && installedModels.isEmpty && !_isLoading)
                    Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 40),
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: flux.border,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Icon(
                              Icons.download_outlined,
                              size: 36,
                              color: flux.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            AppLocalizations.of(context)!.noModelsYet,
                            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context)!.downloadModelToStart,
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  String _formatSize(int sizeMB) {
    if (sizeMB >= 1024) {
      return '${(sizeMB / 1024).toStringAsFixed(1)} GB';
    } else {
      return '$sizeMB MB';
    }
  }

  String _formatDownloadedSize(HFModel model) {
    final totalMB = model.sizeMB;
    final downloadedMB = (totalMB * model.progress / 100).round();
    
    if (totalMB >= 1024) {
      final downloadedGB = (downloadedMB / 1024).toStringAsFixed(1);
      final totalGB = (totalMB / 1024).toStringAsFixed(1);
      return '$downloadedGB GB / $totalGB GB';
    } else {
      return '$downloadedMB MB / $totalMB MB';
    }
  }

  final Set<String> _downloadingIds = {};

  Widget _buildModelCard(HFModel model, int index) {
    final isDownloaded = model.downloaded;
    final isDownloading = model.downloadStatus == 'downloading';
    final isInProgress = isDownloading;
    final bool canStartDownload = !isDownloaded && !isInProgress && !_downloadingIds.contains(model.id);
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    
    return StaggeredEntrance(
      index: index,
      child: AnimatedTapCard(
        onTap: () {
          if (canStartDownload) {
            _downloadingIds.add(model.id);
            final url = ModelService.getDownloadUrl(model.id);
            ref.read(downloadProvider.notifier).startDownloadWithUrl(model, url);
          }
        },
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: flux.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: flux.border,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.name,
                        style: textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${AppLocalizations.of(context)!.poweredBy} ${model.baseModel ?? model.name} (${_formatSize(model.sizeMB)})',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (isDownloaded)
                  AnimatedTapCard(
                    onTap: () => _confirmDelete(model),
                    scaleDown: 0.85,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: flux.border,
                          width: 1,
                        ),
                        color: flux.surface,
                      ),
                      child: Center(
                        child: Icon(Icons.delete_outline, size: 16, color: flux.textPrimary),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: flux.border,
                        width: 1,
                      ),
                      color: flux.surface,
                    ),
                    child: Center(
                      child: isInProgress
                          ? Icon(Icons.hourglass_empty, size: 16, color: flux.textPrimary)
                          : Icon(Icons.add, size: 16, color: flux.textPrimary),
                    ),
                  ),
              ],
            ),
            if (isDownloading) ...[
              const SizedBox(height: 12),
              RepaintBoundary(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: model.progress / 100,
                    backgroundColor: flux.border,
                    valueColor: AlwaysStoppedAnimation(flux.textPrimary),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${model.progress}% ${model.downloadSpeed != null && model.downloadSpeed! > 0 ? '\u2022 ${model.downloadSpeed!.toStringAsFixed(1)} MB/s' : ''} \u2022 ${_formatDownloadedSize(model)}',
                      style: textTheme.bodySmall?.copyWith(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AnimatedTapCard(
                    onTap: () => _confirmCancel(model),
                    scaleDown: 0.85,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: flux.border,
                          width: 1,
                        ),
                        color: flux.surface,
                      ),
                      child: Center(
                        child: Icon(Icons.close, size: 16, color: flux.textPrimary),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
    );
  }

  void _confirmDelete(HFModel model) {
    _showAnimatedDialog(
      title: AppLocalizations.of(context)!.deleteModelQuestion,
      content: AppLocalizations.of(context)!.deleteModelQuestion.replaceAll('{model}', model.name),
      cancelText: AppLocalizations.of(context)!.cancel,
      actionText: AppLocalizations.of(context)!.delete,
      actionColor: Colors.red,
      onAction: () => ref.read(downloadProvider.notifier).deleteModel(model.id),
    );
  }

  void _confirmCancel(HFModel model) {
    _showAnimatedDialog(
      title: AppLocalizations.of(context)!.cancelDownloadQuestion,
      content: AppLocalizations.of(context)!.cancelDownloadQuestion.replaceAll('{model}', model.name),
      cancelText: AppLocalizations.of(context)!.continueDownload,
      actionText: AppLocalizations.of(context)!.cancelDownload,
      actionColor: Colors.red,
      onAction: () {
        ref.read(downloadProvider.notifier).cancelDownload(model.id);
        _downloadingIds.remove(model.id);
      },
    );
  }

  void _showAnimatedDialog({
    required String title,
    required String content,
    required String cancelText,
    required String actionText,
    required Color actionColor,
    required VoidCallback onAction,
  }) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    
    showGeneralDialog(
      context: context,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Container();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curve = Curves.easeInOutCubic;
        final tween = Tween<double>(begin: 0.0, end: 1.0);
        final fadeAnimation = tween.animate(CurvedAnimation(
          parent: animation,
          curve: curve,
        ));
        final scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(CurvedAnimation(
          parent: animation,
          curve: curve,
        ));

        return Opacity(
          opacity: fadeAnimation.value,
          child: Transform.scale(
            scale: scaleAnimation.value,
            child: AlertDialog(
              backgroundColor: flux.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Text(
                title,
                style: textTheme.headlineMedium,
              ),
              content: Text(
                content,
                style: textTheme.bodySmall,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    cancelText,
                    style: textTheme.bodyMedium?.copyWith(color: flux.textSecondary),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    onAction();
                    Navigator.pop(context);
                  },
                  child: Text(
                    actionText,
                    style: textTheme.bodyMedium?.copyWith(color: actionColor),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 250),
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: flux.textPrimary.withValues(alpha: 0.3),
    );
  }
}

