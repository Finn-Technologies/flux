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
import '../../l10n/app_localizations.dart';

/// Settings — monochrome, borderless redesign.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showTokenSpeed = false;
  bool _isAssistantEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _showTokenSpeed = prefs.getBool('showTokenSpeed') ?? false;
        _isAssistantEnabled = prefs.getBool('isAssistantEnabled') ?? false;
      });
    }
  }

  Future<void> _toggleTokenSpeed(bool value) async {
    HapticFeedback.selectionClick();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showTokenSpeed', value);
    if (mounted) setState(() => _showTokenSpeed = value);
  }

  Future<void> _toggleAssistant(bool value) async {
    HapticFeedback.selectionClick();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAssistantEnabled', value);
    if (mounted) setState(() => _isAssistantEnabled = value);
    
    // In a real implementation, we would trigger platform-specific code here
    // for Android's ACTION_VOICE_ASSISTANT_SETTINGS or similar.
  }

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    final loc = AppLocalizations.of(context)!;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: flux.background,
        body: Stack(
            children: [
              Positioned(
                left: 20,
                top: topPadding + 48,
                child: FluxBackButton(onTap: () => context.pop()),
              ),
              Positioned(
                left: 20,
                top: topPadding + 100,
                child: FluxTitle(title: loc.settings),
              ),
              Positioned.fill(
                top: topPadding + 150,
                left: 20,
                right: 20,
                child: ListView(
                  padding: EdgeInsets.only(bottom: bottomSafe + 24),
                  cacheExtent: 500,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    const _SectionLabel(label: 'General'),
                    const SizedBox(height: 10),
                    _StickerTile(
                      title: 'Token Speed',
                      subtitle: 'Show tok/s on chat and editor',
                      icon: Icons.speed_rounded,
                      trailing: CupertinoSwitch(
                        value: _showTokenSpeed,
                        activeTrackColor: flux.textPrimary,
                        onChanged: _toggleTokenSpeed,
                      ),
                      onTap: () => _toggleTokenSpeed(!_showTokenSpeed),
                    ),
                    const SizedBox(height: 16),
                    _StickerTile(
                      title: 'Digital Assistant',
                      subtitle: 'Use Flux as your default assistant (Android)',
                      icon: Icons.assistant_rounded,
                      trailing: CupertinoSwitch(
                        value: _isAssistantEnabled,
                        activeTrackColor: flux.textPrimary,
                        onChanged: _toggleAssistant,
                      ),
                      onTap: () => _toggleAssistant(!_isAssistantEnabled),
                    ),
                    const SizedBox(height: 28),
                    const _SectionLabel(label: 'Data'),
                    const SizedBox(height: 10),
                    _StickerTile(
                      title: loc.clearCache,
                      subtitle: loc.removeTemporaryFiles,
                      icon: Icons.delete_sweep_rounded,
                      destructive: true,
                      onTap: () => _confirmClearCache(context, textTheme),
                    ),
                    const SizedBox(height: 28),
                    const _SectionLabel(label: 'About'),
                    const SizedBox(height: 10),
                    _StickerTile(
                      title: loc.aboutFlux,
                      subtitle: '${loc.version} ${AppVersion.version}',
                      icon: Icons.info_rounded,
                      onTap: () => context.push('/settings/about'),
                      showChevron: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
      ),
    );
}

  void _confirmClearCache(BuildContext context, TextTheme textTheme) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: flux.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FluxRadii.dialog)),
        title: Text(loc.clearCacheQuestion, style: textTheme.headlineMedium),
        content: Text(loc.clearCacheMessage, style: textTheme.bodySmall),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Text(loc.cancel,
                style:
                    textTheme.bodyMedium?.copyWith(color: flux.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
              final prefs = await SharedPreferences.getInstance();
              for (final key in [
                'onboarded',
                'selectedModelId',
                'language'
              ]) {
                await prefs.remove(key);
              }
              await Hive.box('chats').clear();
              await Hive.box('creations').clear();
              await Hive.box('settings').clear();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(loc.cacheCleared,
                        style: textTheme.bodySmall),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FluxRadii.snackBar)),
                    margin: const EdgeInsets.all(20),
                  ),
                );
              }
            },
            child: Text(loc.confirm,
                style: textTheme.bodyMedium
                    ?.copyWith(color: Colors.red, fontWeight: FontWeight.w400)),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        label.toUpperCase(),
        style: textTheme.labelLarge?.copyWith(
          color: flux.textSecondary,
          letterSpacing: 1.4,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// Monochrome settings tile: a simple rounded icon container on the left and
/// a soft drop shadow under the whole card so it pops off the page.
class _StickerTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool destructive;
  final bool showChevron;

  const _StickerTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.trailing,
    this.destructive = false,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;

    return BouncyTap(
      onTap: onTap,
      scaleDown: 0.97,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
        decoration: BoxDecoration(
          color: flux.surface,
          borderRadius: BorderRadius.circular(FluxRadii.card),
        ),
        child: Row(
          children: [
            _StickerChip(icon: icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.bodyLarge?.copyWith(
                      color: flux.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: textTheme.bodySmall),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (showChevron)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: flux.textSecondary.withValues(alpha: 0.55),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Monochrome rounded icon container.
class _StickerChip extends StatelessWidget {
  final IconData icon;

  const _StickerChip({required this.icon});

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: flux.textPrimary.withValues(alpha: 0.05),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          icon,
          size: 20,
          color: flux.textPrimary,
        ),
      ),
    );
  }
}
