import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            // Header
            Positioned(
              left: 20,
              top: 60,
              child: Text(
                'Settings',
                style: _TextStyles.title,
              ),
            ),

            // Settings items - NO bottom navigation here (FluxShell provides it)
            Positioned(
              left: 20,
              right: 20,
              top: 120,
              bottom: 100, // Space for bottom navigation from FluxShell
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Models option
                  _buildSettingsItem(
                    title: 'Models',
                    subtitle: 'Download and manage AI models',
                    onTap: () => context.push('/settings/models'),
                    index: 0,
                  ),
                  const SizedBox(height: 12),

                  // Clear cache option
                  _buildSettingsItem(
                    title: 'Clear cache',
                    subtitle: 'Remove temporary files',
                    isDestructive: true,
                    onTap: () => _confirm(context, 'Clear cache?',
                        'This removes temporary files only.', 'Clear'),
                    index: 1,
                  ),
                  const SizedBox(height: 12),

                  // About option
                  _buildSettingsItem(
                    title: 'About Flux',
                    subtitle: 'Version 0.1.3',
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
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
    int index = 0,
  }) {
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
              Text(
                title,
                style: GoogleFonts.instrumentSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: isDestructive ? Colors.red : _Colors.black,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: _TextStyles.subtitle,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirm(BuildContext context, String title, String message, String action) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: _TextStyles.body.copyWith(fontWeight: FontWeight.w600),
        ),
        content: Text(
          message,
          style: _TextStyles.subtitle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: _TextStyles.subtitle,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: _Colors.background,
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
                style: _TextStyles.title,
              ),
              const SizedBox(height: 8),
              Text(
                'Version 0.1.3',
                style: _TextStyles.subtitle,
              ),
              const SizedBox(height: 24),
              Text(
                'Your private AI assistant that runs locally on your device. Your data stays on your phone — no account needed.',
                textAlign: TextAlign.center,
                style: _TextStyles.body.copyWith(color: _Colors.textSecondary),
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
