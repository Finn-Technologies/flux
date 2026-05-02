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
import '../../core/widgets/flux_animations.dart';
import '../../l10n/app_localizations.dart';

// ============================================================================
// TYPOGRAPHY
// ============================================================================
class _AppTypography {
  static TextStyle heading(BuildContext context) => GoogleFonts.instrumentSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).extension<FluxColorsExtension>()!.textPrimary,
        height: 1.2,
        letterSpacing: -0.5,
      );

  static TextStyle description(BuildContext context) => GoogleFonts.instrumentSans(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        color: Theme.of(context).extension<FluxColorsExtension>()!.textSecondary,
        height: 1.4,
        letterSpacing: -0.2,
      );

  static TextStyle button(BuildContext context) => GoogleFonts.instrumentSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).extension<FluxColorsExtension>()!.background,
        height: 1.25,
      );

  static TextStyle modelTitle(BuildContext context) => GoogleFonts.instrumentSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).extension<FluxColorsExtension>()!.textPrimary,
      );

  static TextStyle modelSubtitle(BuildContext context) => GoogleFonts.instrumentSans(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: Theme.of(context).extension<FluxColorsExtension>()!.textSecondary,
      );
}

// ============================================================================
// ASSETS
// ============================================================================
class _AppAssets {
  static const String backArrow = 'assets/images/back_arrow.svg';
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
  int _page = 0;
  bool _isNavigating = false;
  bool _isDownloading = false;
  bool _isForward = true;

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
    
    setState(() {
      _isNavigating = true;
      _isForward = true;
      _page++;
    });
    
    await Future.delayed(const Duration(milliseconds: 450));
    if (mounted) setState(() => _isNavigating = false);
  }

  void _onBack() async {
    if (_isNavigating || _page <= 0) return;
    
    setState(() {
      _isNavigating = true;
      _isForward = false;
      _page--;
    });
    
    await Future.delayed(const Duration(milliseconds: 450));
    if (mounted) setState(() => _isNavigating = false);
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
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final brightness = Theme.of(context).brightness;

    Widget currentSlide;
    switch (_page) {
      case 0:
        currentSlide = _WelcomeSlide(key: const ValueKey(0), onNext: _onNext);
        break;
      case 1:
        currentSlide = _PrivacySlide(key: const ValueKey(1), onNext: _onNext, onBack: _onBack);
        break;
      case 2:
        currentSlide = _OfflineSlide(key: const ValueKey(2), onNext: _onNext, onBack: _onBack);
        break;
      case 3:
        currentSlide = _DownloadModelSlide(
          key: const ValueKey(3),
          models: _models,
          isLoading: _isLoadingModels,
          selectedModel: _selectedModel,
          onSelect: (model) => setState(() => _selectedModel = model),
          onNext: _onNext,
          onBack: _onBack,
        );
        break;
      case 4:
      default:
        currentSlide = _FinishSlide(key: const ValueKey(4), onFinish: _onFinish);
        break;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: brightness == Brightness.dark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: flux.background,
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            reverseDuration: const Duration(milliseconds: 450),
            switchInCurve: Curves.linear,
            switchOutCurve: Curves.linear,
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                children: <Widget>[
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              );
            },
            transitionBuilder: (child, animation) {
              return FluxPageTransition(
                primaryAnimation: animation,
                isForwardLayout: _isForward,
                child: child,
              );
            },
            child: currentSlide,
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

  const _WelcomeSlide({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        final topPadding = ((screenHeight - 180) / 2) + 20;

        return Stack(
          children: [
            Positioned(
              left: 20,
              right: 20,
              top: topPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BouncyFadeSlide(
                    delay: const Duration(milliseconds: 100),
                    duration: const Duration(milliseconds: 600),
                    slideOffset: 30,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Theme.of(context).extension<FluxColorsExtension>()!.textPrimary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        size: 36,
                        color: Theme.of(context).extension<FluxColorsExtension>()!.textPrimary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  BouncyFadeSlide(
                    delay: const Duration(milliseconds: 200),
                    duration: const Duration(milliseconds: 600),
                    slideOffset: 20,
                    child: Text(
                      AppLocalizations.of(context)!.welcomeToFlux,
                      style: _AppTypography.heading(context),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 60),

                  BouncyFadeSlide(
                    delay: const Duration(milliseconds: 400),
                    duration: const Duration(milliseconds: 600),
                    slideOffset: 20,
                    child: _AnimatedButton(
                      text: AppLocalizations.of(context)!.start,
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

class _PrivacySlide extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _PrivacySlide({super.key, required this.onNext, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        final topPadding = ((screenHeight - 220) / 2) + 20;

        return Stack(
          children: [
            Positioned(
              left: 20,
              top: 60,
              child: BouncyFadeSlide(
                delay: Duration.zero,
                duration: const Duration(milliseconds: 400),
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
                  BouncyFadeSlide(
                    delay: const Duration(milliseconds: 100),
                    duration: const Duration(milliseconds: 500),
                    slideOffset: 24,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Theme.of(context).extension<FluxColorsExtension>()!.textPrimary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.lock_outline,
                        size: 28,
                        color: Theme.of(context).extension<FluxColorsExtension>()!.textPrimary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  BouncyFadeSlide(
                    delay: const Duration(milliseconds: 150),
                    duration: const Duration(milliseconds: 500),
                    slideOffset: 20,
                    child: Text(
                      AppLocalizations.of(context)!.weValuePrivacy,
                      style: _AppTypography.heading(context),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 16),

                  BouncyFadeSlide(
                    delay: const Duration(milliseconds: 250),
                    duration: const Duration(milliseconds: 500),
                    slideOffset: 16,
                    child: Text(
                      AppLocalizations.of(context)!.privacyDescription,
                      style: _AppTypography.description(context),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 48),

                  BouncyFadeSlide(
                    delay: const Duration(milliseconds: 350),
                    duration: const Duration(milliseconds: 500),
                    slideOffset: 16,
                    child: _AnimatedButton(
                      text: AppLocalizations.of(context)!.next,
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

  const _OfflineSlide({super.key, required this.onNext, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        final topPadding = ((screenHeight - 220) / 2) + 20;

        return Stack(
          children: [
            Positioned(
              left: 20,
              top: 60,
              child: BouncyFadeSlide(
                delay: Duration.zero,
                duration: const Duration(milliseconds: 400),
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
                  BouncyFadeSlide(
                    delay: const Duration(milliseconds: 100),
                    duration: const Duration(milliseconds: 500),
                    slideOffset: 24,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Theme.of(context).extension<FluxColorsExtension>()!.textPrimary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.cloud_off_outlined,
                        size: 28,
                        color: Theme.of(context).extension<FluxColorsExtension>()!.textPrimary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  BouncyFadeSlide(
                    delay: const Duration(milliseconds: 150),
                    duration: const Duration(milliseconds: 500),
                    slideOffset: 20,
                    child: Text(
                      AppLocalizations.of(context)!.fullyOffline,
                      style: _AppTypography.heading(context),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 16),

                  BouncyFadeSlide(
                    delay: const Duration(milliseconds: 250),
                    duration: const Duration(milliseconds: 500),
                    slideOffset: 16,
                    child: Text(
                      AppLocalizations.of(context)!.offlineDescription,
                      style: _AppTypography.description(context),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 48),

                  BouncyFadeSlide(
                    delay: const Duration(milliseconds: 350),
                    duration: const Duration(milliseconds: 500),
                    slideOffset: 16,
                    child: _AnimatedButton(
                      text: AppLocalizations.of(context)!.next,
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
    super.key,
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
          top: 60,
          child: BouncyFadeSlide(
            delay: Duration.zero,
            duration: const Duration(milliseconds: 400),
            child: _BackButton(onPressed: onBack),
          ),
        ),

        Positioned(
          left: 20,
          top: 110,
          right: 20,
          child: BouncyFadeSlide(
            delay: const Duration(milliseconds: 100),
            duration: const Duration(milliseconds: 500),
            slideOffset: 20,
            child: Text(
              AppLocalizations.of(context)!.chooseModel,
              style: _AppTypography.heading(context),
            ),
          ),
        ),

        Positioned(
          left: 20,
          top: 158,
          right: 20,
          child: BouncyFadeSlide(
            delay: const Duration(milliseconds: 200),
            duration: const Duration(milliseconds: 500),
            slideOffset: 16,
            child: Text(
              AppLocalizations.of(context)!.chooseModelDescription,
              style: _AppTypography.description(context),
            ),
          ),
        ),

        Positioned(
          left: 20,
          top: 240,
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
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final model = models[index];
                    final isSelected = selectedModel?.id == model.id;

                    return BouncyFadeSlide(
                      delay: Duration(milliseconds: 100 + index * 60),
                      duration: const Duration(milliseconds: 400),
                      slideOffset: 16,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: BouncyTap(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            onSelect(model);
                          },
                          scaleDown: 0.97,
                          child: AnimatedContainer(
                            duration: FluxDurations.fast,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: flux.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? flux.textPrimary : flux.border,
                                width: isSelected ? 1.5 : 1,
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
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? flux.textPrimary : flux.border,
                                      width: 1.5,
                                    ),
                                    color: isSelected ? flux.textPrimary : flux.surface,
                                  ),
                                  child: Center(
                                    child: isSelected
                                        ? Icon(Icons.check, size: 14, color: flux.background)
                                        : Icon(Icons.add, size: 14, color: flux.textSecondary),
                                  ),
                                ),
                              ],
                            ),
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
          child: BouncyFadeSlide(
            delay: const Duration(milliseconds: 300),
            duration: const Duration(milliseconds: 500),
            slideOffset: 16,
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

  const _FinishSlide({super.key, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        final topPadding = ((screenHeight - 180) / 2) + 20;

        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: topPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BouncyFadeSlide(
                    delay: const Duration(milliseconds: 100),
                    duration: const Duration(milliseconds: 600),
                    slideOffset: 24,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Theme.of(context).extension<FluxColorsExtension>()!.textPrimary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.check,
                        size: 28,
                        color: Theme.of(context).extension<FluxColorsExtension>()!.textPrimary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  BouncyFadeSlide(
                    delay: const Duration(milliseconds: 200),
                    duration: const Duration(milliseconds: 600),
                    slideOffset: 20,
                    child: Text(
                      AppLocalizations.of(context)!.thatsIt,
                      style: _AppTypography.heading(context),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 48),

                  BouncyFadeSlide(
                    delay: const Duration(milliseconds: 400),
                    duration: const Duration(milliseconds: 600),
                    slideOffset: 16,
                    child: _AnimatedButton(
                      text: AppLocalizations.of(context)!.finish,
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

class _AnimatedButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const _AnimatedButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return BouncyTap(
      onTap: onPressed,
      scaleDown: 0.95,
      child: AnimatedContainer(
        duration: FluxDurations.fast,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: onPressed != null
              ? flux.textPrimary
              : flux.textPrimary.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
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
    return BouncyTap(
      onTap: onPressed,
      scaleDown: 0.9,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: flux.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: flux.border.withValues(alpha: 0.5)),
        ),
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
            const SizedBox(width: 10),
            Text(
              AppLocalizations.of(context)!.back,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: flux.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
