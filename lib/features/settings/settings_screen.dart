import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/flux_theme.dart';

// ============================================================================
// TYPOGRAPHY - Instrument Sans
// ============================================================================
class _TextStyles {
  static TextStyle title(BuildContext context) => GoogleFonts.instrumentSans(
        fontSize: 25,
        fontWeight: FontWeight.w400,
        color: Theme.of(context).extension<FluxColorsExtension>()!.textPrimary,
        height: 1.22,
      );

  static TextStyle body(BuildContext context) => GoogleFonts.instrumentSans(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: Theme.of(context).extension<FluxColorsExtension>()!.textPrimary,
      );

  static TextStyle subtitle(BuildContext context) => GoogleFonts.instrumentSans(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: Theme.of(context).extension<FluxColorsExtension>()!.textSecondary,
      );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final brightness = Theme.of(context).brightness;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: flux.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: 20,
              top: 60,
              child: Text(
                'Settings',
                style: _TextStyles.title(context),
              ),
            ),

            Positioned(
              left: 20,
              right: 20,
              top: 120,
              bottom: 100,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildSettingsItem(
                    context: context,
                    title: 'Models',
                    subtitle: 'Download and manage AI models',
                    onTap: () => context.push('/settings/models'),
                    index: 0,
                  ),
                  const SizedBox(height: 12),

                  _buildSettingsItem(
                    context: context,
                    title: 'Clear cache',
                    subtitle: 'Remove temporary files',
                    isDestructive: true,
                    onTap: () => _confirm(
                      context,
                      'Clear cache?',
                      'This removes temporary files only.',
                      'Clear',
                      () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.clear();
                        await Hive.box('settings').clear();
                      },
                    ),
                    index: 1,
                  ),
                  const SizedBox(height: 12),

                  _buildSettingsItem(
                    context: context,
                    title: 'About Flux',
                    subtitle: 'Version 0.1.4',
                    onTap: () => _showAboutSheet(context),
                    index: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
    int index = 0,
  }) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 80)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 15 * (1.0 - value)),
            child: child,
          ),
        );
      },
      child: _AnimatedTapCard(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
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
              Text(
                title,
                style: GoogleFonts.instrumentSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: isDestructive ? Colors.red : flux.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: _TextStyles.subtitle(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirm(BuildContext context, String title, String message, String action, [VoidCallback? onAction]) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: flux.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: _TextStyles.body(context).copyWith(fontWeight: FontWeight.w600),
        ),
        content: Text(
          message,
          style: _TextStyles.subtitle(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: _TextStyles.subtitle(context),
            ),
          ),
          TextButton(
            onPressed: () {
              onAction?.call();
              Navigator.pop(ctx);
            },
            child: Text(
              action,
              style: GoogleFonts.instrumentSans(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutSheet(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    showModalBottomSheet(
      context: context,
      backgroundColor: flux.background,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 40, 40, 80),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Flux',
                style: _TextStyles.title(context),
              ),
              const SizedBox(height: 8),
              Text(
                'Version 0.1.4',
                style: _TextStyles.subtitle(context),
              ),
              const SizedBox(height: 24),
              Text(
                'Your private AI assistant that runs locally on your device. Your data stays on your phone \u2014 no account needed.',
                textAlign: TextAlign.center,
                style: _TextStyles.body(context).copyWith(color: flux.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Animated tap card with scale effect
class _AnimatedTapCard extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _AnimatedTapCard({required this.onTap, required this.child});

  @override
  State<_AnimatedTapCard> createState() => _AnimatedTapCardState();
}

class _AnimatedTapCardState extends State<_AnimatedTapCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    widget.onTap();
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
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
