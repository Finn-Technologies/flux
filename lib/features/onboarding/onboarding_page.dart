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
// PALETTE
// ============================================================================
/// Accent used for the onboarding feature glyphs (lock, sparkles, shield).
const Color _kOnboardingBlue = Color(0xFF2E6BFF);

// ============================================================================
// TYPOGRAPHY
// ============================================================================
class _AppTypography {
  static TextStyle heading(BuildContext context) => GoogleFonts.instrumentSans(
        fontSize: 25,
        fontWeight: FontWeight.w400,
        color: Theme.of(context).extension<FluxColorsExtension>()!.textPrimary,
        height: 1.22,
        letterSpacing: 0,
      );

  /// Bold title used at the top of content slides.
  static TextStyle slideTitle(BuildContext context) =>
      GoogleFonts.instrumentSans(
        fontSize: 24,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).extension<FluxColorsExtension>()!.textPrimary,
        height: 1.25,
        letterSpacing: 0,
      );

  /// Body copy for content slides.
  static TextStyle bodyText(BuildContext context) =>
      GoogleFonts.instrumentSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: Theme.of(
          context,
        ).extension<FluxColorsExtension>()!.textSecondary,
        height: 1.5,
        letterSpacing: 0,
      );

  static TextStyle button(BuildContext context) => GoogleFonts.instrumentSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: Theme.of(context).extension<FluxColorsExtension>()!.background,
        height: 1.22,
        letterSpacing: 0,
      );

  static TextStyle backButton(BuildContext context) =>
      GoogleFonts.instrumentSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: Theme.of(
          context,
        ).extension<FluxColorsExtension>()!.textSecondary,
        height: 1.22,
        letterSpacing: 0,
      );
}

// ============================================================================
// ASSETS
// ============================================================================
class _AppAssets {
  static const String backArrow = 'assets/images/back_icon.svg';
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

  Widget _buildSlide(int page) {
    switch (page) {
      case 0:
        return _WelcomeSlide(key: const ValueKey(0), onNext: _onNext);
      case 1:
        return _PrivacySlide(
          key: const ValueKey(1),
          onNext: _onNext,
          onBack: _onBack,
        );
      case 2:
        return _ChooseModelSlide(
          key: const ValueKey(2),
          models: _models,
          isLoading: _isLoadingModels,
          selectedModel: _selectedModel,
          onSelect: (model) => setState(() => _selectedModel = model),
          onNext: _onNext,
          onBack: _onBack,
        );
      case 3:
        return _PrecautionsSlide(
          key: const ValueKey(3),
          onNext: _onNext,
          onBack: _onBack,
        );
      case 4:
      default:
        return _FinishSlide(key: const ValueKey(4), onFinish: _onFinish);
    }
  }

  void _onNext() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_page < 4) _page++;
    });
  }

  void _onBack() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_page > 0) _page--;
    });
  }

  Future<void> _onFinish() async {
    if (_isDownloading) return;
    HapticFeedback.mediumImpact();
    setState(() => _isDownloading = true);
    if (_selectedModel != null) {
      final url = ModelService.getDownloadUrl(_selectedModel!.id);
      ref
          .read(downloadProvider.notifier)
          .startDownloadWithUrl(_selectedModel!, url);
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            brightness == Brightness.dark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: flux.background,
        body: FluxAuraBackground(
          primary: flux.accent,
          secondary: flux.accentWarm,
          intensity: 0.06,
          period: const Duration(seconds: 80),
          child: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.96, end: 1.0).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                          child: child,
                        ),
                      );
                    },
                    child: _buildSlide(_page),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 16,
                  child: AnimatedOpacity(
                    opacity: (_page > 0 && _page < 4) ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    child: IgnorePointer(
                      ignoring: !(_page > 0 && _page < 4),
                      child: _PageIndicator(
                        currentPage: _page,
                        totalPages: 5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SHARED COMPONENTS
// ============================================================================

/// Rounded-square glyph badge shown at the top of each content slide.
class _IconBadge extends StatelessWidget {
  final IconData icon;
  const _IconBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        color: _kOnboardingBlue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Icon(icon, size: 44, color: _kOnboardingBlue),
    );
  }
}

/// Shared scaffold for the three middle content slides: a back button, a
/// centered glyph + title, a scrollable body, and a bottom-right Next button.
class _ContentSlideScaffold extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget body;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final bool nextEnabled;
  final TextAlign titleAlign;

  const _ContentSlideScaffold({
    required this.icon,
    required this.title,
    required this.body,
    required this.onNext,
    required this.onBack,
    this.nextEnabled = true,
    this.titleAlign = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: BouncyFadeSlide(
              delay: Duration.zero,
              duration: const Duration(milliseconds: 400),
              slideOffset: -16,
              slideDirection: Axis.horizontal,
              child: _BackButton(onPressed: onBack),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(top: 16, bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BouncyFadeSlide(
                    delay: const Duration(milliseconds: 60),
                    duration: const Duration(milliseconds: 600),
                    slideOffset: 14,
                    child: Center(child: _IconBadge(icon: icon)),
                  ),
                  const SizedBox(height: 28),
                  BouncyFadeSlide(
                    delay: const Duration(milliseconds: 140),
                    duration: const Duration(milliseconds: 600),
                    slideOffset: 16,
                    child: Text(
                      title,
                      style: _AppTypography.slideTitle(context),
                      textAlign: titleAlign,
                    ),
                  ),
                  const SizedBox(height: 22),
                  BouncyFadeSlide(
                    delay: const Duration(milliseconds: 220),
                    duration: const Duration(milliseconds: 600),
                    slideOffset: 22,
                    child: body,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 48),
            child: Align(
              alignment: Alignment.centerRight,
              child: BouncyFadeSlide(
                delay: const Duration(milliseconds: 280),
                duration: const Duration(milliseconds: 500),
                slideOffset: 18,
                child: _AnimatedButton(
                  text: AppLocalizations.of(context)!.next,
                  onPressed: nextEnabled ? onNext : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SLIDE 1 — WELCOME
// ============================================================================
class _WelcomeSlide extends StatelessWidget {
  final VoidCallback onNext;

  const _WelcomeSlide({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -80) onNext();
      },
      behavior: HitTestBehavior.opaque,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: constraints.maxHeight * 0.47,
                child: BouncyFadeSlide(
                  delay: const Duration(milliseconds: 120),
                  duration: const Duration(milliseconds: 800),
                  slideOffset: 12,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.92, end: 1.0),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, scale, child) {
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Text(
                      AppLocalizations.of(context)!.welcomeToFlux,
                      style: _AppTypography.heading(context),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 118,
                child: BouncyFadeSlide(
                  delay: const Duration(milliseconds: 700),
                  duration: const Duration(milliseconds: 600),
                  slideOffset: 10,
                  child: BouncyTap(
                    onTap: onNext,
                    scaleDown: 0.96,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSlideHint(color: flux.textSecondary),
                        const SizedBox(height: 8),
                        Text(
                          'Swipe to start',
                          style: _AppTypography.backButton(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// SLIDE 2 — PRIVACY-FIRST
// ============================================================================
class _PrivacySlide extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _PrivacySlide({super.key, required this.onNext, required this.onBack});

  @override
  Widget build(BuildContext context) {
    const paragraphs = <String>[
      'Flux is designed to respect your privacy.',
      'Your data is stored locally and is not sent anywhere. Not to us, not to an external provider.',
      'The source code is open, so everyone can view and iterate on it.',
    ];

    return _ContentSlideScaffold(
      icon: Icons.lock_rounded,
      title: 'Flux is Privacy-First',
      titleAlign: TextAlign.start,
      onNext: onNext,
      onBack: onBack,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final paragraph in paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                paragraph,
                style: _AppTypography.bodyText(context),
                textAlign: TextAlign.start,
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// SLIDE 3 — CHOOSE AN AI MODEL
// ============================================================================
class _ChooseModelSlide extends StatelessWidget {
  final List<HFModel> models;
  final bool isLoading;
  final HFModel? selectedModel;
  final Function(HFModel) onSelect;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _ChooseModelSlide({
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

    final Widget body = isLoading
        ? SizedBox(
            height: 220,
            child: Center(
              child: CircularProgressIndicator(
                color: flux.textPrimary,
                strokeWidth: 2,
              ),
            ),
          )
        : Column(
            children: [
              for (var index = 0; index < models.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BouncyFadeSlide(
                    delay: Duration(milliseconds: 120 + index * 80),
                    duration: const Duration(milliseconds: 450),
                    slideOffset: 20,
                    child: _ModelCard(
                      model: models[index],
                      isSelected: selectedModel?.id == models[index].id,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onSelect(models[index]);
                      },
                    ),
                  ),
                ),
            ],
          );

    return _ContentSlideScaffold(
      icon: Icons.auto_awesome_rounded,
      title: 'Choose an AI model',
      onNext: onNext,
      onBack: onBack,
      nextEnabled: selectedModel != null,
      body: body,
    );
  }
}

class _ModelCard extends StatelessWidget {
  final HFModel model;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModelCard({
    required this.model,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;

    final sizeLabel = model.sizeMB >= 1024
        ? '${(model.sizeMB / 1024).toStringAsFixed(1)} GB'
        : '${model.sizeMB} MB';
    final base = (model.baseModel != null && model.baseModel!.isNotEmpty)
        ? model.baseModel!
        : model.name;
    final subtitle = '$base \u00b7 $sizeLabel';

    return BouncyTap(
      onTap: onTap,
      scaleDown: 0.96,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        decoration: BoxDecoration(
          color: flux.surface,
          borderRadius: BorderRadius.circular(FluxRadii.card),
          border: Border.all(
            color: isSelected
                ? _kOnboardingBlue.withValues(alpha: 0.6)
                : flux.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _kOnboardingBlue.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SvgPicture.asset(
                  'assets/images/chip.svg',
                  width: 22,
                  height: 22,
                  colorFilter: const ColorFilter.mode(
                    _kOnboardingBlue,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.name,
                    style: Theme.of(context).textTheme.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? flux.textPrimary
                        : flux.textPrimary.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: isSelected
                          ? Icon(
                              Icons.check_rounded,
                              key: const ValueKey('check'),
                              size: 20,
                              color: flux.background,
                            )
                          : Icon(
                              Icons.arrow_downward_rounded,
                              key: const ValueKey('download'),
                              size: 20,
                              color: flux.textPrimary,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SLIDE 4 — PRECAUTIONS
// ============================================================================
class _PrecautionsSlide extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _PrecautionsSlide({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    const items = <String>[
      'AI may make mistakes, please verify responses and claims.',
      'All AI responses are generated locally on your device.',
      'Do not rely on AI for medical, legal, or financial advice.',
      'We do not collect, store, or share any personal data.',
    ];

    return _ContentSlideScaffold(
      icon: Icons.gpp_maybe_rounded,
      title: 'Before starting, read precautions',
      onNext: onNext,
      onBack: onBack,
      body: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PrecautionCard(number: i + 1, text: items[i]),
            ),
        ],
      ),
    );
  }
}

class _PrecautionCard extends StatelessWidget {
  final int number;
  final String text;

  const _PrecautionCard({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: flux.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: flux.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: _kOnboardingBlue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: GoogleFonts.instrumentSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SLIDE 5 — FINISH
// ============================================================================
class _FinishSlide extends StatelessWidget {
  final VoidCallback onFinish;

  const _FinishSlide({super.key, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -80) onFinish();
      },
      behavior: HitTestBehavior.opaque,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: constraints.maxHeight * 0.47,
                child: BouncyFadeSlide(
                  delay: const Duration(milliseconds: 120),
                  duration: const Duration(milliseconds: 800),
                  slideOffset: 12,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.92, end: 1.0),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, scale, child) {
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Text(
                      'Flux is ready!',
                      style: _AppTypography.heading(context),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 118,
                child: BouncyFadeSlide(
                  delay: const Duration(milliseconds: 700),
                  duration: const Duration(milliseconds: 600),
                  slideOffset: 10,
                  child: BouncyTap(
                    onTap: onFinish,
                    scaleDown: 0.96,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSlideHint(color: flux.textSecondary),
                        const SizedBox(height: 8),
                        Text(
                          "You're all set. Flux is ready.",
                          style: _AppTypography.backButton(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// COMPONENTS — page indicator, buttons, animations
// ============================================================================

class _PageIndicator extends StatelessWidget {
  final int currentPage;
  final int totalPages;

  const _PageIndicator({
    required this.currentPage,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalPages, (index) {
        final isActive = index == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive
                ? flux.textPrimary
                : flux.textTertiary.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class AnimatedSlideHint extends StatefulWidget {
  final Color color;

  const AnimatedSlideHint({super.key, required this.color});

  @override
  State<AnimatedSlideHint> createState() => _AnimatedSlideHintState();
}

class _AnimatedSlideHintState extends State<AnimatedSlideHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -4 * _controller.value),
          child: child,
        );
      },
      child: Icon(
        Icons.keyboard_arrow_up_rounded,
        size: 18,
        color: widget.color,
      ),
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
    return BouncyTap(
      onTap: onPressed,
      scaleDown: 0.94,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: onPressed != null
              ? flux.textPrimary
              : flux.textPrimary.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: _AppTypography.button(context)),
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
        padding: const EdgeInsets.only(right: 12, top: 12, bottom: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(
              _AppAssets.backArrow,
              width: 10,
              height: 18,
              colorFilter: ColorFilter.mode(
                flux.textSecondary,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 13),
            Text(
              AppLocalizations.of(context)!.back,
              style: _AppTypography.backButton(context),
            ),
          ],
        ),
      ),
    );
  }
}
