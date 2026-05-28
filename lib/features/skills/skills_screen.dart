import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/providers/skill_provider.dart';
import '../../core/theme/flux_theme.dart';
import '../../core/widgets/flux_widgets.dart';
import '../../core/widgets/flux_animations.dart';

class SkillsScreen extends ConsumerWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skills = ref.watch(skillProvider);
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
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
            child: const FluxTitle(
              title: "Skills",
            ),
          ),
          Positioned.fill(
            top: topPadding + 150,
            left: 20,
            right: 20,
            child: Builder(
              builder: (context) {
                final hasCustom = skills.any((s) => !s.builtIn);
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: skills.length + 2 + (hasCustom ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == 0) return const _SectionLabel(label: 'Your Skills');
                    if (index == 1) return const SizedBox(height: 12);
                    final skillIndex = index - 2;
                    if (skillIndex >= skills.length) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 6, top: 4),
                        child: Text(
                          'Tap to toggle. Long-press a custom skill to remove it.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: flux.textSecondary,
                              ),
                        ),
                      );
                    }
                    final skill = skills[skillIndex];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: BouncyFadeSlide(
                        delay: Duration(milliseconds: skillIndex * 50),
                        child: _SkillTile(skill: skill),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Create / Import Skill FAB
          Positioned(
            right: 24,
            bottom: 40 + MediaQuery.of(context).padding.bottom,
            child: BouncyTap(
              onTap: () => _showSkillActionSheet(context, ref),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: flux.surface,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/images/plus.svg',
                    width: 28,
                    height: 28,
                    colorFilter:
                        ColorFilter.mode(flux.textPrimary, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSkillActionSheet(BuildContext context, WidgetRef ref) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: flux.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(FluxRadii.sheet)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionSheetTile(
                icon: Icons.edit_rounded,
                label: 'Create Skill',
                onTap: () {
                  Navigator.pop(context);
                  _showCreateSkillDialog(context, ref);
                },
              ),
              _ActionSheetTile(
                icon: Icons.file_open_rounded,
                label: 'Import from .md file',
                onTap: () {
                  Navigator.pop(context);
                  _importSkillFromFile(context, ref);
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: flux.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateSkillDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: flux.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FluxRadii.dialog)),
        title: const Text("Create New Skill"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(hintText: "Skill Name (e.g. Weather)"),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(hintText: "Description (How to use it)"),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                ref.read(skillProvider.notifier).addSkill(
                  Skill(
                    id: nameController.text.toLowerCase().replaceAll(' ', '_'),
                    name: nameController.text,
                    description: descController.text,
                  ),
                );
                Navigator.pop(context);
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  Future<void> _importSkillFromFile(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['md'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null && file.path != null) {
        final f = File(file.path!);
        if (!await f.exists()) return;
      }

      final text = bytes != null
          ? utf8.decode(bytes)
          : await File(file.path!).readAsString();

      // Derive name from first H1 heading, falling back to filename.
      String name = file.name.replaceAll(RegExp(r'\.md$', caseSensitive: false), '');
      final headingMatch = RegExp(r'^#\s+(.+)$', multiLine: true).firstMatch(text);
      if (headingMatch != null) {
        name = headingMatch.group(1)!.trim();
      }

      final id = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_|_$'), '');
      if (id.isEmpty) return;

      ref.read(skillProvider.notifier).addSkill(
        Skill(
          id: id,
          name: name,
          description: text.trim(),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not import skill: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FluxRadii.snackBar)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    }
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

class _SkillTile extends ConsumerWidget {
  final Skill skill;
  const _SkillTile({required this.skill});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;

    return BouncyTap(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(skillProvider.notifier).toggleSkill(skill.id);
      },
      onLongPress: skill.builtIn
          ? null
          : () {
              HapticFeedback.mediumImpact();
              _confirmDelete(context, ref);
            },
      scaleDown: 0.97,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          decoration: BoxDecoration(
            color: flux.surface,
            borderRadius: BorderRadius.circular(FluxRadii.card),
          ),
        child: Row(
          children: [
            _StickerChip(
              icon: _getIconForSkill(skill.id),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    skill.name,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    skill.description,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: skill.isEnabled,
              activeTrackColor: flux.textPrimary,
              onChanged: (_) {
                HapticFeedback.lightImpact();
                ref.read(skillProvider.notifier).toggleSkill(skill.id);
              },
            ),
          ],
        ),
      ),
    );
  }


  void _confirmDelete(BuildContext context, WidgetRef ref) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: flux.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FluxRadii.dialog)),
        title: Text('Delete "${skill.name}"?', style: textTheme.headlineMedium),
        content: Text(
          'Flux will no longer use this skill in chat.',
          style: textTheme.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: textTheme.bodyMedium?.copyWith(color: flux.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.read(skillProvider.notifier).removeSkill(skill.id);
              Navigator.pop(ctx);
            },
            child: Text('Delete',
                style: textTheme.bodyMedium?.copyWith(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  IconData _getIconForSkill(String id) {
    switch (id) {
      case 'web_search': return Icons.search_rounded;
      case 'memory': return Icons.psychology_rounded;
      case 'creations': return Icons.auto_awesome_mosaic_rounded;
      default: return Icons.extension_rounded;
    }
  }
}

class _ActionSheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionSheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    return BouncyTap(
      onTap: onTap,
      scaleDown: 0.97,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
              Text(label, style: textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}

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
      child: Icon(icon, size: 20, color: flux.textPrimary),
    );
  }
}
