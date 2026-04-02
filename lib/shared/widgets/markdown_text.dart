import 'package:flutter/material.dart';

// ── Public API ────────────────────────────────────────────────────────────────

/// Renders a markdown string as rich [Text.rich] spans.
///
/// Supported syntax:
///   `**bold**`          → bold
///   `*italic*`          → italic
///   `_italic_`          → italic
///   `` `code` ``        → monospace
///   Lines `- item`      → bullet  `•  item`
///   Lines `N. item`     → numbered  `1.  item`
///   Lines `[… — …]`     → timestamp header (muted italic)
class MarkdownText extends StatelessWidget {
  const MarkdownText(
    this.data, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.bodySmall ?? const TextStyle();
    final spans = _parseMarkdown(data, base, context);
    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Formatting toolbar for markdown editing.
///
/// Place it directly above (or below) a [TextField] and pass the same
/// [TextEditingController]. Buttons wrap the current selection (or insert
/// syntax at the cursor) with the corresponding markdown tokens.
class MarkdownToolbar extends StatelessWidget {
  const MarkdownToolbar({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttons = Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        _ToolbarButton(
          label: 'B',
          tooltip: 'Bold (**text**)',
          bold: true,
          controller: controller,
          prefix: '**',
          suffix: '**',
        ),
        _ToolbarButton(
          label: 'I',
          tooltip: 'Italic (*text*)',
          italic: true,
          controller: controller,
          prefix: '*',
          suffix: '*',
        ),
        _ToolbarButton(
          label: '`',
          tooltip: 'Inline code',
          mono: true,
          controller: controller,
          prefix: '`',
          suffix: '`',
        ),
        _ToolbarButton(
          label: '• List',
          tooltip: 'Bullet list item (- item)',
          controller: controller,
          prefix: '- ',
          suffix: '',
          insertLinePrefix: true,
        ),
        _ToolbarButton(
          label: '1. List',
          tooltip: 'Numbered list item',
          controller: controller,
          prefix: '1. ',
          suffix: '',
          insertLinePrefix: true,
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: buttons,
    );
  }
}

// ── Private helpers ───────────────────────────────────────────────────────────

/// Parses [text] into a flat list of [InlineSpan]s.
List<InlineSpan> _parseMarkdown(
  String text,
  TextStyle base,
  BuildContext context,
) {
  final theme = Theme.of(context);
  final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.45);
  final codeColor = theme.colorScheme.primary;

  final spans = <InlineSpan>[];
  final lines = text.split('\n');

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];

    // Blank line → newline spacer
    if (line.isEmpty) {
      spans.add(const TextSpan(text: '\n'));
      continue;
    }

    // Timestamp header: line matching `[... — ...]`
    if (_kTimestampLine.hasMatch(line)) {
      spans.add(TextSpan(
        text: '$line\n',
        style: base.copyWith(
          fontStyle: FontStyle.italic,
          color: mutedColor,
          fontSize: (base.fontSize ?? 12) - 1,
        ),
      ));
      continue;
    }

    // Bullet: starts with `- `
    if (line.startsWith('- ')) {
      spans.add(TextSpan(text: '•  ', style: base));
      spans.addAll(_parseInline(line.substring(2), base, mutedColor, codeColor));
      spans.add(const TextSpan(text: '\n'));
      continue;
    }

    // Numbered list: starts with digit(s) + `. `
    final numMatch = _kNumberedLine.matchAsPrefix(line);
    if (numMatch != null) {
      spans.add(TextSpan(text: '${numMatch.group(1)}.  ', style: base));
      spans.addAll(
          _parseInline(line.substring(numMatch.end), base, mutedColor, codeColor));
      spans.add(const TextSpan(text: '\n'));
      continue;
    }

    // Normal line
    spans.addAll(_parseInline(line, base, mutedColor, codeColor));
    spans.add(const TextSpan(text: '\n'));
  }

  return spans;
}

/// Parses inline markdown tokens within a single line.
List<InlineSpan> _parseInline(
  String line,
  TextStyle base,
  Color mutedColor,
  Color codeColor,
) {
  final spans = <InlineSpan>[];
  var remaining = line;

  while (remaining.isNotEmpty) {
    // `` `code` ``
    final codeMatch = _kInlineCode.firstMatch(remaining);
    // `**bold**`
    final boldMatch = _kBold.firstMatch(remaining);
    // `*italic*` or `_italic_`
    final italicMatch = _kItalic.firstMatch(remaining);

    // Find the earliest match
    final matches = [
      if (codeMatch != null) (codeMatch, 'code'),
      if (boldMatch != null) (boldMatch, 'bold'),
      if (italicMatch != null) (italicMatch, 'italic'),
    ]..sort((a, b) => a.$1.start.compareTo(b.$1.start));

    if (matches.isEmpty) {
      spans.add(TextSpan(text: remaining, style: base));
      break;
    }

    final (match, kind) = matches.first;

    // Text before the match
    if (match.start > 0) {
      spans.add(TextSpan(text: remaining.substring(0, match.start), style: base));
    }

    // For italic, group(1) is *..* and group(2) is _.._
    final inner = (kind == 'italic')
        ? (match.group(1) ?? match.group(2) ?? '')
        : match.group(1)!;
    final TextStyle styled;
    switch (kind) {
      case 'bold':
        styled = base.copyWith(fontWeight: FontWeight.bold);
      case 'italic':
        styled = base.copyWith(fontStyle: FontStyle.italic);
      case 'code':
        styled = base.copyWith(
          fontFamily: 'monospace',
          color: codeColor,
          backgroundColor:
              codeColor.withValues(alpha: 0.08),
        );
      default:
        styled = base;
    }
    spans.add(TextSpan(text: inner, style: styled));
    remaining = remaining.substring(match.end);
  }

  return spans;
}

final _kTimestampLine = RegExp(r'^\[.+—.+\]$');
final _kNumberedLine = RegExp(r'^(\d+)\. ');
final _kBold = RegExp(r'\*\*(.+?)\*\*');
final _kItalic = RegExp(r'(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)|_(.+?)_');
final _kInlineCode = RegExp(r'`(.+?)`');

// ── Toolbar button ────────────────────────────────────────────────────────────

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.label,
    required this.tooltip,
    required this.controller,
    required this.prefix,
    required this.suffix,
    this.bold = false,
    this.italic = false,
    this.mono = false,
    this.insertLinePrefix = false,
  });

  final String label;
  final String tooltip;
  final TextEditingController controller;
  final String prefix;
  final String suffix;
  final bool bold;
  final bool italic;
  final bool mono;

  /// If true, inserts [prefix] at the start of the current line (no suffix).
  final bool insertLinePrefix;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _apply(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              fontFamily: mono ? 'monospace' : null,
            ),
          ),
        ),
      ),
    );
  }

  void _apply() {
    final text = controller.text;
    final sel = controller.selection;
    if (!sel.isValid) return;

    if (insertLinePrefix) {
      // Find the start of the line that contains the cursor/selection start
      final lineStart = text.lastIndexOf('\n', sel.start - 1) + 1;
      final newText = text.substring(0, lineStart) +
          prefix +
          text.substring(lineStart);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: sel.baseOffset + prefix.length,
        ),
      );
    } else if (sel.isCollapsed) {
      // No selection: insert tokens and place cursor between them
      final newText =
          text.substring(0, sel.start) + prefix + suffix + text.substring(sel.end);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: sel.start + prefix.length),
      );
    } else {
      // Wrap selection
      final selected = sel.textInside(text);
      final newText = text.substring(0, sel.start) +
          prefix +
          selected +
          suffix +
          text.substring(sel.end);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: sel.start,
          extentOffset: sel.start + prefix.length + selected.length + suffix.length,
        ),
      );
    }
  }
}

