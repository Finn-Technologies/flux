import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/services/model_service.dart';
import '../../core/models/hf_model.dart';
import '../../core/providers/download_provider.dart';

// ============================================================================
// COLORS - Exact from Figma
// ============================================================================
class _Colors {
  static const Color background = Color(0xFFF9F9F9);
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color textSecondary = Color.fromRGBO(0, 0, 0, 0.5);
  static const Color border = Color.fromRGBO(0, 0, 0, 0.1);
}

// ============================================================================
// TYPOGRAPHY - Instrument Sans
// ============================================================================
class _TextStyles {
  static TextStyle get title => GoogleFonts.instrumentSans(
        fontSize: 25,
        fontWeight: FontWeight.w400,
        color: _Colors.black,
        height: 1.22,
      );

  static TextStyle get body => GoogleFonts.instrumentSans(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: _Colors.black,
      );

  static TextStyle get subtitle => GoogleFonts.instrumentSans(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: _Colors.textSecondary,
      );

  static TextStyle get modelTitle => GoogleFonts.instrumentSans(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: _Colors.black,
      );

  static TextStyle get modelSubtitle => GoogleFonts.instrumentSans(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: _Colors.textSecondary,
      );
}

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

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: _Colors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Back button - moved up (y: 60)
            Positioned(
              left: 20,
              top: 60,
              child: GestureDetector(
                onTap: () => context.go('/settings'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/images/back_arrow.svg',
                      width: 10,
                      height: 18,
                    ),
                    const SizedBox(width: 13),
                    Text(
                      'Back',
                      style: GoogleFonts.instrumentSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: _Colors.textSecondary,
                        height: 1.22,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Header - moved up (y: 100)
            Positioned(
              left: 20,
              top: 100,
              child: Text(
                'Models',
                style: _TextStyles.title,
              ),
            ),

            // Content - moved up accordingly (y: 160)
            Positioned(
              left: 20,
              right: 20,
              top: 160,
              bottom: 20,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Storage card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: _Colors.border,
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
                              style: _TextStyles.subtitle,
                            ),
                            Text(
                              '${_usedStorageGB.toStringAsFixed(1)} GB / ${_totalStorageGB.toStringAsFixed(0)} GB',
                              style: _TextStyles.subtitle,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: usedFraction,
                            backgroundColor: _Colors.border,
                            valueColor: const AlwaysStoppedAnimation(_Colors.black),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Active Downloads
                  if (downloadingModels.isNotEmpty) ...[
                    Text(
                      'Downloading',
                      style: _TextStyles.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    ...downloadingModels.map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildModelCard(m),
                    )),
                    const SizedBox(height: 24),
                  ],

                  // Installed Models
                  if (installedModels.isNotEmpty) ...[
                    Text(
                      'Installed',
                      style: _TextStyles.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    ...installedModels.map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildModelCard(m),
                    )),
                    const SizedBox(height: 24),
                  ],

                  // Available Models (not yet downloaded)
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(color: _Colors.black),
                    )
                  else ...[
                    // Filter out models that are already installed or downloading
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
                            style: _TextStyles.body.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          ...trulyAvailable.map((m) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildModelCard(m),
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
                              color: _Colors.border,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Icon(
                              Icons.download_outlined,
                              size: 36,
                              color: _Colors.black,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No models yet',
                            style: _TextStyles.body.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Download a model to get started',
                            style: _TextStyles.subtitle,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Format size to show MB or GB appropriately
  String _formatSize(int sizeMB) {
    if (sizeMB >= 1024) {
      return '${(sizeMB / 1024).toStringAsFixed(1)} GB';
    } else {
      return '$sizeMB MB';
    }
  }

  // Format downloaded size progress (e.g., "150 MB / 500 MB" or "0.5 GB / 2.5 GB")
  String _formatDownloadedSize(HFModel model) {
    final totalMB = model.sizeMB;
    final downloadedMB = (totalMB * model.progress / 100).round();
    
    if (totalMB >= 1024) {
      // Show in GB if total is >= 1GB
      final downloadedGB = (downloadedMB / 1024).toStringAsFixed(1);
      final totalGB = (totalMB / 1024).toStringAsFixed(1);
      return '$downloadedGB GB / $totalGB GB';
    } else {
      // Show in MB
      return '$downloadedMB MB / $totalMB MB';
    }
  }

  // Track which models are currently being downloaded to prevent double-taps
  final Set<String> _downloadingIds = {};

  // Model card - same style as onboarding page
  // In settings/models page, we only download/delete - NO SELECTION here
  Widget _buildModelCard(HFModel model) {
    final isDownloaded = model.downloaded;
    final isDownloading = model.downloadStatus == 'downloading';
    final isInProgress = isDownloading;
    
    // Only start download if not already in progress (downloading or paused)
    final bool canStartDownload = !isDownloaded && !isInProgress && !_downloadingIds.contains(model.id);
    
    return GestureDetector(
      onTap: () {
        if (canStartDownload) {
          // Start new download
          _downloadingIds.add(model.id);
          final url = ModelService.getDownloadUrl(model.id);
          ref.read(downloadProvider.notifier).startDownloadWithUrl(model, url);
        }
        // Note: Resuming paused downloads is done via the resume button, not by tapping the card
        // Note: No selection on tap in settings - selection happens on home/chat screen only
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: _Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: _Colors.border,
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
                        style: _TextStyles.modelTitle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Powered by ${model.baseModel ?? model.name} (${_formatSize(model.sizeMB)})',
                        style: _TextStyles.modelSubtitle,
                      ),
                    ],
                  ),
                ),
                // Delete button for downloaded models, or status indicator
                if (isDownloaded)
                  GestureDetector(
                    onTap: () => _confirmDelete(model),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _Colors.border,
                          width: 1,
                        ),
                        color: _Colors.white,
                      ),
                      child: const Center(
                        child: Icon(Icons.delete_outline, size: 16, color: _Colors.black),
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
                        color: _Colors.border,
                        width: 1,
                      ),
                      color: _Colors.white,
                    ),
                    child: Center(
                      child: isInProgress
                          ? const Icon(Icons.hourglass_empty, size: 16, color: _Colors.black)
                          : const Icon(Icons.add, size: 16, color: _Colors.black),
                    ),
                  ),
              ],
            ),
            // Download progress indicator with cancel button only
            if (isDownloading) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: model.progress / 100,
                  backgroundColor: _Colors.border,
                  valueColor: const AlwaysStoppedAnimation(_Colors.black),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Progress text with speed and size info
                  Expanded(
                    child: Text(
                      '${model.progress}% ${model.downloadSpeed != null && model.downloadSpeed! > 0 ? '• ${model.downloadSpeed!.toStringAsFixed(1)} MB/s' : ''} • ${_formatDownloadedSize(model)}',
                      style: _TextStyles.subtitle.copyWith(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Cancel button only
                  GestureDetector(
                    onTap: () => _confirmCancel(model),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _Colors.border,
                          width: 1,
                        ),
                        color: _Colors.white,
                      ),
                      child: const Center(
                        child: Icon(Icons.close, size: 16, color: _Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDelete(HFModel model) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          'Delete Model?',
          style: _TextStyles.body.copyWith(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete ${model.name}? You will need to download it again to use it.',
          style: _TextStyles.subtitle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: _TextStyles.body.copyWith(color: _Colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(downloadProvider.notifier).deleteModel(model.id);
              Navigator.pop(ctx);
            },
            child: Text(
              'Delete',
              style: _TextStyles.body.copyWith(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmCancel(HFModel model) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          'Cancel Download?',
          style: _TextStyles.body.copyWith(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to cancel the download of ${model.name}? Downloaded progress will be lost.',
          style: _TextStyles.subtitle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Continue',
              style: _TextStyles.body.copyWith(color: _Colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(downloadProvider.notifier).cancelDownload(model.id);
              _downloadingIds.remove(model.id);
              Navigator.pop(ctx);
            },
            child: Text(
              'Cancel Download',
              style: _TextStyles.body.copyWith(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
