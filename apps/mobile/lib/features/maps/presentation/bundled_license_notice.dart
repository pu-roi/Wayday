import 'package:flutter/material.dart';
import '../../../app/theme.dart';

/// Display-only normalization; the bundled upstream notice stays untouched.
String formatBundledNotice(String source) {
  final paragraphs = <String>[];
  final lines = <String>[];
  void flush() {
    if (lines.isEmpty) return;
    paragraphs.add(lines.join(' '));
    lines.clear();
  }

  for (final raw in source.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty || RegExp(r'^-{3,}$').hasMatch(line)) {
      flush();
      continue;
    }
    if (RegExp(r'^#{1,6}\s').hasMatch(line)) {
      flush();
      paragraphs.add(line.replaceFirst(RegExp(r'^#{1,6}\s+'), ''));
    } else if (RegExp(r'^[A-Z][A-Z &0-9.()-]+$').hasMatch(line) &&
        !line.endsWith(',') &&
        line.length < 32) {
      flush();
      paragraphs.add(line);
    } else {
      lines.add(line);
    }
  }
  flush();
  return paragraphs.join('\n\n');
}

class BundledLicenseNotice extends StatefulWidget {
  const BundledLicenseNotice({
    required this.title,
    required this.asset,
    super.key,
  });
  final String title;
  final String asset;

  @override
  State<BundledLicenseNotice> createState() => _BundledLicenseNoticeState();
}

class _BundledLicenseNoticeState extends State<BundledLicenseNotice>
    with AutomaticKeepAliveClientMixin {
  Future<String>? _notice;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notice ??= _load();
  }

  Future<String> _load() async => formatBundledNotice(
    await DefaultAssetBundle.of(context).loadString(widget.asset),
  );

  @override
  void didUpdateWidget(covariant BundledLicenseNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.asset != oldWidget.asset) _notice = _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ExpansionTile(
      key: PageStorageKey(widget.asset),
      maintainState: true,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(top: 8, bottom: 16),
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text(widget.title, style: context.type.bodyMedium),
      children: [
        FutureBuilder<String>(
          future: _notice,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Align(
                alignment: Alignment.centerLeft,
                child: Text('Loading license…'),
              );
            }
            if (snapshot.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('This license could not load.'),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => setState(() {
                        _notice = _load();
                      }),
                      child: const Text('Retry loading license'),
                    ),
                  ),
                ],
              );
            }
            return Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                snapshot.data!,
                key: PageStorageKey('${widget.asset}-text'),
                style: context.type.bodyMedium,
              ),
            );
          },
        ),
      ],
    );
  }
}
