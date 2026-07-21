import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/providers/skill_provider.dart';
import '../../core/theme/flux_theme.dart';
import '../../core/widgets/flux_widgets.dart';
import '../../core/widgets/flux_animations.dart';

/// Skills — monochrome redesign.
///
/// Shares the app-wide [FluxStickerChip] / [FluxSectionLabel] and the
/// route-aware [FluxPageReveal] entrance so it stays visually and motion-wise
/// consistent with the models, settings and you pages.
class SkillsScreen extends ConsumerWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skills = ref.watch(skillProvider);
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    final items = <Widget>[];
    var revealIndex = 2; // 0 = back button, 1 = title
    items.add(FluxRevealItem(
      index: revealIndex++,
      child: const FluxSectionLabel('Your Skills'),
    ));
    items.add(const SizedBox(height: 12));
    for (var i = 0; i < skills.length; i++) {
      if (i > 0) items.add(const SizedBox(height: 16));
      items.add(FluxRevealItem(
        index: revealIndex++,
        child: _SkillTile(skill: skills[i]),
      ));
    }
    items.add(const SizedBox(height: 16));
    items.add(FluxRevealItem(
      index: revealIndex++,
      child: Padding(
        padding: const EdgeInsets.only(left: 6, top: 4),
        child: Text(
          'Tap to toggle. Long-press a custom skill to remove it.',
          style: textTheme.bodySmall?.copyWith(color: flux.textSecondary),
        ),
      ),
    ));

    return Scaffold(
      backgroundColor: flux.background,
      body: FluxPageReveal(
        child: Stack(
          children: [
            Positioned(
              left: 20,
              top: topPadding + 48,
              child: FluxRevealItem(
                index: 0,
                slideOffset: 10,
                child: FluxBackButton(onTap: () => context.pop()),
              ),
            ),
            Positioned(
              left: 20,
              top: topPadding + 100,
              child: const FluxRevealItem(
                index: 1,
                slideOffset: 12,
                child: FluxTitle(title: "Skills"),
              ),
            ),
            Positioned.fill(
              top: topPadding + 150,
              left: 20,
              right: 20,
              child: ListView(
                padding: EdgeInsets.only(bottom: bottomSafe + 100),
                physics: const BouncingScrollPhysics(),
                children: items,
              ),
            ),

            // Create / Import Skill FAB
            Positioned(
              right: 24,
              bottom: 40 + bottomSafe,
              child: FluxRevealItem(
                index: revealIndex++,
                slideOffset: 24,
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
            ),
          ],
        ),
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
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(FluxRadii.sheet)),
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FluxRadii.dialog)),
        title: const Text("Create New Skill"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration:
                  const InputDecoration(hintText: "Skill Name (e.g. Weather)"),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                  hintText: "Description (How to use it)"),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                ref.read(skillProvider.notifier).addSkill(
                      Skill(
                        id: nameController.text
                            .toLowerCase()
                            .replaceAll(' ', '_'),
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
      String name =
          file.name.replaceAll(RegExp(r'\.md$', caseSensitive: false), '');
      final headingMatch =
          RegExp(r'^#\s+(.+)$', multiLine: true).firstMatch(text);
      if (headingMatch != null) {
        name = headingMatch.group(1)!.trim();
      }

      final id = name
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(FluxRadii.snackBar)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    }
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
            FluxStickerChip(icon: _getIconForSkill(skill.id)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    skill.name,
                    style: textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    skill.description,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            CupertinoSwitch(
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FluxRadii.dialog)),
        title: Text('Delete "${skill.name}"?', style: textTheme.headlineMedium),
        content: Text(
          'Flux will no longer use this skill in chat.',
          style: textTheme.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style:
                    textTheme.bodyMedium?.copyWith(color: flux.textSecondary)),
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
      case 'web_search':
        return Icons.search_rounded;
      case 'memory':
        return Icons.psychology_rounded;
      case 'creations':
        return Icons.auto_awesome_mosaic_rounded;
      default:
        return Icons.extension_rounded;
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
              FluxStickerChip(icon: icon),
              const SizedBox(width: 14),
              Text(label, style: textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}
