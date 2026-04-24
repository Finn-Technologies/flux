import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/model_service.dart';
import '../../core/models/hf_model.dart';
import '../../core/providers/download_provider.dart';
import '../../core/providers/model_provider.dart';
import '../../core/theme/flux_theme.dart';
import '../../core/widgets/animated_tap_card.dart';
import '../../l10n/app_localizations.dart';
// ============================================================================
// TYPOGRAPHY - Instrument Sans from Google Fonts
// ============================================================================
class _AppTypography {
  static TextStyle heading(BuildContext context) => GoogleFonts.instrumentSans(
        fontSize: 25,
        fontWeight: FontWeight.w400,
        color: Theme.of(context).extension<FluxColorsExtension>()!.textPrimary,
        height: 1.22,
        letterSpacing: 0,
      );

  static TextStyle description(BuildContext context) => GoogleFonts.instrumentSans(
        fontSize: 20,
        fontWeight: FontWeight.w400,
        color: Theme.of(context).extension<FluxColorsExtension>()!.textSecondary,
        height: 1.22,
        letterSpacing: 0,
      );

  static TextStyle button(BuildContext context) => GoogleFonts.instrumentSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: Theme.of(context).extension<FluxColorsExtension>()!.background,
        height: 1.22,
        letterSpacing: 0,
      );

  static TextStyle backButton(BuildContext context) => GoogleFonts.instrumentSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: Theme.of(context).extension<FluxColorsExtension>()!.textSecondary,
        height: 1.22,
        letterSpacing: 0,
      );

  static TextStyle modelTitle(BuildContext context) => GoogleFonts.instrumentSans(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: Theme.of(context).extension<FluxColorsExtension>()!.textPrimary,
        letterSpacing: 0,
      );

  static TextStyle modelSubtitle(BuildContext context) => GoogleFonts.instrumentSans(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: Theme.of(context).extension<FluxColorsExtension>()!.textSecondary,
        letterSpacing: 0,
      );
}

// ============================================================================
// ASSETS
// ============================================================================
class _AppAssets {
  static const String backArrow = 'assets/images/back_arrow.svg';
}

// ============================================================================
// ANIMATION CONSTANTS
// ============================================================================
class _AnimDurations {
  static const Duration fast = Duration(milliseconds: 350);
}

class _AnimCurves {
  static const Curve smooth = Curves.easeInOutCubic;
}

// ============================================================================
// MAIN SCREEN
// ============================================================================
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;
  bool _isNavigating = false;
  bool _isDownloading = false;

  List<HFModel> _models = [];
  bool _isLoadingModels = true;
  HFModel? _selectedModel;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    final models = await ModelService.getRecommendedModels();
    if (mounted) {
      setState(() {
        _models = models;
        _isLoadingModels = false;
        if (models.isNotEmpty) _selectedModel = models.first;
      });
    }
  }

  void _onNext() async {
    if (_isNavigating || _page >= 4) return;
    
    setState(() => _isNavigating = true);
    
    await _controller.nextPage(
      duration: _AnimDurations.fast,
      curve: _AnimCurves.smooth,
    );
    
    setState(() => _isNavigating = false);
  }

  void _onBack() async {
    if (_isNavigating || _page <= 0) return;
    
    setState(() => _isNavigating = true);
    
    await _controller.previousPage(
      duration: _AnimDurations.fast,
      curve: _AnimCurves.smooth,
    );
    
    setState(() => _isNavigating = false);
  }

  Future<void> _onSkip() async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarded', true);

    if (mounted) context.go('/home');
  }

  Future<void> _onFinish() async {
    if (_isDownloading) return;
    
    setState(() => _isDownloading = true);
    
    if (_selectedModel != null) {
      final url = ModelService.getDownloadUrl(_selectedModel!.id);
      ref.read(downloadProvider.notifier).startDownloadWithUrl(_selectedModel!, url);
      ref.read(selectedModelIdProvider.notifier).select(_selectedModel!.id);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarded', true);

    if (mounted) context.go('/home');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final brightness = Theme.of(context).brightness;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: brightness == Brightness.dark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: flux.background,
        body: SafeArea(
          child: PageView(
            controller: _controller,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              _WelcomeSlide(onNext: _onNext, onSkip: _onSkip),
              _PrivacySlide(onNext: _onNext, onBack: _onBack),
              _OfflineSlide(onNext: _onNext, onBack: _onBack),
              _DownloadModelSlide(
                models: _models,
                isLoading: _isLoadingModels,
                selectedModel: _selectedModel,
                onSelect: (model) => setState(() => _selectedModel = model),
                onNext: _onNext,
                onBack: _onBack,
              ),
              _FinishSlide(onFinish: _onFinish),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SLIDES
// ============================================================================

class _WelcomeSlide extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _WelcomeSlide({required this.onNext, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        final spacing = 60.0;
        final contentHeight = 31.0 + spacing + 44;
        final topPadding = ((screenHeight - contentHeight) / 2) + 60;
        final flux = Theme.of(context).extension<FluxColorsExtension>()!;

        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: topPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FadeInSlide(
                    delay: const Duration(milliseconds: 100),
                    child: Text(
                      AppLocalizations.of(context)!.welcomeToFlux,
                      style: _AppTypography.heading(context),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                  
                  _FadeInSlide(
                    delay: const Duration(milliseconds: 200),
                    child: _AnimatedButton(
                      text: AppLocalizations.of(context)!.start,
                      onPressed: onNext,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _FadeInSlide(
                    delay: const Duration(milliseconds: 250),
                    child: AnimatedTapCard(
                      onTap: onSkip,
                      scaleDown: 0.95,
                      child: Text(
                        AppLocalizations.of(context)!.skipSetup,
                        style: _AppTypography.backButton(context).copyWith(
                          color: flux.textSecondary.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PrivacySlide extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _PrivacySlide({required this.onNext, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        final spacing = 60.0;
        final contentHeight = 31.0 + 20 + 76 + spacing + 44;
        final topPadding = ((screenHeight - contentHeight) / 2) + 60;

        return Stack(
          children: [
            Positioned(
              left: 20,
              top: 74,
              child: _FadeInSlide(
                delay: Duration.zero,
                child: _BackButton(onPressed: onBack),
              ),
            ),

            Positioned(
              left: 20,
              right: 20,
              top: topPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FadeInSlide(
                    delay: const Duration(milliseconds: 100),
                    child: Text(
                      'We value your privacy',
                      style: _AppTypography.heading(context),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  _FadeInSlide(
                    delay: const Duration(milliseconds: 150),
                    child: Text(
                      "We designed Flux to use Local AI models, so your data doesn't go to corporations, not even us.",
                      style: _AppTypography.description(context),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  SizedBox(height: spacing),
                  
                  _FadeInSlide(
                    delay: const Duration(milliseconds: 200),
                    child: _AnimatedButton(
                      text: 'Next',
                      onPressed: onNext,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OfflineSlide extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _OfflineSlide({required this.onNext, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        final spacing = 60.0;
        final contentHeight = 31.0 + 20 + 76 + spacing + 44;
        final topPadding = ((screenHeight - contentHeight) / 2) + 60;

        return Stack(
          children: [
            Positioned(
              left: 20,
              top: 74,
              child: _FadeInSlide(
                delay: Duration.zero,
                child: _BackButton(onPressed: onBack),
              ),
            ),

            Positioned(
              left: 20,
              right: 20,
              top: topPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FadeInSlide(
                    delay: const Duration(milliseconds: 100),
                    child: Text(
                      'Fully offline',
                      style: _AppTypography.heading(context),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  _FadeInSlide(
                    delay: const Duration(milliseconds: 150),
                    child: Text(
                      'Since we use Local AI models, Flux works entirely offline, so you can ask questions even with no coverage.',
                      style: _AppTypography.description(context),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  SizedBox(height: spacing),
                  
                  _FadeInSlide(
                    delay: const Duration(milliseconds: 200),
                    child: _AnimatedButton(
                      text: 'Next',
                      onPressed: onNext,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DownloadModelSlide extends StatelessWidget {
  final List<HFModel> models;
  final bool isLoading;
  final HFModel? selectedModel;
  final Function(HFModel) onSelect;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _DownloadModelSlide({
    required this.models,
    required this.isLoading,
    required this.selectedModel,
    required this.onSelect,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return Stack(
      children: [
        Positioned(
          left: 20,
          top: 74,
          child: _FadeInSlide(
            delay: Duration.zero,
            child: _BackButton(onPressed: onBack),
          ),
        ),

        Positioned(
          left: 20,
          top: 122,
          right: 20,
          child: _FadeInSlide(
            delay: const Duration(milliseconds: 100),
            child: Text(
              'Choose a model to download',
              style: _AppTypography.heading(context),
            ),
          ),
        ),

        Positioned(
          left: 20,
          top: 173,
          right: 20,
          child: _FadeInSlide(
            delay: const Duration(milliseconds: 150),
            child: Text(
              'Flux recommends models optimized for your device, ensuring they work properly.',
              style: _AppTypography.description(context),
            ),
          ),
        ),

        Positioned(
          left: 20,
          top: 265,
          right: 20,
          bottom: 100,
          child: isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: flux.textPrimary,
                    strokeWidth: 2,
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: models.length,
                  cacheExtent: 150,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  itemBuilder: (context, index) {
                    final model = models[index];
                    final isSelected = selectedModel?.id == model.id;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AnimatedTapCard(
                        onTap: () => onSelect(model),
                        scaleDown: 0.95,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                          decoration: BoxDecoration(
                            color: flux.surface,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: isSelected ? flux.textPrimary : flux.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      model.name,
                                      style: _AppTypography.modelTitle(context),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Powered by ${model.baseModel ?? model.name} (${model.sizeMB >= 1024 ? '${(model.sizeMB / 1024).toStringAsFixed(1)} GB' : '${model.sizeMB} MB'})',
                                      style: _AppTypography.modelSubtitle(context),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? flux.textPrimary : flux.border,
                                    width: 1,
                                  ),
                                  color: isSelected ? flux.textPrimary : flux.surface,
                                ),
                                child: Center(
                                  child: isSelected
                                      ? Icon(Icons.check, size: 16, color: flux.background)
                                      : Icon(Icons.add, size: 16, color: flux.textPrimary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),

        Positioned(
          right: 20,
          bottom: 40,
          child: _FadeInSlide(
            delay: const Duration(milliseconds: 200),
            child: _AnimatedButton(
              text: 'Next',
              onPressed: selectedModel != null ? onNext : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _FinishSlide extends StatelessWidget {
  final VoidCallback onFinish;

  const _FinishSlide({required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        final spacing = 60.0;
        final contentHeight = 31.0 + spacing + 44;
        final topPadding = ((screenHeight - contentHeight) / 2) + 60;

        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: topPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FadeInSlide(
                    delay: const Duration(milliseconds: 100),
                    child: Text(
                      "That's it. Flux is ready!",
                      style: _AppTypography.heading(context),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                  
                  _FadeInSlide(
                    delay: const Duration(milliseconds: 200),
                    child: _AnimatedButton(
                      text: 'Finish',
                      onPressed: onFinish,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// COMPONENTS
// ============================================================================

class _FadeInSlide extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _FadeInSlide({required this.child, required this.delay});

  @override
  State<_FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<_FadeInSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _slide;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeInOutCubic),
      ),
    );

    _slide = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeInOutCubic),
      ),
    );

    _startTimer = Timer(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(0, _slide.value),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _AnimatedButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const _AnimatedButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return AnimatedTapCard(
      onTap: onPressed,
      scaleDown: 0.95,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: onPressed != null
              ? flux.textPrimary
              : flux.textPrimary.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          text,
          style: _AppTypography.button(context),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _BackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return AnimatedTapCard(
      onTap: onPressed,
      scaleDown: 0.9,
      child: Container(
        padding: const EdgeInsets.only(right: 12, top: 12, bottom: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(
              _AppAssets.backArrow,
              width: 10,
              height: 18,
              colorFilter: ColorFilter.mode(flux.textSecondary, BlendMode.srcIn),
            ),
            const SizedBox(width: 13),
            Text(
              'Back',
              style: _AppTypography.backButton(context),
            ),
          ],
        ),
      ),
    );
  }
}
