import 'package:flutter/material.dart';
import '../../app/theme.dart';

Future<String?> choosePlace(
  BuildContext context, {
  required String title,
  required String initial,
}) => Navigator.of(context, rootNavigator: true).push<String>(
  MaterialPageRoute(
    builder: (_) => PlacePicker(title: title, initial: initial),
  ),
);

class PlacePicker extends StatefulWidget {
  const PlacePicker({required this.title, required this.initial, super.key});
  final String title;
  final String initial;
  @override
  State<PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<PlacePicker> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const MapPreview(),
            const SizedBox(height: 20),
            Text('A place for your plans.', style: context.type.titleLarge),
            const SizedBox(height: 8),
            Text(
              'This is a map preview. Search and pin placement are coming later; enter a place name for now.',
              style: context.type.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Form(
              key: _form,
              child: TextFormField(
                key: const Key('place-name'),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Place name',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a place name.'
                    : null,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                if (_form.currentState?.validate() ?? false) {
                  Navigator.pop(context, _name.text.trim());
                }
              },
              child: const Text('Use this place'),
            ),
          ],
        ),
      ),
    ),
  );
}

class MapPreview extends StatelessWidget {
  const MapPreview({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Illustrative map placeholder, not a live map',
    image: true,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 1.35,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _MapPainter(
                  ground: context.colors.surfaceContainerHighest,
                  block: context.wayday.mist.withValues(alpha: .55),
                  road: context.colors.surface,
                ),
              ),
            ),
            Center(
              child: Icon(
                Icons.location_on_rounded,
                size: 52,
                color: context.wayday.link,
              ),
            ),
            Positioned(
              left: 16,
              bottom: 16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(
                    'Map preview',
                    style: context.type.labelMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MapPainter extends CustomPainter {
  _MapPainter({required this.ground, required this.block, required this.road});
  final Color ground;
  final Color block;
  final Color road;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(ground, BlendMode.src);
    final paint = Paint()..color = block;
    for (final rect in [
      const Rect.fromLTWH(.05, .06, .25, .28),
      const Rect.fromLTWH(.36, .03, .24, .23),
      const Rect.fromLTWH(.70, .07, .25, .33),
      const Rect.fromLTWH(.08, .57, .24, .36),
      const Rect.fromLTWH(.41, .65, .22, .28),
      const Rect.fromLTWH(.73, .59, .23, .36),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            rect.left * size.width,
            rect.top * size.height,
            rect.width * size.width,
            rect.height * size.height,
          ),
          const Radius.circular(12),
        ),
        paint,
      );
    }
    final roads = Paint()
      ..color = road
      ..strokeWidth = 13
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(-10, size.height * .45)
        ..cubicTo(
          size.width * .25,
          size.height * .38,
          size.width * .55,
          size.height * .62,
          size.width + 10,
          size.height * .47,
        ),
      roads,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .33, -10)
        ..lineTo(size.width * .35, size.height * .48)
        ..lineTo(size.width * .37, size.height + 10),
      roads,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .65, -10)
        ..lineTo(size.width * .67, size.height + 10),
      roads,
    );
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) =>
      old.ground != ground || old.block != block || old.road != road;
}
