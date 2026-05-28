import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart' show getApplicationDocumentsDirectory;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:home_widget/home_widget.dart';
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
  final String type;
  final String? screenshotPath;

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
    this.type = 'playground',
    this.screenshotPath,
  });

  bool get isWidget => type == 'widget';

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
    'type': type,
    'screenshotPath': screenshotPath,
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
    type: json['type'] as String? ?? 'playground',
    screenshotPath: json['screenshotPath'] as String?,
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
    String? type,
    String? screenshotPath,
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
        type: type ?? this.type,
        screenshotPath: screenshotPath ?? this.screenshotPath,
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
  String _selectedTab = 'all';

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
              onPressed: () {
                Navigator.pop(ctx);
                _pinToHome(creation);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.pin, color: CupertinoColors.activeBlue, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Pin to Home Screen',
                    style: textTheme.bodyLarge?.copyWith(color: CupertinoColors.activeBlue),
                  ),
                ],
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                _exportCreationAsHtml(creation);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.doc_text, color: CupertinoColors.activeBlue, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Export as HTML',
                    style: textTheme.bodyLarge?.copyWith(color: CupertinoColors.activeBlue),
                  ),
                ],
              ),
            ),
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
              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w400),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FluxRadii.menu)),
        items: [
          PopupMenuItem<String>(
            value: 'pin',
            child: Row(
              children: [
                const Icon(Icons.pin_drop_outlined, color: CupertinoColors.activeBlue, size: 22),
                const SizedBox(width: 12),
                Text(
                  'Pin to Home Screen',
                  style: textTheme.bodyLarge?.copyWith(color: CupertinoColors.activeBlue),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'export',
            child: Row(
              children: [
                const Icon(Icons.file_download_outlined, color: CupertinoColors.activeBlue, size: 22),
                const SizedBox(width: 12),
                Text(
                  'Export as HTML',
                  style: textTheme.bodyLarge?.copyWith(color: CupertinoColors.activeBlue),
                ),
              ],
            ),
          ),
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
        } else if (value == 'export') {
          _exportCreationAsHtml(creation);
        } else if (value == 'pin') {
          _pinToHome(creation);
        }
      });
    }
  }

  Future<void> _pinToHome(Creation creation) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final htmlFile = File('${dir.path}/widget_creation_${creation.id}.html');
      await htmlFile.writeAsString(creation.html);

      final h = _hashString(creation.id);
      final c = _CreationStickerCard.palette[h % _CreationStickerCard.palette.length];
      final colorHex =
          '#${(c.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0')}';

      await HomeWidget.saveWidgetData<String>('creationId', creation.id);
      await HomeWidget.saveWidgetData<String>('creationTitle', creation.title);
      await HomeWidget.saveWidgetData<String>('creationColor', colorHex);
      await HomeWidget.saveWidgetData<String>('htmlFilePath', htmlFile.path);
      await HomeWidget.saveWidgetData<String>('updatedAt', creation.updatedAt.toIso8601String());
      await HomeWidget.saveWidgetData<String>('creationType', creation.type);

      if (creation.screenshotPath != null) {
        await HomeWidget.saveWidgetData<String>('screenshotPath', creation.screenshotPath);
      }

      // Also save iOS-compatible keys (home_widget's iOS WidgetKit extension reads these)
      await HomeWidget.saveWidgetData<String>('title', creation.title);
      await HomeWidget.saveWidgetData<String>('content', 'Flux Creation: ${creation.title}');

      await HomeWidget.updateWidget(
        name: 'FluxWidgetProvider',
        androidName: 'FluxWidgetProvider',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pinned to Home! Add the Flux widget to see it.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pin: $e')),
      );
    }
  }

  int _hashString(String s) {
    var h = 0;
    for (final code in s.codeUnits) {
      h = (h * 31 + code) & 0x7fffffff;
    }
    return h;
  }

  Future<void> _exportCreationAsHtml(Creation creation) async {
    if (creation.html.isEmpty) return;
    if (!mounted) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final sanitizedTitle = creation.title
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');
      final filename = sanitizedTitle.isNotEmpty
          ? '${sanitizedTitle}_${creation.updatedAt.millisecondsSinceEpoch}.html'
          : 'creation_${creation.updatedAt.millisecondsSinceEpoch}.html';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(creation.html);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported → $filename'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
                style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w400),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FluxRadii.dialog)),
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
              onPressed: () { HapticFeedback.lightImpact(); Navigator.pop(ctx); },
              child: Text(
                AppLocalizations.of(context)!.cancel,
                style: textTheme.bodyMedium?.copyWith(color: flux.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(creationsProvider.notifier).deleteCreation(creation.id);
                Navigator.pop(ctx);
              },
              child: Text(
                AppLocalizations.of(context)!.delete,
                style: textTheme.bodyMedium?.copyWith(color: Colors.red, fontWeight: FontWeight.w400),
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
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    final downloaded = ref.watch(downloadProvider);
    final creativeModels = downloaded.where((m) => m.downloaded);
    final creativeModel = creativeModels.isNotEmpty ? creativeModels.first : null;

    final filtered = _selectedTab == 'all'
        ? creations
        : creations.where((c) => c.type == _selectedTab).toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: flux.background,
        body: FluxDottedBackground(
          child: Stack(
            children: [
              Positioned(
                left: 20,
                top: topPadding + 48,
                child: FluxBackButton(onTap: () => context.pop()),
              ),
              Positioned(
                left: 20,
                top: topPadding + 100,
                child: FluxTitle(title: AppLocalizations.of(context)!.creations),
              ),
              Positioned.fill(
                left: 20,
                right: 20,
                top: topPadding + 150,
                bottom: bottomSafe,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTabBar(context, flux),
                    const SizedBox(height: 12),
                    if (creativeModel == null)
                      _buildCreativePrompt(context, flux),
                    if (creativeModel == null) const SizedBox(height: 20),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: filtered.isEmpty
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
            ],
          ),
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
          borderRadius: BorderRadius.circular(999),
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
                    borderRadius: BorderRadius.circular(999),
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
                        'Model Required',
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Download a model to start creating.',
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
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Center(
                  child: Text(
                      'Download a Model',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w400,
                      color: flux.background,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
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

  Widget _buildTabBar(BuildContext context, FluxColorsExtension flux) {
    final textTheme = Theme.of(context).textTheme;
    final tabs = [
      ('all', 'All'),
      ('playgrounds', 'Playgrounds'),
      ('widgets', 'Widgets'),
    ];
    return Row(
      children: tabs.map((tab) {
        final isSelected = _selectedTab == tab.$1;
        return GestureDetector(
          onTap: () => setState(() => _selectedTab = tab.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? flux.textPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? flux.textPrimary : flux.border,
                width: 1,
              ),
            ),
            child: Text(
              tab.$2,
              style: textTheme.bodySmall?.copyWith(
                color: isSelected ? flux.background : flux.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGrid(BuildContext context, List<Creation> creations, FluxColorsExtension flux) {
    final width = MediaQuery.of(context).size.width;
    final columns = width > 900 ? 5 : (width > 600 ? 4 : (width > 400 ? 3 : 2));

    final filtered = _selectedTab == 'all'
        ? creations
        : creations.where((c) => c.type == _selectedTab).toList();

    final bottomSafe = MediaQuery.of(context).padding.bottom;
    return GridView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(4, 8, 4, bottomSafe + 12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 14,
        mainAxisSpacing: 18,
        childAspectRatio: 0.78,
      ),
      itemCount: filtered.length,
      cacheExtent: 500,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final creation = filtered[index];
        final cardKey = GlobalKey();
        return StaggeredEntrance(
          index: index,
          delayStep: const Duration(milliseconds: 30),
          child: creation.isWidget
              ? _CreationWidgetCard(
                  key: cardKey,
                  creation: creation,
                  flux: flux,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/creations/app/${creation.id}');
                  },
                  onLongPress: () => _showCreationOptions(cardKey, creation),
                )
              : _CreationStickerCard(
                  key: cardKey,
                  creation: creation,
                  flux: flux,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/creations/app/${creation.id}');
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
// STICKER CARD — sticker-on-paper card with a centered chunky icon.
// Shape and color are deterministic from the creation id, so the same
// creation always renders the same sticker.
// ============================================================================
class _CreationStickerCard extends StatelessWidget {
  final Creation creation;
  final FluxColorsExtension flux;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onPlayPreview;

  const _CreationStickerCard({
    super.key,
    required this.creation,
    required this.flux,
    required this.onTap,
    required this.onLongPress,
    required this.onPlayPreview,
  });

  // Deterministic palette index from creation id — refreshed, slightly
  // more saturated, retro-pastel palette.
  static const palette = [
    Color(0xFFFF8FAB), // bubblegum pink
    Color(0xFF80ED99), // spring green
    Color(0xFF73DDFF), // electric sky
    Color(0xFFFFD166), // sunshine
    Color(0xFFE0AAFF), // orchid
    Color(0xFFFFA552), // tangerine
    Color(0xFF95E1D3), // turquoise
    Color(0xFFC1FF9B), // matcha
    Color(0xFFFF6B6B), // tomato
    Color(0xFFB388FF), // grape
  ];

  static const _icons = [
    Icons.rocket_launch_rounded,
    Icons.auto_awesome_rounded,
    Icons.bolt_rounded,
    Icons.palette_rounded,
    Icons.toys_rounded,
    Icons.science_rounded,
    Icons.music_note_rounded,
    Icons.smart_toy_rounded,
    Icons.celebration_rounded,
    Icons.diamond_rounded,
    Icons.local_florist_rounded,
    Icons.lightbulb_rounded,
  ];

  // Shape variants: circle, rounded square (squircle-like), hexagon-ish
  // (high-radius square), pill, diamond, and octagon.
  static const _shapeCount = 6;

  int _hash(String s) {
    var h = 0;
    for (final code in s.codeUnits) {
      h = (h * 31 + code) & 0x7fffffff;
    }
    return h;
  }

  ShapeBorder _shapeFor(int variant) {
    switch (variant) {
      case 0:
        return const CircleBorder();
      case 1:
        return ContinuousRectangleBorder(borderRadius: BorderRadius.circular(999));
      case 2:
        // Squircle-ish — rounded corners with a slight asymmetric bias.
        return const ContinuousRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(40),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(40),
          ),
        );
      case 3:
        // Pill shape
        return const ContinuousRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(36)),
        );
      case 4:
        // Diamond-ish with asymmetric corners
        return const ContinuousRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(36),
            bottomLeft: Radius.circular(36),
            bottomRight: Radius.circular(8),
          ),
        );
      case 5:
      default:
        // Octagon-ish with varying corner radii
        return const ContinuousRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(24),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final h = _hash(creation.id);
    final paletteColor = palette[h % palette.length];
    final iconData = _icons[(h ~/ 7) % _icons.length];
    final shape = _shapeFor(h % _shapeCount);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Sticker = colored face with a centered chunky icon. Title sits
    // beneath the sticker on the dotted paper, not inside the sticker.
    final sticker = BouncyTap(
      onTap: onTap,
      onLongPress: onLongPress,
      scaleDown: 0.94,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // White die-cut border + drop shadow.
                Container(
                  decoration: ShapeDecoration(
                    color: isDark ? const Color(0xFFEFEFEF) : Colors.white,
                    shape: shape,
                    shadows: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.45 : 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  margin: const EdgeInsets.all(4),
                ),
                // Colored face.
                Container(
                  margin: const EdgeInsets.all(10),
                  decoration: ShapeDecoration(
                    color: paletteColor,
                    shape: shape,
                  ),
                  child: Center(
                    // The icon is centered inside the sticker for a clear
                    // visual focal point. Pin badge overlays the top-right.
                    child: Icon(
                      iconData,
                      size: 44,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (creation.isPinned)
                  Positioned(
                    top: 10,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.push_pin_rounded,
                          size: 10, color: Colors.white),
                    ),
                  ),
                // Play button on bottom-right.
                if (creation.html.isNotEmpty)
                  Positioned(
                    right: 8,
                    bottom: 10,
                    child: BouncyTap(
                      onTap: onPlayPreview,
                      scaleDown: 0.85,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Title below the sticker on the paper background.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              creation.title.isNotEmpty
                  ? creation.title
                  : AppLocalizations.of(context)!.untitledCreation,
              style: textTheme.bodySmall?.copyWith(
                color: flux.textPrimary,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          Text(
            _formatDate(context, creation.updatedAt),
            style: textTheme.labelMedium?.copyWith(
              color: flux.textSecondary,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (context.isDesktop) {
      return FluxHoverScale(hoverScale: 1.04, child: sticker);
    }
    return sticker;
  }

  String _formatDate(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return AppLocalizations.of(context)!.justNow;
    if (diff.inHours < 1) {
      return AppLocalizations.of(context)!.minutesAgo(diff.inMinutes);
    }
    if (diff.inDays < 1) {
      return AppLocalizations.of(context)!.hoursAgo(diff.inHours);
    }
    if (diff.inDays < 7) {
      return AppLocalizations.of(context)!.daysAgo(diff.inDays);
    }
    return '${date.month}/${date.day}/${date.year}';
  }
}

// ============================================================================
// WIDGET CARD — shows screenshot preview for widget-type creations.
// ============================================================================
class _CreationWidgetCard extends StatelessWidget {
  final Creation creation;
  final FluxColorsExtension flux;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _CreationWidgetCard({
    super.key,
    required this.creation,
    required this.flux,
    required this.onTap,
    required this.onLongPress,
  });

  static const _palette = [
    Color(0xFFFF8FAB),
    Color(0xFF80ED99),
    Color(0xFF73DDFF),
    Color(0xFFFFD166),
    Color(0xFFE0AAFF),
    Color(0xFFFFA552),
    Color(0xFF95E1D3),
    Color(0xFFC1FF9B),
    Color(0xFFFF6B6B),
    Color(0xFFB388FF),
  ];

  int _hash(String s) {
    var h = 0;
    for (final code in s.codeUnits) {
      h = (h * 31 + code) & 0x7fffffff;
    }
    return h;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final h = _hash(creation.id);
    final fallbackColor = _palette[h % _palette.length];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final card = BouncyTap(
      onTap: onTap,
      onLongPress: onLongPress,
      scaleDown: 0.94,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // White border + shadow
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFFEFEFEF) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  margin: const EdgeInsets.all(4),
                ),
                // Screenshot image or fallback
                Container(
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: fallbackColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: creation.screenshotPath != null
                      ? Image.file(
                          File(creation.screenshotPath!),
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildFallbackIcon(fallbackColor),
                        )
                      : _buildFallbackIcon(fallbackColor),
                ),
                // Widget badge
                Positioned(
                  top: 10,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.widgets_rounded, size: 10, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'WIDGET',
                          style: textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (creation.isPinned)
                  Positioned(
                    top: 10,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.push_pin_rounded,
                          size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              creation.title.isNotEmpty
                  ? creation.title
                  : AppLocalizations.of(context)!.untitledCreation,
              style: textTheme.bodySmall?.copyWith(
                color: flux.textPrimary,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          Text(
            _formatDate(context, creation.updatedAt),
            style: textTheme.labelMedium?.copyWith(
              color: flux.textSecondary,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (context.isDesktop) {
      return FluxHoverScale(hoverScale: 1.04, child: card);
    }
    return card;
  }

  Widget _buildFallbackIcon(Color color) {
    return const Center(
      child: Icon(
        Icons.widgets_rounded,
        size: 44,
        color: Colors.black87,
      ),
    );
  }

  String _formatDate(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return AppLocalizations.of(context)!.justNow;
    if (diff.inHours < 1) {
      return AppLocalizations.of(context)!.minutesAgo(diff.inHours);
    }
    if (diff.inDays < 1) {
      return AppLocalizations.of(context)!.hoursAgo(diff.inHours);
    }
    if (diff.inDays < 7) {
      return AppLocalizations.of(context)!.daysAgo(diff.inDays);
    }
    return '${date.month}/${date.day}/${date.year}';
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
