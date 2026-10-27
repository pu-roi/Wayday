import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/core/widgets/selection_controls.dart';

const _preview = Key('selection-preview');
const _options = [
  SelectionOption(value: 'one', label: 'First option'),
  SelectionOption(value: 'two', label: 'Second option'),
  SelectionOption(value: 'three', label: 'Third option'),
];

class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final _trigger = FocusNode();
  String _inline = 'one';
  String _sheet = 'one';

  @override
  void dispose() {
    _trigger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const TextField(
            key: Key('draft-text'),
            decoration: InputDecoration(labelText: 'Draft text'),
          ),
          const SizedBox(height: 16),
          SelectionRadioGroup<String>(
            label: 'Example choices',
            options: _options,
            selectedValue: _inline,
            onChanged: (value) => setState(() => _inline = value),
          ),
          TextButton(
            key: const Key('sheet-trigger'),
            focusNode: _trigger,
            onPressed: () async {
              final value = await chooseSingleChoice<String>(
                context,
                title: 'Choose an example',
                options: _options,
                selectedValue: _sheet,
                returnFocusNode: _trigger,
              );
              if (value != null && mounted) setState(() => _sheet = value);
            },
            child: Text('Sheet value: $_sheet'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _launch(WidgetTester tester, {double scale = 1}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _preview,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const _Harness(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('sheet-trigger')),
    160,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.byKey(const Key('sheet-trigger')));
  await tester.pumpAndSettle();
}

Finder _sheetText(String label) =>
    find.descendant(of: find.byType(BottomSheet), matching: find.text(label));

void main() {
  testWidgets('radio rows expose the current choice and change it', (
    tester,
  ) async {
    await _launch(tester);
    final rows = find.byType(RadioListTile<String>);
    expect(tester.widget<RadioListTile<String>>(rows.first).selected, isTrue);
    await tester.tap(find.text('Second option'));
    await tester.pump();
    expect(tester.widget<RadioListTile<String>>(rows.at(1)).selected, isTrue);
    expect(tester.widget<RadioListTile<String>>(rows.first).selected, isFalse);
  });

  testWidgets(
    'sheet changes stay pending until Done and cancel preserves value',
    (tester) async {
      await _launch(tester);
      await _open(tester);
      expect(_sheetText('Choose an example'), findsOneWidget);
      await tester.tap(_sheetText('Second option'));
      await tester.pump();
      expect(find.text('Sheet value: one'), findsOneWidget);
      await tester.tap(_sheetText('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Sheet value: one'), findsOneWidget);
      await _open(tester);
      final rows = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(RadioListTile<String>),
      );
      expect(tester.widget<RadioListTile<String>>(rows.first).selected, isTrue);
      await tester.tap(_sheetText('Third option'));
      await tester.tap(_sheetText('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Sheet value: three'), findsOneWidget);
    },
  );

  testWidgets('Back, barrier, and swipe cancel pending selection', (
    tester,
  ) async {
    await _launch(tester);
    for (final cancel in ['back', 'barrier', 'swipe']) {
      await _open(tester);
      await tester.tap(_sheetText('Second option'));
      await tester.pump();
      switch (cancel) {
        case 'back':
          await tester.binding.handlePopRoute();
        case 'barrier':
          await tester.tapAt(const Offset(10, 10));
        case 'swipe':
          await tester.drag(find.byType(BottomSheet), const Offset(0, 800));
      }
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Sheet value: one'), findsOneWidget);
    }
  });

  testWidgets(
    'sheet preserves text and restores focus without opening keyboard',
    (tester) async {
      await _launch(tester);
      await tester.enterText(
        find.byKey(const Key('draft-text')),
        'Keep my draft',
      );
      expect(tester.testTextInput.isVisible, isTrue);
      await _open(tester);
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(_sheetText('Cancel'));
      await tester.pumpAndSettle();
      final trigger = tester.widget<TextButton>(
        find.byKey(const Key('sheet-trigger')),
      );
      expect(trigger.focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.text('Keep my draft'), findsOneWidget);
    },
  );

  testWidgets('keyboard selection stays in the sheet until confirmed', (
    tester,
  ) async {
    await _launch(tester);
    await _open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(_sheetText('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Sheet value: two'), findsOneWidget);
  });

  testWidgets(
    'small screens and large text keep choices and actions reachable',
    (tester) async {
      await _launch(tester, scale: 2);
      tester.view.physicalSize = const Size(320, 560);
      await tester.pumpAndSettle();
      await _open(tester);
      await tester.ensureVisible(_sheetText('Third option'));
      await tester.tap(_sheetText('Third option'));
      await tester.ensureVisible(_sheetText('Done'));
      await tester.tap(_sheetText('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Sheet value: three'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced motion removes the sheet transition', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _launch(tester);
    await _open(tester);
    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.animationController!.duration, Duration.zero);
    expect(sheet.animationController!.reverseDuration, Duration.zero);
  });

  testWidgets('synthetic selection component preview', (tester) async {
    if (Platform.environment['WAYDAY_CAPTURE'] == '1') {
      await (FontLoader(
        'Figtree',
      )..addFont(rootBundle.load('assets/fonts/Figtree.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
    await _launch(tester);
    await _open(tester);
    if (Platform.environment['WAYDAY_CAPTURE'] != '1') return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_preview),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('../../.impeccable/review')
        ..createSync(recursive: true);
      File(
        '${directory.path}/selection-controls.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
