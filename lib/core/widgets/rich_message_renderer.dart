import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/flux_theme.dart';
import '../../core/widgets/flux_animations.dart';

// Pre-compiled regex patterns for performance (library-private top-level)
final _thinkRegex = RegExp(r'<think>(.*?)</think>', dotAll: true);
final _inlineRegex = RegExp(r'(\*\*(.*?)\*\*)|(`(.*?)`)|(\$(.*?)\$)');
final _separatorCheck = RegExp(r'^[\s\-:]+$');

class RichMessageRenderer extends StatelessWidget {
  final String text;
  final bool isUser;

  const RichMessageRenderer({
    super.key,
    required this.text,
    required this.isUser,
  });

  static final Map<int, List<MessageSegment>> _parseCache = {};
  static const int _maxCacheEntries = 20;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flux = theme.extension<FluxColorsExtension>()!;

    final segments = _getOrParseSegments(text.trim());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: segments.map((s) => _buildSegment(context, s, flux)).toList(),
    );
  }

  List<MessageSegment> _getOrParseSegments(String text) {
    final hash = text.hashCode;
    final cached = _parseCache[hash];
    if (cached != null) return cached;
    final segments = _parseSegments(text);
    if (_parseCache.length >= _maxCacheEntries) {
      _parseCache.remove(_parseCache.keys.first);
    }
    _parseCache[hash] = segments;
    return segments;
  }

  Widget _buildSegment(BuildContext context, MessageSegment segment, FluxColorsExtension flux) {
    if (segment is ThinkSegment) {
      return _ThinkBlock(content: segment.content, flux: flux);
    }
    if (segment is TableSegment) {
      return _TableBlock(rows: segment.rows, flux: flux);
    }
    if (segment is HeaderSegment) {
      return _HeaderBlock(text: segment.text, level: segment.level, flux: flux);
    }
    if (segment is MathSegment) {
      return _MathBlock(text: segment.text, flux: flux);
    }
    if (segment is TextSegment) {
      return _RichTextBlock(text: segment.text, flux: flux, isUser: isUser);
    }
    return const SizedBox.shrink();
  }

  List<MessageSegment> _parseSegments(String text) {
    final segments = <MessageSegment>[];

    int lastEnd = 0;

    for (final match in _thinkRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        final sub = text.substring(lastEnd, match.start).trim();
        if (sub.isNotEmpty) {
          segments.addAll(_parseBlocks(sub));
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
        segments.addAll(_parseBlocks(sub));
      }
    }

    return segments;
  }

  List<MessageSegment> _parseBlocks(String text) {
    final segments = <MessageSegment>[];
    final lines = text.split('\n');
    int i = 0;

    while (i < lines.length) {
      final String rawLine = lines[i];
      final String trimmedLine = rawLine.trim();

      if (trimmedLine.startsWith('#### ')) {
        segments.add(HeaderSegment(text: trimmedLine.substring(5).trim(), level: 4));
        i++;
      } else if (trimmedLine.startsWith('### ')) {
        segments.add(HeaderSegment(text: trimmedLine.substring(4).trim(), level: 3));
        i++;
      }
      else if (trimmedLine.startsWith('\$\$')) {
        final mathLines = <String>[];
        if (trimmedLine.length > 2 && trimmedLine.endsWith('\$\$')) {
           segments.add(MathSegment(text: trimmedLine.substring(2, trimmedLine.length - 2).trim()));
           i++;
        } else {
          i++;
          while (i < lines.length && !lines[i].trim().startsWith('\$\$')) {
            mathLines.add(lines[i]);
            i++;
          }
          if (mathLines.isNotEmpty) {
            segments.add(MathSegment(text: mathLines.join('\n').trim()));
          }
          if (i < lines.length) i++;
        }
      }
      else if (_isTableRow(rawLine)) {
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
      }
      else {
        final textLines = <String>[];
        while (i < lines.length) {
          final l = lines[i];
          final tl = l.trim();
          if (_isTableRow(l) || tl.startsWith('###') || tl.startsWith('\$\$')) {
            break;
          }
          textLines.add(l);
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

class HeaderSegment extends MessageSegment {
  final String text;
  final int level;
  HeaderSegment({required this.text, required this.level});
}

class MathSegment extends MessageSegment {
  final String text;
  MathSegment({required this.text});
}

class _HeaderBlock extends StatelessWidget {
  final String text;
  final int level;
  final FluxColorsExtension flux;

  const _HeaderBlock({required this.text, required this.level, required this.flux});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    
    final style = level == 3 
        ? textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2)
        : textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700);

    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Text(text, style: style),
    );
  }
}

class _MathBlock extends StatelessWidget {
  final String text;
  final FluxColorsExtension flux;

  const _MathBlock({required this.text, required this.flux});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: flux.textPrimary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: flux.border, width: 0.5),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          text,
          style: GoogleFonts.firaCode(
            fontSize: 14,
            color: flux.textPrimary,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

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
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: isUser ? Colors.white : flux.textPrimary,
        height: 1.55,
      ),
    );
  }

  List<InlineSpan> _parseSpans(String text, FluxColorsExtension flux) {
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in _inlineRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }

      if (match.group(1) != null) {
        spans.add(TextSpan(
          text: match.group(2),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ));
      } else if (match.group(3) != null) {
        spans.add(TextSpan(
          text: match.group(4),
          style: GoogleFonts.firaCode(
            backgroundColor: flux.textPrimary.withValues(alpha: 0.07),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: flux.textPrimary,
          ),
        ));
      } else if (match.group(5) != null) {
        spans.add(TextSpan(
          text: match.group(6),
          style: GoogleFonts.firaCode(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            fontStyle: FontStyle.italic,
            color: flux.textPrimary,
          ),
        ));
      }
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return spans;
  }
}

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
    final bgColor = widget.flux.textSecondary.withValues(alpha: 0.06);
    final borderColor = widget.flux.border;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: FluxDurations.fast,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BouncyTap(
                onTap: () => setState(() => _expanded = !_expanded),
                scaleDown: 0.98,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      AnimatedRotation(
                        turns: _expanded ? 0.25 : 0,
                        duration: FluxDurations.normal,
                        curve: const Cubic(0.34, 1.56, 0.64, 1),
                        child: Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: widget.flux.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
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
              AnimatedSize(
                duration: FluxDurations.normal,
                curve: const Cubic(0.34, 1.56, 0.64, 1),
                alignment: Alignment.topCenter,
                child: _expanded
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
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

class _TableBlock extends StatelessWidget {
  final List<String> rows;
  final FluxColorsExtension flux;

  const _TableBlock({required this.rows, required this.flux});

  @override
  Widget build(BuildContext context) {
    final parsedRows = rows.map((r) => _parseRow(r)).toList();
    if (parsedRows.isEmpty) return const SizedBox.shrink();

    final separatorIndex = parsedRows.indexWhere((cells) {
      return cells.every((c) => _separatorCheck.hasMatch(c));
    });

    final headerRows = separatorIndex > 0 ? parsedRows.sublist(0, separatorIndex) : <List<String>>[];
    final bodyRows = separatorIndex >= 0
        ? parsedRows.sublist(separatorIndex + 1)
        : parsedRows;

    final allRows = [...headerRows, ...bodyRows];
    if (allRows.isEmpty) return const SizedBox.shrink();

    final columnCount = allRows.map((r) => r.length).reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: flux.border, width: 0.5),
            borderRadius: BorderRadius.circular(14),
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
                        ? flux.textPrimary.withValues(alpha: 0.05)
                        : (rowIndex % 2 == 0 ? flux.surface : null),
                  ),
                  children: List.generate(columnCount, (colIndex) {
                    final cellText = colIndex < cells.length ? cells[colIndex] : '';
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Text(
                        cellText,
                        style: GoogleFonts.instrumentSans(
                          fontSize: 13,
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
