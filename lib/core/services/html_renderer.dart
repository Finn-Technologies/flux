import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class HtmlRenderer {
  static Future<Uint8List?> renderToImage(
    String html, {
    required BuildContext context,
    Size size = const Size(400, 300),
  }) async {
    final boundary = GlobalKey();

    final widget = MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SizedBox(
          width: size.width,
          height: size.height,
          child: RepaintBoundary(
            key: boundary,
            child: Container(
              width: size.width,
              height: size.height,
              color: Colors.white,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _HtmlPreviewPainter(html: html, size: size),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: -size.width,
        top: -size.height,
        child: SizedBox(width: size.width, height: size.height, child: widget),
      ),
    );

    Overlay.of(context).insert(overlayEntry);

    await Future.delayed(const Duration(milliseconds: 200));

    Uint8List? imageBytes;
    try {
      final renderObject = boundary.currentContext?.findRenderObject();
      if (renderObject is RenderRepaintBoundary && renderObject.hasSize) {
        final image = await renderObject.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        imageBytes = byteData?.buffer.asUint8List();
      }
    } catch (_) {}

    try {
      overlayEntry.remove();
    } catch (_) {}

    return imageBytes;
  }
}

class _HtmlPreviewPainter extends CustomPainter {
  final String html;
  final Size size;

  _HtmlPreviewPainter({required this.html, required this.size});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFF5F5F5);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final titleStyle = const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Color(0xFF333333),
    );

    final subtitleStyle = const TextStyle(
      fontSize: 12,
      color: Color(0xFF999999),
    );

    final title = _extractTitle();
    final tp = TextPainter(
      text: TextSpan(text: title, style: titleStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 40);
    tp.paint(canvas, Offset(20, size.height / 2 - 20));

    final subtitle = '${html.length} chars of HTML';
    final stp = TextPainter(
      text: TextSpan(text: subtitle, style: subtitleStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 40);
    stp.paint(canvas, Offset(20, size.height / 2 + 10));
  }

  String _extractTitle() {
    final titleRegex = RegExp(r'<title[^>]*>([^<]*)</title>', caseSensitive: false);
    final match = titleRegex.firstMatch(html);
    if (match != null) return match.group(1)?.trim() ?? 'Untitled';

    if (html.contains('<!doctype html>') || html.contains('<html')) {
      return 'HTML App';
    }
    return 'Creation';
  }

  @override
  bool shouldRepaint(covariant _HtmlPreviewPainter oldDelegate) => false;
}
