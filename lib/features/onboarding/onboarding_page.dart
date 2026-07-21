import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/hf_model.dart';
import '../../core/providers/download_provider.dart';
import '../../core/providers/model_provider.dart';
import '../../core/services/model_service.dart';
import '../../core/services/performance_service.dart';
import '../../core/theme/flux_theme.dart';
import '../../l10n/app_localizations.dart';

/// Figma node 134:151 and its four continuation frames.
///
/// The design is based on a 390 x 844 canvas. Positions that matter to the
/// composition are kept at their Figma values, while the content sheet and
/// safe-area controls remain usable on shorter and wider devices.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _page = 0;
  bool _isLoadingModels = true;
  bool _isFinishing = false;
  List<HFModel> _models = const [];
  HFModel? _selectedModel;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    final models = await ModelService.getRecommendedModels();
    if (!mounted) return;
    setState(() {
      _models = models.take(3).toList(growable: false);
      _selectedModel = models.isEmpty ? null : models.first;
      _isLoadingModels = false;
    });
  }

  void _next() {
    if (_page >= 4) {
      _finish();
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _page++);
  }

  void _back() {
    if (_page == 0) return;
    HapticFeedback.lightImpact();
    setState(() => _page--);
  }

  Future<void> _finish() async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);
    HapticFeedback.mediumImpact();

    final model = _selectedModel;
    if (model != null) {
      final url = ModelService.getDownloadUrl(model.id);
      ref.read(downloadProvider.notifier).startDownloadWithUrl(model, url);
      ref.read(selectedModelIdProvider.notifier).select(model.id);
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('onboarded', true);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final lowEnd = PerformanceService.instance.isConstrained;
    final overlay = Theme.of(context).brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: flux.background,
        body: Stack(
          children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration:
                    lowEnd ? Duration.zero : const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.025, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_page),
                  child: _buildPage(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context) {
    switch (_page) {
      case 0:
        return _EdgeSlide(
          title: '${AppLocalizations.of(context)!.welcomeToFlux}!',
          hint: 'Swipe to start',
          onAdvance: _next,
        );
      case 1:
        return _DetailSlide(
          iconAsset: 'assets/images/onboarding_privacy.svg',
          title: 'Flux is Privacy-First',
          onBack: _back,
          onNext: _next,
          child: const Text(
            'Flux is designed to respect your privacy.\n\n'
            'Your data is stored locally and is not sent anywhere. Not to us, '
            'not to an external provider.\n\n'
            'The source code is open, so everyone can view and iterate on it.',
          ),
        );
      case 2:
        return _DetailSlide(
          iconAsset: 'assets/images/onboarding_model.svg',
          title: 'Choose an AI model',
          onBack: _back,
          onNext: _selectedModel == null ? null : _next,
          child: _ModelChoices(
            models: _models,
            selectedModel: _selectedModel,
            isLoading: _isLoadingModels,
            onSelected: (model) {
              HapticFeedback.selectionClick();
              setState(() => _selectedModel = model);
            },
          ),
        );
      case 3:
        return _DetailSlide(
          iconAsset: 'assets/images/onboarding_precautions.svg',
          title: 'Before starting, read precautions',
          onBack: _back,
          onNext: _next,
          child: const _PrecautionGrid(),
        );
      default:
        return _EdgeSlide(
          title: 'Flux is ready!',
          hint: _isFinishing
              ? 'Preparing Flux…'
              : "You're all set. Flux is ready.",
          onAdvance: _finish,
          onBack: _back,
        );
    }
  }
}

class _EdgeSlide extends StatelessWidget {
  const _EdgeSlide({
    required this.title,
    required this.hint,
    required this.onAdvance,
    this.onBack,
  });

  final String title;
  final String hint;
  final VoidCallback onAdvance;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final topInset = MediaQuery.paddingOf(context).top;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onAdvance,
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -80) onAdvance();
      },
      child: Stack(
        children: [
          const Positioned.fill(child: _BottomAura()),
          if (onBack != null)
            Positioned(
              left: 20,
              top: topInset + 24,
              child: _BackButton(onPressed: onBack!),
            ),
          Center(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 20,
                    height: 1,
                  ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 132,
            child: Semantics(
              button: true,
              label: hint,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.keyboard_arrow_up_rounded,
                    size: 24,
                    color: flux.textSecondary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 16,
                          color: flux.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSlide extends StatelessWidget {
  const _DetailSlide({
    required this.iconAsset,
    required this.title,
    required this.onBack,
    required this.onNext,
    required this.child,
  });

  final String iconAsset;
  final String title;
  final VoidCallback onBack;
  final VoidCallback? onNext;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final size = MediaQuery.sizeOf(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final sheetHeight = (size.height * 0.508).clamp(390.0, 460.0).toDouble();

    return Stack(
      children: [
        Positioned(
          left: 20,
          top: topInset + 24,
          child: _BackButton(onPressed: onBack),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: topInset + 155,
          bottom: sheetHeight,
          child: Center(
            child: SvgPicture.asset(
              iconAsset,
              width: 90,
              height: 90,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: sheetHeight,
          child: Container(
            decoration: BoxDecoration(
              color: flux.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(25, 34, 25, 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 20,
                        height: 1.2,
                      ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: DefaultTextStyle(
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          fontSize: 16,
                          height: 1.25,
                          color: flux.textSecondary,
                        ),
                    child: child,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: _NextButton(onPressed: onNext),
                ),
                SizedBox(height: MediaQuery.paddingOf(context).bottom),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ModelChoices extends StatelessWidget {
  const _ModelChoices({
    required this.models,
    required this.selectedModel,
    required this.isLoading,
    required this.onSelected,
  });

  final List<HFModel> models;
  final HFModel? selectedModel;
  final bool isLoading;
  final ValueChanged<HFModel> onSelected;

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    if (isLoading) {
      return Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: flux.textPrimary,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: models.length,
      separatorBuilder: (_, __) => const SizedBox(height: 9),
      itemBuilder: (context, index) {
        final model = models[index];
        final selected = selectedModel?.id == model.id;
        return Semantics(
          selected: selected,
          button: true,
          label: '${model.name}, ${model.description}',
          child: InkWell(
            borderRadius: BorderRadius.circular(50),
            onTap: () => onSelected(model),
            child: Ink(
              height: 60,
              padding: const EdgeInsets.only(left: 25, right: 12),
              decoration: BoxDecoration(
                color: flux.background,
                borderRadius: BorderRadius.circular(50),
                border: selected
                    ? Border.all(color: flux.textPrimary, width: 1)
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          model.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 14,
                                    height: 1.15,
                                    color: flux.textPrimary,
                                  ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          model.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 14,
                                    height: 1.15,
                                    color: flux.textSecondary,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: flux.textPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      selected
                          ? Icons.check_rounded
                          : Icons.arrow_downward_rounded,
                      size: 22,
                      color: flux.background,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PrecautionGrid extends StatelessWidget {
  const _PrecautionGrid();

  static const items = [
    'AI may make mistakes, please verify responses and claims.',
    'All AI responses are generated locally on your device.',
    'Do not rely on AI for medical, legal, or financial advice.',
    'We do not collect, store, or share any personal data.',
  ];

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 8,
        mainAxisExtent: 104,
      ),
      itemBuilder: (context, index) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: flux.background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: flux.textPrimary,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: flux.background,
                      fontWeight: FontWeight.w500,
                      height: 1,
                    ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                items[index],
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: flux.textPrimary,
                      fontSize: 13,
                      height: 1.15,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return Semantics(
      button: true,
      label: AppLocalizations.of(context)!.back,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: flux.textSecondary,
              ),
              const SizedBox(width: 14),
              Text(
                AppLocalizations.of(context)!.back,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 16,
                      color: flux.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onPressed,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          decoration: BoxDecoration(
            color: flux.textPrimary.withValues(
              alpha: onPressed == null ? 0.3 : 1.0,
            ),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            AppLocalizations.of(context)!.next,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: flux.background,
                  fontSize: 14,
                  height: 1,
                ),
          ),
        ),
      ),
    );
  }
}

class _BottomAura extends StatelessWidget {
  const _BottomAura();

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.transparent,
              flux.accent.withValues(alpha: 0.10),
              flux.accent.withValues(alpha: 0.34),
            ],
            stops: const [0, 0.48, 0.72, 1],
          ),
        ),
      ),
    );
  }
}
