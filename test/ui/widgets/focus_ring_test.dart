import 'package:duanju_app/ui/app_scope.dart';
import 'package:duanju_app/ui/widgets/focus_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  testWidgets('television focus outline slides between elements', (
    tester,
  ) async {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );
    final first = FocusNode();
    final second = FocusNode();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
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
                      FocusRing(
                        radius: 999,
                        child: TextButton(
                          focusNode: second,
                          onPressed: () {},
                          child: const Text('下'),
                        ),
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
    final motion = find
        .descendant(
          of: find.byType(FocusOutlineMotion),
          matching: find.byType(CustomPaint),
        )
        .last;

    first.requestFocus();
    await tester.pumpAndSettle();
    expect(tester.renderObject(motion), paintsNothing);

    second.requestFocus();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
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
}
