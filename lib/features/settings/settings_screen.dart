import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          _SettingsSection(
            title: 'Storage',
            delay: 0,
            children: [
              _SettingsTile(
                icon: Icons.delete_outline,
                title: 'Clear cache',
                subtitle: 'Remove temporary files',
                isDestructive: true,
                colorScheme: colorScheme,
                onTap: () => _confirm(context, 'Clear cache?',
                    'This removes temporary files only.', 'Clear', true),
              ),
            ],
          ),
          _SettingsSection(
            title: 'About',
            delay: 100,
            children: [
              _SettingsTile(
                icon: Icons.info_outline,
                title: 'About Flux',
                subtitle: 'Version 0.1.0',
                colorScheme: colorScheme,
                onTap: () => _showAboutSheet(context),
              ),
            ],
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  void _confirm(BuildContext context, String title, String message,
      String action, bool destructive) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Text(message,
                  style: TextStyle(
                      fontSize: 16, color: colorScheme.secondary, height: 1.5)),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(action,
                        style: TextStyle(
                            fontSize: 16,
                            color: destructive
                                ? colorScheme.error
                                : colorScheme.primary)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutSheet(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(28),
                ),
                child:
                    Icon(Icons.smart_toy, size: 40, color: colorScheme.primary),
              ),
              const SizedBox(height: 24),
              Text('Flux',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Version 0.1.0',
                  style: TextStyle(fontSize: 15, color: colorScheme.secondary)),
              const SizedBox(height: 24),
              Text(
                'Your private AI assistant that runs locally on your device. Your data stays on your phone — no account needed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16, color: colorScheme.secondary, height: 1.5),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final int delay;
  final List<Widget> children;

  const _SettingsSection(
      {required this.title, required this.delay, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 10),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ),
        ...children,
      ],
    ).animate().fadeIn(delay: Duration(milliseconds: delay), duration: 350.ms);
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final ColorScheme colorScheme;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colorScheme,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 4),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isDestructive
              ? colorScheme.error.withValues(alpha: 0.1)
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon,
            size: 22,
            color: isDestructive ? colorScheme.error : colorScheme.primary),
      ),
      title: Text(
        title,
        style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: isDestructive ? colorScheme.error : null),
      ),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 14, color: colorScheme.secondary)),
      trailing:
          Icon(Icons.chevron_right, size: 24, color: colorScheme.secondary),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
    );
  }
}
