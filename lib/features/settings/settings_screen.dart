import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_version.dart';
import '../../core/theme/flux_theme.dart';
import '../../core/widgets/animated_tap_card.dart';
import '../../core/widgets/flux_widgets.dart';
import '../../l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
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
              child: FluxTitle(title: AppLocalizations.of(context)!.settings),
            ),

            Positioned(
              left: 20,
              right: 20,
              top: 120,
              bottom: 108,
              child: ListView(
                padding: EdgeInsets.zero,
                cacheExtent: 500,
                children: [
                  StaggeredEntrance(
                    index: 0,
                    child: _buildSettingsItem(
                      context: context,
                      title: AppLocalizations.of(context)!.models,
                      subtitle: AppLocalizations.of(context)!.downloadAndManageModels,
                      onTap: () => context.push('/settings/models'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  StaggeredEntrance(
                    index: 1,
                    child: _buildSettingsItem(
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
                                  AppLocalizations.of(context)!.cacheCleared,
                                  style: textTheme.bodySmall,
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
                    ),
                  ),
                  const SizedBox(height: 12),

                  StaggeredEntrance(
                    index: 2,
                    child: _buildSettingsItem(
                      context: context,
                      title: AppLocalizations.of(context)!.aboutFlux,
                      subtitle: '${AppLocalizations.of(context)!.version} ${AppVersion.version}',
                      onTap: () => _showAboutSheet(context),
                    ),
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
  }) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;

    return AnimatedTapCard(
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
              style: textTheme.bodyLarge?.copyWith(
                color: isDestructive ? Colors.red : flux.textPrimary,
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
    );
  }

  void _confirm(BuildContext context, String title, String message, String action, [VoidCallback? onAction]) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: flux.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
              style: textTheme.bodyMedium?.copyWith(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutSheet(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;

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
                style: textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                '${AppLocalizations.of(context)!.version} ${AppVersion.version}',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.yourPrivateAI,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(color: flux.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

