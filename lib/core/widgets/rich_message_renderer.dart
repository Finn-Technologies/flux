import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/flux_theme.dart';
import '../../core/widgets/animated_tap_card.dart';

/// A rich message renderer that supports:
/// - Bold text via **markdown**
/// - Markdown tables
/// - Collapsible think blocks (\<think>...\</think>)
class RichMessageRenderer extends StatelessWidget {
  final String text;
  final bool isUser;

  const RichMessageRenderer({
    super.key,
    required this.text,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flux = theme.extension<FluxColorsExtension>()!;

    final segments = _parseSegments(text.trim());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: segments.map((s) => _buildSegment(context, s, flux)).toList(),
    );
  }

  Widget _buildSegment(BuildContext context, MessageSegment segment, FluxColorsExtension flux) {
    if (segment is ThinkSegment) {
      return _ThinkBlock(content: segment.content, flux: flux);
    }
    if (segment is TableSegment) {
      return _TableBlock(rows: segment.rows, flux: flux);
    }
    if (segment is TextSegment) {
      return _RichTextBlock(text: segment.text, flux: flux, isUser: isUser);
    }
    return const SizedBox.shrink();
  }

  List<MessageSegment> _parseSegments(String text) {
    final segments = <MessageSegment>[];
    final thinkRegex = RegExp(r'<think>(.*?)</think>', dotAll: true);
    int lastEnd = 0;

    for (final match in thinkRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        final sub = text.substring(lastEnd, match.start).trim();
        if (sub.isNotEmpty) {
          segments.addAll(_parseTablesAndText(sub));
        }
      }
      final content = match.group(1)!.trim();
      if (content.isNotEmpty) {
        segments.add(ThinkSegment(content: content));
      }
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      final sub = text.substring(lastEnd).trim();
      if (sub.isNotEmpty) {
        segments.addAll(_parseTablesAndText(sub));
      }
    }

    return segments;
  }

  List<MessageSegment> _parseTablesAndText(String text) {
    final segments = <MessageSegment>[];
    final lines = text.split('\n');
    int i = 0;

    while (i < lines.length) {
      if (_isTableRow(lines[i])) {
        final tableLines = <String>[];
        while (i < lines.length && _isTableRow(lines[i])) {
          tableLines.add(lines[i]);
          i++;
        }
        if (tableLines.length >= 2) {
          segments.add(TableSegment(rows: tableLines));
        } else {
          segments.add(TextSegment(text: tableLines.join('\n')));
        }
      } else {
        final textLines = <String>[];
        while (i < lines.length && !_isTableRow(lines[i])) {
          textLines.add(lines[i]);
          i++;
        }
        if (textLines.isNotEmpty) {
          final joined = textLines.join('\n').trim();
          if (joined.isNotEmpty) {
            segments.add(TextSegment(text: joined));
          }
        }
      }
    }

    return segments;
  }

  bool _isTableRow(String line) {
    final trimmed = line.trim();
    return trimmed.startsWith('|') && trimmed.endsWith('|');
  }
}

abstract class MessageSegment {}

class TextSegment extends MessageSegment {
  final String text;
  TextSegment({required this.text});
}

class ThinkSegment extends MessageSegment {
  final String content;
  ThinkSegment({required this.content});
}

class TableSegment extends MessageSegment {
  final List<String> rows;
  TableSegment({required this.rows});
}

/// Renders inline bold text via **markdown**
class _RichTextBlock extends StatelessWidget {
  final String text;
  final FluxColorsExtension flux;
  final bool isUser;

  const _RichTextBlock({
    required this.text,
    required this.flux,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    final spans = _parseSpans(text, flux);
    return Text.rich(
      TextSpan(children: spans),
      style: GoogleFonts.instrumentSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: isUser ? Colors.white : flux.textPrimary,
        height: 1.5,
      ),
    );
  }

  List<InlineSpan> _parseSpans(String text, FluxColorsExtension flux) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return spans;
  }
}

/// Collapsible think block with smooth animation
class _ThinkBlock extends StatefulWidget {
  final String content;
  final FluxColorsExtension flux;

  const _ThinkBlock({required this.content, required this.flux});

  @override
  State<_ThinkBlock> createState() => _ThinkBlockState();
}

class _ThinkBlockState extends State<_ThinkBlock>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.flux.textSecondary.withValues(alpha: 0.08);
    final borderColor = widget.flux.border;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with tap to expand/collapse
              AnimatedTapCard(
                onTap: () => setState(() => _expanded = !_expanded),
                scaleDown: 0.98,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      AnimatedRotation(
                        turns: _expanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        child: Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: widget.flux.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _expanded ? 'Hide reasoning' : 'Thinking...',
                        style: GoogleFonts.instrumentSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: widget.flux.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Expandable content
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: _expanded
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: _RichTextBlock(
                          text: widget.content,
                          flux: widget.flux,
                          isUser: false,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders a markdown table with aligned columns
class _TableBlock extends StatelessWidget {
  final List<String> rows;
  final FluxColorsExtension flux;

  const _TableBlock({required this.rows, required this.flux});

  @override
  Widget build(BuildContext context) {
    final parsedRows = rows.map((r) => _parseRow(r)).toList();
    if (parsedRows.isEmpty) return const SizedBox.shrink();

    // Detect and remove the separator row (contains only dashes and pipes)
    final separatorIndex = parsedRows.indexWhere((cells) {
      return cells.every((c) => RegExp(r'^[\s\-:]+$').hasMatch(c));
    });

    final headerRows = separatorIndex > 0 ? parsedRows.sublist(0, separatorIndex) : <List<String>>[];
    final bodyRows = separatorIndex >= 0
        ? parsedRows.sublist(separatorIndex + 1)
        : parsedRows;

    final allRows = [...headerRows, ...bodyRows];
    if (allRows.isEmpty) return const SizedBox.shrink();

    final columnCount = allRows.map((r) => r.length).reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: flux.border, width: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder(
                horizontalInside: BorderSide(color: flux.border, width: 0.5),
                verticalInside: BorderSide(color: flux.border, width: 0.5),
              ),
              children: allRows.asMap().entries.map((entry) {
                final rowIndex = entry.key;
                final cells = entry.value;
                final isHeader = rowIndex < headerRows.length;

                return TableRow(
                  decoration: BoxDecoration(
                    color: isHeader
                        ? flux.textPrimary.withValues(alpha: 0.06)
                        : (rowIndex % 2 == 0 ? flux.surface : null),
                  ),
                  children: List.generate(columnCount, (colIndex) {
                    final cellText = colIndex < cells.length ? cells[colIndex] : '';
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text(
                        cellText,
                        style: GoogleFonts.instrumentSans(
                          fontSize: 14,
                          fontWeight: isHeader ? FontWeight.w600 : FontWeight.w400,
                          color: flux.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    );
                  }),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  List<String> _parseRow(String row) {
    final trimmed = row.trim();
    var content = trimmed;
    if (content.startsWith('|')) content = content.substring(1);
    if (content.endsWith('|')) content = content.substring(0, content.length - 1);
    return content.split('|').map((c) => c.trim()).toList();
  }
}
