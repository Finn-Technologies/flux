import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/flux_theme.dart';
import '../../core/widgets/animated_tap_card.dart';
import '../../l10n/app_localizations.dart';

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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
      backgroundColor: flux.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: 20,
              top: 60,
              child: Text(
                AppLocalizations.of(context)!.settings,
                style: _TextStyles.title(context),
              ),
            ),

            Positioned(
              left: 20,
              right: 20,
              top: 120,
              bottom: 108,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildSettingsItem(
                    context: context,
                    title: AppLocalizations.of(context)!.models,
                    subtitle: AppLocalizations.of(context)!.downloadAndManageModels,
                    onTap: () => context.push('/settings/models'),
                    index: 0,
                  ),
                  const SizedBox(height: 12),

                  _buildSettingsItem(
                    context: context,
                    title: AppLocalizations.of(context)!.clearCache,
                    subtitle: AppLocalizations.of(context)!.removeTemporaryFiles,
                    isDestructive: true,
                    onTap: () => _confirm(
                      context,
                      AppLocalizations.of(context)!.clearCacheQuestion,
                      AppLocalizations.of(context)!.clearCacheMessage,
                      AppLocalizations.of(context)!.confirm,
                      () async {
                        final prefs = await SharedPreferences.getInstance();
                        // Preserve critical flags
                        final onboarded = prefs.getBool('onboarded');
                        final selectedModel = prefs.getString('selectedModelId');
                        await prefs.clear();
                        if (onboarded == true) await prefs.setBool('onboarded', true);
                        if (selectedModel != null) await prefs.setString('selectedModelId', selectedModel);
                        await Hive.box('settings').clear();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Cache cleared',
                                style: GoogleFonts.instrumentSans(fontSize: 14),
                              ),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              margin: const EdgeInsets.all(20),
                            ),
                          );
                        }
                      },
                    ),
                    index: 1,
                  ),
                  const SizedBox(height: 12),

                  _buildSettingsItem(
                    context: context,
                    title: AppLocalizations.of(context)!.aboutFlux,
                    subtitle: '${AppLocalizations.of(context)!.version} 0.1.5',
                    onTap: () => _showAboutSheet(context),
                    index: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
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
      duration: Duration(milliseconds: 350 + (index * 80)),
      curve: Curves.easeInOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 15 * (1.0 - value)),
            child: child,
          ),
        );
      },
      child: AnimatedTapCard(
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              onAction?.call();
              Navigator.pop(ctx);
            },
            child: Text(
              action,
              style: const TextStyle(color: Colors.red),
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
          padding: const EdgeInsets.fromLTRB(40, 30, 40, 60),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Flux',
                style: _TextStyles.title(context),
              ),
              const SizedBox(height: 8),
              Text(
                '${AppLocalizations.of(context)!.version} 0.1.5',
                style: _TextStyles.subtitle(context),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.yourPrivateAI,
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
