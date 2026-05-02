import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_version.dart';
import '../../core/theme/flux_theme.dart';
import '../../core/widgets/flux_widgets.dart';
import '../../core/widgets/flux_animations.dart';
import '../../core/constants/responsive.dart';
import '../../l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;
    final isDesktop = context.isDesktop;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPad = isDesktop ? 24.0 : MediaQuery.of(context).padding.bottom + 84.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: flux.background,
        body: Stack(
          children: [
            Positioned(
              left: 20,
              top: topPadding + 52,
              child: FluxTitle(title: AppLocalizations.of(context)!.settings),
            ),

            Positioned(
              left: 20,
              right: 20,
              top: topPadding + 112,
              bottom: bottomPad,
                child: ListView(
                  padding: EdgeInsets.zero,
                  cacheExtent: 500,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    BouncyFadeSlide(
                      delay: FluxDurations.staggerStep * 0,
                      child: _buildSettingsItem(
                        context: context,
                        title: AppLocalizations.of(context)!.models,
                        subtitle: AppLocalizations.of(context)!.downloadAndManageModels,
                        icon: Icons.memory,
                        onTap: () => context.push('/settings/models'),
                      ),
                    ),
                    const SizedBox(height: 10),

                    BouncyFadeSlide(
                      delay: FluxDurations.staggerStep * 1,
                      child: _buildSettingsItem(
                        context: context,
                        title: AppLocalizations.of(context)!.clearCache,
                        subtitle: AppLocalizations.of(context)!.removeTemporaryFiles,
                        icon: Icons.cleaning_services_outlined,
                        isDestructive: true,
                        onTap: () => _confirm(
                          context,
                          AppLocalizations.of(context)!.clearCacheQuestion,
                          AppLocalizations.of(context)!.clearCacheMessage,
                          AppLocalizations.of(context)!.confirm,
                          () async {
                            final prefs = await SharedPreferences.getInstance();
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
                                    AppLocalizations.of(context)!.cacheCleared,
                                    style: textTheme.bodySmall,
                                  ),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  margin: const EdgeInsets.all(20),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    BouncyFadeSlide(
                      delay: FluxDurations.staggerStep * 2,
                      child: _buildSettingsItem(
                        context: context,
                        title: AppLocalizations.of(context)!.aboutFlux,
                        subtitle: '${AppLocalizations.of(context)!.version} ${AppVersion.version}',
                        icon: Icons.info_outline,
                        onTap: () => context.push('/settings/about'),
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

  Widget _buildSettingsItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;

    return BouncyTap(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      scaleDown: 0.92,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: flux.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: flux.border,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: flux.textPrimary.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDestructive
                    ? Colors.red.withValues(alpha: 0.08)
                    : flux.textPrimary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isDestructive ? Colors.red : flux.textPrimary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.bodyLarge?.copyWith(
                      color: isDestructive ? Colors.red : flux.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: flux.textSecondary.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  void _confirm(BuildContext context, String title, String message, String action, [VoidCallback? onAction]) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(title, style: textTheme.headlineMedium),
          content: Text(message, style: textTheme.bodySmall),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                AppLocalizations.of(context)!.cancel,
                style: textTheme.bodyMedium?.copyWith(color: flux.textSecondary),
              ),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                onAction?.call();
                Navigator.pop(ctx);
              },
              child: Text(
                action,
                style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: flux.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title, style: textTheme.headlineMedium),
          content: Text(message, style: textTheme.bodySmall),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                AppLocalizations.of(context)!.cancel,
                style: textTheme.bodyMedium?.copyWith(color: flux.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                onAction?.call();
                Navigator.pop(ctx);
              },
              child: Text(
                action,
                style: textTheme.bodyMedium?.copyWith(color: Colors.red, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }
  }
}
