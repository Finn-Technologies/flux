import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.smart_toy,
                      color: colorScheme.onPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Flux',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _IntroSlide(
                    icon: Icons.shield_outlined,
                    title: 'Private by design',
                    body:
                        'Your conversations never leave your device. No account, no servers, no tracking.',
                  ),
                  _IntroSlide(
                    icon: Icons.wifi_off_outlined,
                    title: 'Works offline',
                    body: 'Once downloaded, models run entirely on your phone.',
                  ),
                  _IntroSlide(
                    icon: Icons.speed_outlined,
                    title: 'Your AI, your rules',
                    body:
                        'Choose which models to install and tailor the experience to your device.',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _page == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _page == i
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: () {
                        if (_page < 2) {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          context.go('/onboarding/choose-model');
                        }
                      },
                      child: Text(
                        _page < 2 ? 'Continue' : 'Get Started',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  if (_page < 2)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextButton(
                        onPressed: () => context.go('/onboarding/choose-model'),
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            fontSize: 15,
                            color: colorScheme.secondary,
                          ),
                        ),
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
}

class _IntroSlide extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _IntroSlide({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, size: 40, color: colorScheme.primary),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 28,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.secondary,
              fontSize: 17,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
