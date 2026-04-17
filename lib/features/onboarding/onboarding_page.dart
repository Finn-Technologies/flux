import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/model_service.dart';
import '../../core/models/hf_model.dart';
import '../../core/providers/download_provider.dart';
import '../../core/providers/model_provider.dart';

// ============================================================================
// COLORS - Exact from Figma
// ============================================================================
class _AppColors {
  static const Color background = Color(0xFFF9F9F9);
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color textSecondary = Color.fromRGBO(0, 0, 0, 0.5);
  static const Color border = Color.fromRGBO(0, 0, 0, 0.1);
}

// ============================================================================
// TYPOGRAPHY - Instrument Sans from Google Fonts
// ============================================================================
class _AppTypography {
  static TextStyle get heading => GoogleFonts.instrumentSans(
        fontSize: 25,
        fontWeight: FontWeight.w400,
        color: _AppColors.black,
        height: 1.22,
        letterSpacing: 0,
      );

  static TextStyle get description => GoogleFonts.instrumentSans(
        fontSize: 20,
        fontWeight: FontWeight.w400,
        color: _AppColors.textSecondary,
        height: 1.22,
        letterSpacing: 0,
      );

  static TextStyle get button => GoogleFonts.instrumentSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: _AppColors.white,
        height: 1.22,
        letterSpacing: 0,
      );

  static TextStyle get backButton => GoogleFonts.instrumentSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: _AppColors.textSecondary,
        height: 1.22,
        letterSpacing: 0,
      );

  static TextStyle get modelTitle => GoogleFonts.instrumentSans(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: _AppColors.black,
        letterSpacing: 0,
      );

  static TextStyle get modelSubtitle => GoogleFonts.instrumentSans(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: _AppColors.textSecondary,
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
// ANIMATION CONSTANTS - Fast animations
// ============================================================================
class _AnimDurations {
  static const Duration fast = Duration(milliseconds: 250);
  static const Duration medium = Duration(milliseconds: 350);
}

class _AnimCurves {
  static const Curve smooth = Curves.easeInOut;
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

  // Model selection state
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

  Future<void> _onFinish() async {
    if (_selectedModel != null) {
      final url = ModelService.getDownloadUrl(_selectedModel!.id);
      ref.read(downloadProvider.notifier).startDownloadWithUrl(_selectedModel!, url);
      ref.read(selectedModelIdProvider.notifier).state = _selectedModel!.id;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarded', true);

    if (mounted) context.go('/chat');
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: _AppColors.background,
      body: SafeArea(
        child: PageView(
          controller: _controller,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (i) => setState(() => _page = i),
          children: [
            _WelcomeSlide(onNext: _onNext),
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
    );
  }
}

// ============================================================================
// SLIDES
// ============================================================================

class _WelcomeSlide extends StatelessWidget {
  final VoidCallback onNext;

  const _WelcomeSlide({required this.onNext});

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
                  Text(
                    'Welcome to Flux',
                    style: _AppTypography.heading,
                    textAlign: TextAlign.center,
                  )
                      .animate()
                      .fadeIn(duration: _AnimDurations.medium),
                  
                  const SizedBox(height: 60),
                  
                  _AnimatedButton(
                    text: 'Start',
                    onPressed: onNext,
                  )
                      .animate()
                      .fadeIn(duration: _AnimDurations.fast, delay: 100.ms),
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
              child: _BackButton(onPressed: onBack)
                  .animate()
                  .fadeIn(duration: _AnimDurations.fast),
            ),

            Positioned(
              left: 20,
              right: 20,
              top: topPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'We value your privacy',
                    style: _AppTypography.heading,
                    textAlign: TextAlign.center,
                  )
                      .animate()
                      .fadeIn(duration: _AnimDurations.medium),
                  
                  const SizedBox(height: 20),
                  
                  Text(
                    "We designed Flux to use Local AI models, so your data doesn't go to corporations, not even us.",
                    style: _AppTypography.description,
                    textAlign: TextAlign.center,
                  )
                      .animate()
                      .fadeIn(duration: _AnimDurations.medium, delay: 50.ms),
                  
                  SizedBox(height: spacing),
                  
                  _AnimatedButton(
                    text: 'Next',
                    onPressed: onNext,
                  )
                      .animate()
                      .fadeIn(duration: _AnimDurations.fast, delay: 100.ms),
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
              child: _BackButton(onPressed: onBack)
                  .animate()
                  .fadeIn(duration: _AnimDurations.fast),
            ),

            Positioned(
              left: 20,
              right: 20,
              top: topPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Fully offline',
                    style: _AppTypography.heading,
                    textAlign: TextAlign.center,
                  )
                      .animate()
                      .fadeIn(duration: _AnimDurations.medium),
                  
                  const SizedBox(height: 20),
                  
                  Text(
                    'Since we use Local AI models, Flux works entirely offline, so you can ask questions even with no coverage.',
                    style: _AppTypography.description,
                    textAlign: TextAlign.center,
                  )
                      .animate()
                      .fadeIn(duration: _AnimDurations.medium, delay: 50.ms),
                  
                  SizedBox(height: spacing),
                  
                  _AnimatedButton(
                    text: 'Next',
                    onPressed: onNext,
                  )
                      .animate()
                      .fadeIn(duration: _AnimDurations.fast, delay: 100.ms),
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
    return Stack(
      children: [
        Positioned(
          left: 20,
          top: 74,
          child: _BackButton(onPressed: onBack)
              .animate()
              .fadeIn(duration: _AnimDurations.fast),
        ),

        Positioned(
          left: 20,
          top: 122,
          right: 20,
          child: Text(
            'Choose a model to download',
            style: _AppTypography.heading,
          )
              .animate()
              .fadeIn(duration: _AnimDurations.medium),
        ),

        Positioned(
          left: 20,
          top: 173,
          right: 20,
          child: Text(
            'Flux recommends models optimized for your device, ensuring they work properly.',
            style: _AppTypography.description,
          )
              .animate()
              .fadeIn(duration: _AnimDurations.medium, delay: 50.ms),
        ),

        Positioned(
          left: 20,
          top: 265,
          right: 20,
          bottom: 100,
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: _AppColors.black,
                    strokeWidth: 2,
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: models.length,
                  itemBuilder: (context, index) {
                    final model = models[index];
                    final isSelected = selectedModel?.id == model.id;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () => onSelect(model),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                          decoration: BoxDecoration(
                            color: _AppColors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: isSelected ? _AppColors.black : _AppColors.border,
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
                                      'Flux Lite',
                                      style: _AppTypography.modelTitle,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Powered by ${model.name} (${(model.sizeMB / 1024).toStringAsFixed(1)} GB)',
                                      style: _AppTypography.modelSubtitle,
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
                                    color: isSelected ? _AppColors.black : _AppColors.border,
                                    width: 1,
                                  ),
                                  color: isSelected ? _AppColors.black : _AppColors.white,
                                ),
                                child: Center(
                                  child: isSelected
                                      ? const Icon(Icons.check, size: 16, color: _AppColors.white)
                                      : const Icon(Icons.add, size: 16, color: _AppColors.black),
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
          child: _AnimatedButton(
            text: 'Next',
            onPressed: selectedModel != null ? onNext : null,
          )
              .animate()
              .fadeIn(duration: _AnimDurations.fast),
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
                  Text(
                    "That's it. Flux is ready!",
                    style: _AppTypography.heading,
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 60),
                  
                  _AnimatedButton(
                    text: 'Finish',
                    onPressed: onFinish,
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

class _AnimatedButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;

  const _AnimatedButton({required this.text, required this.onPressed});

  @override
  State<_AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    widget.onPressed?.call();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: _AnimDurations.fast,
        curve: _AnimCurves.smooth,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          decoration: BoxDecoration(
            color: widget.onPressed != null
                ? _AppColors.black
                : _AppColors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            widget.text,
            style: _AppTypography.button,
          ),
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
    return GestureDetector(
      onTap: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SvgPicture.asset(
            _AppAssets.backArrow,
            width: 10,
            height: 18,
          ),
          const SizedBox(width: 13),
          Text(
            'Back',
            style: _AppTypography.backButton,
          ),
        ],
      ),
    );
  }
}
