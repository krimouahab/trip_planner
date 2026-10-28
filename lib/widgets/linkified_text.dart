import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

final _linkPattern = RegExp(
  r'((?:https?:\/\/|www\.)[^\s<>"]+|[\w.+-]+@[\w-]+\.[\w.-]+)',
  caseSensitive: false,
);

/// Opens [raw] (a URL, "www." address or e-mail) in the right app.
Future<void> openLink(BuildContext context, String raw) async {
  final Uri uri;
  if (raw.contains('@') && !raw.contains('://')) {
    uri = Uri(scheme: 'mailto', path: raw);
  } else if (raw.toLowerCase().startsWith('www.')) {
    uri = Uri.parse('https://$raw');
  } else {
    uri = Uri.parse(raw);
  }
  final messenger = ScaffoldMessenger.maybeOf(context);
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) {
    messenger?.showSnackBar(SnackBar(content: Text('Could not open $raw')));
  }
}

/// Text in which every URL / e-mail address is underlined and tappable.
class LinkifiedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;

  const LinkifiedText(this.text, {super.key, this.style, this.maxLines});

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final base = widget.style ?? DefaultTextStyle.of(context).style;
    final linkStyle = base.copyWith(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: Theme.of(context).colorScheme.primary,
    );

    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _linkPattern.allMatches(widget.text)) {
      var link = m.group(0)!;
      // Don't swallow sentence punctuation that follows a link.
      final trailing = RegExp(r'[.,;:!?)\]]+$').firstMatch(link);
      if (trailing != null) link = link.substring(0, trailing.start);
      if (m.start > last) {
        spans.add(TextSpan(text: widget.text.substring(last, m.start)));
      }
      final r = TapGestureRecognizer()..onTap = () => openLink(context, link);
      _recognizers.add(r);
      spans.add(
        TextSpan(
          text: link,
          style: linkStyle,
          recognizer: r,
          mouseCursor: SystemMouseCursors.click,
        ),
      );
      last = m.start + link.length;
    }
    if (last < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(last)));
    }

    return Text.rich(
      TextSpan(style: base, children: spans),
      maxLines: widget.maxLines,
      overflow: widget.maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}
