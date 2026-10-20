import 'dart:async';

import 'package:duanju_app/cover_loader.dart';
import 'package:duanju_app/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

class _CoverRepository extends FixtureRepository {
  final started = <String>[];
  final pending = <String, Completer<String>>{};

  @override
  Future<String> cover(Drama drama, {bool force = false}) {
    started.add(drama.id);
    return (pending[drama.id] = Completer<String>()).future;
  }
}

Drama _drama(int index) =>
    Drama(id: 'cover:$index', source: 'hongguo', title: '封面 $index');

void main() {
  testWidgets('covers wait briefly, stay within limit and drain newest first', (
    tester,
  ) async {
    final repository = _CoverRepository();
    final requests = <int, CoverRequest>{
      for (var index = 0; index < 8; index++)
        index: CoverLoader.request(repository, _drama(index)),
    };
    await tester.pump(const Duration(milliseconds: 100));
    expect(repository.started, isEmpty);
    requests[7]!.cancel();
    await tester.pump(const Duration(milliseconds: 60));
    expect(repository.started, [for (var i = 0; i < 6; i++) 'cover:$i']);

    for (final index in [8, 9]) {
      requests[index] = CoverLoader.request(repository, _drama(index));
    }
    await tester.pump(const Duration(milliseconds: 160));
    expect(repository.started, hasLength(6));

    repository.pending['cover:0']!.complete('/covers/0.jpg');
    expect(await requests[0]!.file, '/covers/0.jpg');
    await tester.pump();
    expect(repository.started.last, 'cover:9');

    requests[8]!.cancel();
    repository.pending['cover:1']!.completeError(StateError('失败'));
    await expectLater(requests[1]!.file, throwsStateError);
    await tester.pump();
    expect(repository.started.last, 'cover:6');

    repository.pending['cover:2']!.complete('/covers/2.jpg');
    await tester.pump();
    expect(repository.started, hasLength(8));
    expect(repository.started, isNot(contains('cover:7')));
    expect(repository.started, isNot(contains('cover:8')));
    for (final completer in repository.pending.values) {
      if (!completer.isCompleted) completer.complete('');
    }
    await tester.pump();
  });
}
