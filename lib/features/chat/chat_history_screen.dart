import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/chat_session.dart';
import '../../core/theme/flux_theme.dart';
import '../../core/providers/model_provider.dart';
import '../../core/widgets/flux_animations.dart';
import '../../l10n/app_localizations.dart';
import 'chat_screen.dart';

class ChatHistoryScreen extends ConsumerStatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  ConsumerState<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends ConsumerState<ChatHistoryScreen> {
  String? _currentConversationId;

  void _startNewChat() {
    setState(() => _currentConversationId = null);
    ref.read(chatMessagesProvider.notifier).clear();
    context.go('/home');
  }

  void _selectConversation(ChatSession conv) {
    setState(() => _currentConversationId = conv.id);
    if (conv.modelId != null) {
      ref.read(selectedModelIdProvider.notifier).select(conv.modelId);
    }
    ref.read(chatMessagesProvider.notifier).setMessages(conv.messages);
    context.go('/home');
  }

  void _showRenameDialog(BuildContext context, ChatSession conv) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final textController = TextEditingController(text: conv.title);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: flux.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FluxRadii.dialog)),
        title: Text(
          AppLocalizations.of(context)!.renameChat,
          style: textTheme.headlineMedium,
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.chatName,
            hintStyle: textTheme.bodyLarge?.copyWith(color: flux.textSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: BorderSide(color: flux.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: BorderSide(color: flux.textPrimary, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(ctx);
            },
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: textTheme.bodyMedium?.copyWith(color: flux.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              final newTitle = textController.text.trim();
              if (newTitle.isNotEmpty) {
                final updatedConv = ChatSession(
                  id: conv.id,
                  title: newTitle,
                  messages: conv.messages,
                  updatedAt: conv.updatedAt,
                  modelId: conv.modelId,
                );
                ref
                    .read(conversationsProvider.notifier)
                    .updateConversation(updatedConv);
              }
              Navigator.pop(ctx);
            },
            child: Text(
              AppLocalizations.of(context)!.save,
              style: textTheme.bodyMedium?.copyWith(
                color: flux.textPrimary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, ChatSession conv) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: flux.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FluxRadii.dialog)),
        title: Text(
          '${AppLocalizations.of(context)!.delete} "${conv.title}"?',
          style: textTheme.headlineMedium,
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(ctx);
            },
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: textTheme.bodyMedium?.copyWith(color: flux.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              ref
                  .read(conversationsProvider.notifier)
                  .deleteConversation(conv.id);
              Navigator.pop(ctx);
            },
            child: Text(
              AppLocalizations.of(context)!.delete,
              style: textTheme.bodyMedium?.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showContextMenu(BuildContext context, RenderBox renderBox, ChatSession conv) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final offset = renderBox.localToGlobal(Offset.zero);
    final itemSize = renderBox.size;

    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    if (isIOS) {
      showCupertinoModalPopup<String>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: Text(
            conv.title,
            style: textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx, 'rename');
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.pencil,
                    color: flux.textPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    AppLocalizations.of(context)!.rename,
                    style: textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(ctx, 'delete');
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    CupertinoIcons.delete,
                    color: CupertinoColors.destructiveRed,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    AppLocalizations.of(context)!.delete,
                    style: textTheme.bodyLarge?.copyWith(
                      color: CupertinoColors.destructiveRed,
                    ),
                  ),
                ],
              ),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ).then((value) {
        if (!mounted) return;
        if (value == 'rename') {
          _showRenameDialog(this.context, conv);
        } else if (value == 'delete') {
          _showDeleteConfirmation(this.context, conv);
        }
      });
    } else {
      final position = RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + itemSize.height + 10,
        offset.dx + itemSize.width,
        offset.dy + itemSize.height + 10,
      );
      showMenu<String>(
        context: context,
        position: position,
        color: flux.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FluxRadii.menu),
        ),
        items: [
          PopupMenuItem<String>(
            value: 'rename',
            child: Row(
              children: [
                Icon(
                  Icons.edit_outlined,
                  color: flux.textPrimary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context)!.rename,
                  style: textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context)!.delete,
                  style: textTheme.bodyLarge?.copyWith(color: Colors.red),
                ),
              ],
            ),
          ),
        ],
      ).then((value) {
        if (!mounted) return;
        if (value == 'rename') {
          _showRenameDialog(this.context, conv);
        } else if (value == 'delete') {
          _showDeleteConfirmation(this.context, conv);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final conversations = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: flux.background,
      body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 15),
                child: Row(
                  children: [
                    Text(
                      'Flux',
                      style: textTheme.displaySmall?.copyWith(
                        fontSize: 20,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const Spacer(),
                    _SidebarHeaderButton(
                      svgAsset: 'assets/images/settings.svg',
                      tooltip: AppLocalizations.of(context)!.settings,
                      onTap: () {
                        context.push('/settings');
                      },
                    ),
                    const SizedBox(width: 10),
                    _SidebarHeaderButton(
                      svgAsset: 'assets/images/compose.svg',
                      tooltip: AppLocalizations.of(context)!.newChat,
                      onTap: _startNewChat,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 0, 25, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    runSpacing: 15,
                  children: [
                  BouncyFadeSlide(
                    delay: const Duration(milliseconds: 40),
                    slideOffset: 14,
                    child: _SidebarAction(
                      svgAsset: 'assets/images/canvas.svg',
                      label: AppLocalizations.of(context)!.creations,
                      onTap: () {
                        context.push('/creations');
                      },
                    ),
                  ),
                  BouncyFadeSlide(
                    delay: const Duration(milliseconds: 100),
                    slideOffset: 14,
                    child: _SidebarAction(
                      svgAsset: 'assets/images/relieved-02.svg',
                      label: 'You',
                      onTap: () {
                        context.push('/you');
                      },
                    ),
                  ),
                  BouncyFadeSlide(
                    delay: const Duration(milliseconds: 160),
                    slideOffset: 14,
                    child: _SidebarAction(
                      svgAsset: 'assets/images/book-open-text.svg',
                      label: 'Skills',
                      onTap: () {
                        context.push('/skills');
                      },
                    ),
                  ),
                  BouncyFadeSlide(
                    delay: const Duration(milliseconds: 220),
                    slideOffset: 14,
                    child: _SidebarAction(
                      svgAsset: 'assets/images/chip.svg',
                      label: AppLocalizations.of(context)!.models,
                      onTap: () {
                        context.push('/settings/models');
                      },
                    ),
                  ),
                ],
                  ),
                ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 30, 25, 12),
              child: Text(
                AppLocalizations.of(context)!.chatHistory,
                style: textTheme.displaySmall?.copyWith(
                  fontSize: 18,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            Expanded(
              child: conversations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/sad_face.png',
                            width: 40,
                            height: 40,
                            color: flux.textSecondary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No history; start chatting',
                            style: textTheme.labelLarge?.copyWith(
                              color: flux.textSecondary,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: conversations.length,
                      cacheExtent: 150,
                      addAutomaticKeepAlives: false,
                      addRepaintBoundaries: true,
                      itemBuilder: (context, index) {
                        final conv = conversations[index];
                        final isSelected = _currentConversationId == conv.id;
                        final itemKey = GlobalKey();
                        return GestureDetector(
                          onTap: () => _selectConversation(conv),
                          onLongPress: () {
                            HapticFeedback.heavyImpact();
                            final renderBox = itemKey.currentContext
                                    ?.findRenderObject() as RenderBox?;
                            if (renderBox == null) return;
                            _showContextMenu(context, renderBox, conv);
                          },
                          child: Container(
                            key: itemKey,
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? flux.textPrimary.withValues(alpha: 0.06)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              conv.title,
                              style: textTheme.bodySmall?.copyWith(
                                fontSize: 14,
                                color: flux.textPrimary,
                                decoration: TextDecoration.none,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
}
}

class _SidebarHeaderButton extends StatelessWidget {
  final String svgAsset;
  final String tooltip;
  final VoidCallback onTap;

  const _SidebarHeaderButton({
    required this.svgAsset,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: SvgPicture.asset(
              svgAsset,
              width: 30,
              height: 30,
              colorFilter:
                  ColorFilter.mode(flux.textPrimary, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarAction extends StatelessWidget {
  final String svgAsset;
  final String label;
  final VoidCallback onTap;

  const _SidebarAction({
    required this.svgAsset,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: flux.surface,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Opacity(
                  opacity: 0.7,
                  child: SvgPicture.asset(
                    svgAsset,
                    width: 26,
                    height: 26,
                    colorFilter:
                        ColorFilter.mode(flux.textPrimary, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelLarge?.copyWith(
                color: flux.textPrimary,
                fontSize: 12,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
