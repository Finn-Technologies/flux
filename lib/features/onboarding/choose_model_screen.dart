import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/model_service.dart';
import '../../core/models/hf_model.dart';
import '../../core/providers/download_provider.dart';
import '../../core/providers/model_provider.dart';
import '../../core/widgets/flux_animations.dart';
import '../../l10n/app_localizations.dart';

class ChooseModelScreen extends ConsumerStatefulWidget {
  const ChooseModelScreen({super.key});

  @override
  ConsumerState<ChooseModelScreen> createState() => _ChooseModelScreenState();
}

class _ChooseModelScreenState extends ConsumerState<ChooseModelScreen> {
  List<HFModel> _models = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  HFModel? _selectedModel;
  int _deviceRAM = 0;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    setState(() => _isLoading = true);
    final ram = await ModelService.getDeviceRAM();
    final models = await ModelService.getRecommendedModels();
    if (mounted) {
      setState(() {
        _deviceRAM = ram;
        _models = models;
        _isLoading = false;
        if (models.isNotEmpty) _selectedModel = models.first;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/onboarding'),
        ),
        title: Text(
          AppLocalizations.of(context)!.modelPicker,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.memory, size: 16, color: colorScheme.secondary),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.detectedRam(_deviceRAM),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context)!.selectOptimizedModel,
                  style: TextStyle(fontSize: 15, color: colorScheme.secondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildModelList(colorScheme),
          ),
          _buildFooter(colorScheme),
        ],
      ),
    );
  }

  Widget _buildModelList(ColorScheme colorScheme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _models.length,
      cacheExtent: 150,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      itemBuilder: (context, index) {
        final model = _models[index];
        final isSelected = _selectedModel?.id == model.id;

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 400 + (index * 100)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, 20 * (1.0 - value)),
                child: child,
              ),
            );
          },
          child: BouncyTap(
            onTap: () => setState(() => _selectedModel = model),
            scaleDown: 0.95,
            child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: const Cubic(0.34, 1.56, 0.64, 1),
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primary.withValues(alpha: 0.05)
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected ? colorScheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected ? colorScheme.primary : colorScheme.outlineVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.smart_toy_rounded,
                    color: isSelected ? colorScheme.onPrimary : colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(model.sizeMB / 1024).toStringAsFixed(1)} GB • Optimized',
                        style: TextStyle(fontSize: 13, color: colorScheme.secondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: colorScheme.primary, size: 28),
              ],
            ),
          ),
        ),
      );
      },
    );
  }

  Widget _buildFooter(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: (_selectedModel == null || _isSubmitting) ? null : _onContinue,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      AppLocalizations.of(context)!.downloadAndContinue,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.highSpeedConnectionRecommended,
            style: TextStyle(fontSize: 12, color: colorScheme.secondary),
          ),
        ],
      ),
    );
  }

  Future<void> _onContinue() async {
    if (_selectedModel == null || _isSubmitting) return;
    
    setState(() => _isSubmitting = true);
    
    // Start download using the static service for URL
    final url = ModelService.getDownloadUrl(_selectedModel!.id);
    ref.read(downloadProvider.notifier).startDownloadWithUrl(_selectedModel!, url);
    ref.read(selectedModelIdProvider.notifier).select(_selectedModel!.id);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarded', true);
    
    if (mounted) context.go('/home');
  }
}
