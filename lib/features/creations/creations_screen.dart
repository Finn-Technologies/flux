import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/providers/download_provider.dart';
import '../../core/theme/flux_theme.dart';
import '../../core/widgets/flux_widgets.dart';
import '../../core/widgets/flux_animations.dart';
import '../../core/constants/responsive.dart';
import '../../l10n/app_localizations.dart';

// ============================================================================
// MODEL
// ============================================================================
class Creation {
  final String id;
  final String title;
  final String html;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Map<String, dynamic>> messages;
  final bool isPinned;
  final String? pinnedIconPath;
  final String? pinnedName;

  Creation({
    required this.id,
    required this.title,
    required this.html,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
    this.isPinned = false,
    this.pinnedIconPath,
    this.pinnedName,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'html': html,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'messages': messages,
    'isPinned': isPinned,
    'pinnedIconPath': pinnedIconPath,
    'pinnedName': pinnedName,
  };

  factory Creation.fromJson(Map<String, dynamic> json) => Creation(
    id: json['id'] as String,
    title: json['title'] as String,
    html: json['html'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    messages: (json['messages'] as List<dynamic>?)
            ?.map((m) => Map<String, dynamic>.from(m as Map))
            .toList() ??
        [],
    isPinned: json['isPinned'] as bool? ?? false,
    pinnedIconPath: json['pinnedIconPath'] as String?,
    pinnedName: json['pinnedName'] as String?,
  );

  Creation copyWith({
    String? id,
    String? title,
    String? html,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Map<String, dynamic>>? messages,
    bool? isPinned,
    String? pinnedIconPath,
    String? pinnedName,
  }) =>
      Creation(
        id: id ?? this.id,
        title: title ?? this.title,
        html: html ?? this.html,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        messages: messages ?? this.messages,
        isPinned: isPinned ?? this.isPinned,
        pinnedIconPath: pinnedIconPath ?? this.pinnedIconPath,
        pinnedName: pinnedName ?? this.pinnedName,
      );
}

// ============================================================================
// PROVIDER
// ============================================================================
final creationsProvider = StateNotifierProvider<CreationsNotifier, List<Creation>>((ref) => CreationsNotifier());

class CreationsNotifier extends StateNotifier<List<Creation>> {
  CreationsNotifier() : super([]) {
    _loadFromHive();
  }

  void _loadFromHive() {
    final box = Hive.box('creations');
    final items = box.values
        .map((v) => Creation.fromJson(Map<String, dynamic>.from(v)))
        .toList();
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = items;
  }

  Future<void> saveCreation(Creation creation) async {
    state = [
      creation,
      ...state.where((c) => c.id != creation.id),
    ];
    final box = Hive.box('creations');
    await box.put(creation.id, creation.toJson());
  }

  Future<void> deleteCreation(String id) async {
    state = state.where((c) => c.id != id).toList();
    final box = Hive.box('creations');
    await box.delete(id);
  }

  Future<void> togglePin(String id, {bool? isPinned, String? pinnedName, String? pinnedIconPath}) async {
    state = state.map((c) {
      if (c.id == id) {
        final updated = c.copyWith(
          isPinned: isPinned ?? !c.isPinned,
          pinnedName: pinnedName,
          pinnedIconPath: pinnedIconPath,
        );
        final box = Hive.box('creations');
        box.put(updated.id, updated.toJson());
        return updated;
      }
      return c;
    }).toList();
  }
}

// ============================================================================
// MAIN COLLECTION SCREEN
// ============================================================================
class CreationsScreen extends ConsumerStatefulWidget {
  const CreationsScreen({super.key});

  @override
  ConsumerState<CreationsScreen> createState() => _CreationsScreenState();
}

class _CreationsScreenState extends ConsumerState<CreationsScreen> {
  final _scrollController = ScrollController();
  double _topFadeOpacity = 0.0;
  double _bottomFadeOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onCreationsScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkBottomFade();
    });
  }

  void _onCreationsScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final top = offset > 0 ? 1.0 : 0.0;
    final bottom = maxExtent > 0 && offset < maxExtent ? 1.0 : 0.0;
    if (top != _topFadeOpacity || bottom != _bottomFadeOpacity) {
      setState(() {
        _topFadeOpacity = top;
        _bottomFadeOpacity = bottom;
      });
    }
  }

  void _checkBottomFade() {
    if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
      setState(() => _bottomFadeOpacity = 1.0);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onCreationsScroll);
    _scrollController.dispose();
    super.dispose();
  }
  void _showCreationOptions(GlobalKey cardKey, Creation creation) {
    final renderBox = cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !mounted) return;

    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final offset = renderBox.localToGlobal(Offset.zero);
    final itemSize = renderBox.size;

    if (isIOS) {
      showCupertinoModalPopup<String>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: Text(
            creation.title.isNotEmpty
                ? creation.title
                : AppLocalizations.of(context)!.untitledCreation,
            style: textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                _showCreationDeleteConfirm(context, creation);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.delete, color: CupertinoColors.destructiveRed, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    AppLocalizations.of(context)!.delete,
                    style: textTheme.bodyLarge?.copyWith(color: CupertinoColors.destructiveRed),
                  ),
                ],
              ),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        items: [
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                const Icon(Icons.delete_outline, color: Colors.red, size: 22),
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
        if (value == 'delete') {
          _showCreationDeleteConfirm(context, creation);
        }
      });
    }
  }

  void _showCreationDeleteConfirm(BuildContext context, Creation creation) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(
            '${AppLocalizations.of(context)!.delete} ${AppLocalizations.of(context)!.creations}?',
            style: textTheme.headlineMedium,
          ),
          content: Text(
            '"${creation.title}" ${AppLocalizations.of(context)!.delete}',
            style: textTheme.bodySmall,
          ),
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
                ref.read(creationsProvider.notifier).deleteCreation(creation.id);
                Navigator.pop(ctx);
                HapticFeedback.lightImpact();
              },
              child: Text(
                AppLocalizations.of(context)!.delete,
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
          title: Text(
            '${AppLocalizations.of(context)!.delete} ${AppLocalizations.of(context)!.creations}?',
            style: textTheme.headlineMedium,
          ),
          content: Text(
            '"${creation.title}" ${AppLocalizations.of(context)!.delete}',
            style: textTheme.bodySmall,
          ),
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
                ref.read(creationsProvider.notifier).deleteCreation(creation.id);
                Navigator.pop(ctx);
                HapticFeedback.lightImpact();
              },
              child: Text(
                AppLocalizations.of(context)!.delete,
                style: textTheme.bodyMedium?.copyWith(color: Colors.red, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _showPreview(BuildContext context, Creation creation) {
    if (creation.html.isEmpty) return;
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    
    final webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(flux.background)
      ..loadHtmlString(creation.html);

    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (ctx) => _CreationPreviewScreen(
          webViewController: webViewController,
          onClose: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final creations = ref.watch(creationsProvider);
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final topPadding = mediaPadding(context).top;
    final brightness = Theme.of(context).brightness;
    final isDesktop = context.isDesktop;
    final bottomPad = isDesktop ? 24.0 : MediaQuery.of(context).padding.bottom + 84.0;

    final downloaded = ref.watch(downloadProvider);
    final creativeModels = downloaded.where(
      (m) => m.id == 'flux-lite-qwen-3.5-0.8b' && m.downloaded,
    );
    final creativeModel = creativeModels.isNotEmpty ? creativeModels.first : null;

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
              child: FluxTitle(title: AppLocalizations.of(context)!.creations),
            ),

            Positioned(
              left: 20,
              right: 20,
              top: topPadding + 110,
              bottom: bottomPad,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (creativeModel == null)
                    _buildCreativePrompt(context, flux),

                  if (creativeModel == null)
                    const SizedBox(height: 20),

                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: creations.isEmpty
                              ? _buildEmptyState(context, flux)
                              : _buildGrid(context, creations, flux),
                        ),
                        if (_topFadeOpacity > 0)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 30,
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      flux.background,
                                      flux.background,
                                      flux.background.withValues(alpha: 0),
                                    ],
                                    stops: const [0.0, 0.3, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_bottomFadeOpacity > 0)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 30,
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      flux.background,
                                      flux.background,
                                      flux.background.withValues(alpha: 0),
                                    ],
                                    stops: const [0.0, 0.3, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (creativeModel != null)
              Positioned(
                right: 20,
                bottom: bottomPad + 22,
                child: Semantics(
                  label: AppLocalizations.of(context)!.newCreation,
                  button: true,
                  child: Tooltip(
                    message: AppLocalizations.of(context)!.newCreation,
                    child: BouncyTap(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/creations/editor');
                      },
                      scaleDown: 0.85,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: flux.textPrimary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: flux.textPrimary.withValues(alpha: 0.2),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(Icons.add, color: flux.background, size: 28),
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

  EdgeInsets mediaPadding(BuildContext context) => MediaQuery.of(context).padding;

  Widget _buildCreativePrompt(BuildContext context, FluxColorsExtension flux) {
    final textTheme = Theme.of(context).textTheme;

    return BouncyFadeSlide(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: flux.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: flux.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: flux.textPrimary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.memory,
                    color: flux.textPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Flux Lite Required',
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Install Flux Lite to start creating.',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            BouncyTap(
              onTap: () => context.push('/settings/models'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: flux.textPrimary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    'Install Flux Lite',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: flux.background,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '533 MB',
                style: textTheme.labelLarge?.copyWith(
                  color: flux.textSecondary.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, FluxColorsExtension flux) {
    return FluxEmptyState(
      icon: Icons.extension_outlined,
      title: AppLocalizations.of(context)!.noCreations,
      subtitle: AppLocalizations.of(context)!.buildFirstApp,
    );
  }

  Widget _buildGrid(BuildContext context, List<Creation> creations, FluxColorsExtension flux) {
    final width = MediaQuery.of(context).size.width;
    final columns = width > 900 ? 4 : (width > 600 ? 3 : (width > 400 ? 2 : 1));

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: columns > 2 ? 2.8 : (columns > 1 ? 3.2 : 4.0),
      ),
      itemCount: creations.length,
      cacheExtent: 500,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final creation = creations[index];
        final cardKey = GlobalKey();
        return StaggeredEntrance(
          index: index,
          delayStep: const Duration(milliseconds: 30),
          child: _CreationCard(
            key: cardKey,
            creation: creation,
            flux: flux,
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/creations/editor', extra: creation.id);
            },
            onLongPress: () => _showCreationOptions(cardKey, creation),
            onPlayPreview: () => _showPreview(context, creation),
          ),
        );
      },
    );
  }
}

// ============================================================================
// CREATION CARD
// ============================================================================
class _CreationCard extends StatelessWidget {
  final Creation creation;
  final FluxColorsExtension flux;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onPlayPreview;

  const _CreationCard({
    super.key,
    required this.creation,
    required this.flux,
    required this.onTap,
    required this.onLongPress,
    required this.onPlayPreview,
  });

  String _formatDate(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return AppLocalizations.of(context)!.justNow;
    if (diff.inHours < 1) return AppLocalizations.of(context)!.minutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return AppLocalizations.of(context)!.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return AppLocalizations.of(context)!.daysAgo(diff.inDays);
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return BouncyTap(
      onTap: onTap,
      onLongPress: onLongPress,
      scaleDown: 0.97,
      child: Container(
        decoration: BoxDecoration(
          color: flux.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: flux.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: flux.textPrimary.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Container(
              width: 60,
              height: double.infinity,
              color: flux.textPrimary.withValues(alpha: 0.03),
              child: Center(
                child: Icon(
                  Icons.code_rounded,
                  size: 22,
                  color: flux.textSecondary.withValues(alpha: 0.3),
                ),
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      creation.title.isNotEmpty ? creation.title : AppLocalizations.of(context)!.untitledCreation,
                      style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(context, creation.updatedAt),
                      style: textTheme.labelLarge?.copyWith(
                        color: flux.textSecondary.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (creation.html.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: BouncyTap(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onPlayPreview();
                  },
                  scaleDown: 0.85,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: flux.textPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.play_arrow_rounded, color: flux.background, size: 18),
                  ),
                ),
              )
            else if (creation.isPinned)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.push_pin_rounded,
                  size: 14,
                  color: flux.textSecondary.withValues(alpha: 0.3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CREATION PREVIEW SCREEN
// ============================================================================
class _CreationPreviewScreen extends StatelessWidget {
  final WebViewController webViewController;
  final VoidCallback onClose;
  const _CreationPreviewScreen({required this.webViewController, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: flux.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  BouncyTap(
                    onTap: onClose,
                    scaleDown: 0.85,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: flux.border),
                      ),
                      child: Icon(Icons.close, size: 18, color: flux.textPrimary),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context)!.preview,
                        style: textTheme.titleLarge,
                      ),
                    ),
                  ),
                  const SizedBox(width: 36),
                ],
              ),
            ),
            Divider(color: flux.border, height: 1, thickness: 0.5),
            Expanded(
              child: RepaintBoundary(
                child: WebViewWidget(controller: webViewController),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
