import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Retrieval metadata stays in the separate source cards, not answer prose.
String cleanAnswerText(String text) => text
    .replaceAll(RegExp(r'[ \t]*\[(?:Source|Chunk)\s+[^\]\r\n]*\]', caseSensitive: false), '')
    .replaceAll(RegExp(r'[ \t]*\[\d+\]\((?:#source-|source:)[^)]*\)'), '')
    .replaceAll(RegExp(r'[ \t]*\[(?:S(?:o(?:u(?:r(?:c(?:e)?)?)?)?)?|C(?:h(?:u(?:n(?:k)?)?)?)?)(?:\s+[^\]\r\n]*)?$', caseSensitive: false), '');

/// Never collapse whitespace: indentation and line breaks are Markdown syntax.
String prepareMarkdown(String text, {bool streaming = false}) {
  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (!streaming) return normalized;
  String? fence;
  for (final line in normalized.split('\n')) {
    final match = RegExp(r'^ {0,3}(`{3,}|~{3,})').firstMatch(line);
    if (match == null) continue;
    final marker = match.group(1)!;
    if (fence == null) {
      fence = marker;
    } else if (marker[0] == fence[0] && marker.length >= fence.length) {
      fence = null;
    }
  }
  return fence == null ? normalized : '$normalized\n$fence\n';
}

class AnswerMarkdown extends StatelessWidget {
  final String text;
  final bool streaming;
  final void Function(String, String?, String)? onTapLink;
  const AnswerMarkdown(this.text, {super.key, this.streaming = false, this.onTapLink});

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: prepareMarkdown(text, streaming: streaming),
      selectable: true,
      softLineBreak: true,
      onTapLink: onTapLink,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(fontSize: 14.5, height: 1.7, color: Color(0xFF0F172A)),
        h1: const TextStyle(fontSize: 20, height: 1.4, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        h2: const TextStyle(fontSize: 17, height: 1.4, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        h3: const TextStyle(fontSize: 15.5, height: 1.4, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        h4: const TextStyle(fontSize: 14.5, height: 1.4, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
        blockSpacing: 14,
        listIndent: 24,
        listBullet: const TextStyle(fontSize: 14.5, color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
        code: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, color: Color(0xFF0F172A)),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        codeblockPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        tableColumnWidth: const IntrinsicColumnWidth(),
        tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        tableBorder: TableBorder.all(color: const Color(0xFFE2E8F0)),
        tableHead: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
        tableBody: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
        blockquote: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
        blockquoteDecoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
          border: Border(left: BorderSide(color: Color(0xFF2563EB), width: 3.5)),
        ),
        blockquotePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        a: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
      ),
    );
  }
}
