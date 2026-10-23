import 'package:duanju_app/ui/app_scope.dart';
import 'package:duanju_app/ui/widgets/focus_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

Future<Finder> _pumpButtons(
  WidgetTester tester, {
  required FocusNode first,
  required FocusNode second,
  required FocusNode plain,
}) async {
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: AppScope(
        repository: FakeRepository(),
        television: true,
        child: FocusOutlineMotion(
          child: FocusOutlineLayer(
            child: Material(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 200,
                  children: [
                    FocusRing(
                      radius: 999,
                      child: TextButton(
                        focusNode: first,
                        onPressed: () {},
                        child: const Text('上'),
                      ),
                    ),
                    Row(
                      spacing: 40,
                      children: [
                        FocusRing(
                          radius: 999,
                          child: TextButton(
                            focusNode: second,
                            onPressed: () {},
                            child: const Text('下'),
                          ),
                        ),
                        TextButton(
                          focusNode: plain,
                          onPressed: () {},
                          child: const Text('无外框'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return find
      .descendant(
        of: find.byType(FocusOutlineMotion),
        matching: find.byType(CustomPaint),
      )
      .last;
}

Future<void> _startSliding(
  WidgetTester tester,
  FocusNode first,
  FocusNode second,
) async {
  first.requestFocus();
  await tester.pumpAndSettle();
  second.requestFocus();
  await tester.pump();
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 40));
}

void main() {
  late FocusNode first;
  late FocusNode second;
  late FocusNode plain;
  setUp(() {
    first = FocusNode();
    second = FocusNode();
    plain = FocusNode();
  });
  tearDown(() {
    first.dispose();
    second.dispose();
    plain.dispose();
  });

  testWidgets('television focus outline slides between elements', (
    tester,
  ) async {
    final motion = await _pumpButtons(
      tester,
      first: first,
      second: second,
      plain: plain,
    );
    expect(tester.renderObject(motion), paintsNothing);

    await _startSliding(tester, first, second);
    RRect? drawn;
    expect(
      tester.renderObject(motion),
      paints..something((method, arguments) {
        if (method != #drawRRect) return false;
        drawn = arguments.first as RRect;
        return true;
      }),
    );
    expect(
      drawn!.center.dy,
      inExclusiveRange(
        tester.getCenter(find.text('上')).dy,
        tester.getCenter(find.text('下')).dy,
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.renderObject(motion), paintsNothing);
  });

  testWidgets('a slide cut short by an element without outline is erased', (
    tester,
  ) async {
    final motion = await _pumpButtons(
      tester,
      first: first,
      second: second,
      plain: plain,
    );
    await _startSliding(tester, first, second);
    expect(tester.renderObject(motion), paints..rrect());

    var lastRepaintClears = false;
    tester
        .widget<CustomPaint>(motion)
        .painter!
        .addListener(
          () => lastRepaintClears = paintsNothing.matches(
            tester.renderObject(motion),
            {},
          ),
        );
    plain.requestFocus();
    await tester.pumpAndSettle();
    expect(lastRepaintClears, isTrue);
  });
}
