import 'dart:ui';

import 'package:duanju_app/core_bridge.dart';
import 'package:duanju_app/local_store.dart';
import 'package:duanju_app/models.dart';
import 'package:duanju_app/playback_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

import 'support/fake_player.dart';
import 'support/fakes.dart';

class _PlaybackRepository extends FakeRepository {
  final resolved = <({int episode, int quality})>[];
  final released = <String>[];
  var fallbacks = 0;
  var resolveFailure = '';
  var _sessions = 0;

  PlaybackPlan _plan({int route = 0}) {
    _sessions++;
    return PlaybackPlan(
      url: 'https://media.test/$_sessions.m3u8',
      session: 'session-$_sessions',
      routeIndex: route,
      routeCount: 2,
      quality: 1080,
      qualities: const [1080, 720],
    );
  }

  @override
  Future<PlaybackPlan> resolve(
    Drama drama,
    Episode episode, {
    int quality = 0,
  }) async {
    resolved.add((episode: episode.number, quality: quality));
    if (resolveFailure.isNotEmpty) throw AppFailure(resolveFailure);
    return _plan();
  }

  @override
  Future<PlaybackPlan> fallback(PlaybackPlan current) async {
    fallbacks++;
    return _plan(route: current.routeIndex + 1);
  }

  @override
  Future<void> release(String session) async => released.add(session);
}

final _show = drama('show', title: '测试剧');

Future<(PlaybackSession, FakePlayer)> _open(
  _PlaybackRepository repository,
  LocalStore store, {
  int index = 0,
  double position = 0,
}) async {
  final player = FakePlayer();
  final session = PlaybackSession(
    repository: repository,
    store: store,
    detail: dramaDetail(_show, count: 3),
    player: player,
    index: index,
    position: position,
  );
  addTearDown(() {
    if (_closed.add(session)) session.dispose();
  });
  await pumpEventQueue();
  return (session, player);
}

final _closed = <PlaybackSession>{};

void _close(PlaybackSession session) {
  _closed.add(session);
  session.dispose();
}

Duration _seconds(num value) => Duration(milliseconds: (value * 1000).round());

void main() {
  test('opens the episode at the resume position and saves progress', () async {
    final repository = _PlaybackRepository();
    final store = await openStore();
    final (session, player) = await _open(
      repository,
      store,
      index: 1,
      position: 30,
    );

    expect(session.ready, isTrue);
    expect(session.episode.number, 2);
    expect(repository.resolved.single, (episode: 2, quality: 0));
    expect(player.opened.single.uri, 'https://media.test/1.m3u8');
    expect(player.opened.single.start, _seconds(30));
    expect(player.rates, [1.0]);
    expect(session.qualityLabel, '自动（1080P）');

    player.progress(_seconds(40), duration: _seconds(100));
    await session.saveProgress();
    final watch = store.watched(_show.id)!;
    expect(watch.episode, 2);
    expect(watch.position, 40);
    expect(watch.duration, 100);
  });

  test('a finished episode moves on to the next one', () async {
    final repository = _PlaybackRepository();
    final store = await openStore();
    final (session, player) = await _open(repository, store);

    player.progress(_seconds(99.5), duration: _seconds(100));
    player.finish();
    await pumpEventQueue();

    expect(session.index, 1);
    expect(session.ready, isTrue);
    expect(player.opened, hasLength(2));
    expect(player.opened.last.start, isNull);
    expect(repository.released, contains('session-1'));
    expect(store.watched(_show.id)!.episode, 1);
  });

  test('the last episode stops at its end instead of looping', () async {
    final repository = _PlaybackRepository();
    final store = await openStore();
    final (session, player) = await _open(repository, store, index: 2);

    player.progress(_seconds(99.5), duration: _seconds(100));
    player.finish();
    await pumpEventQueue();

    expect(session.index, 2);
    expect(player.opened, hasLength(1));
    expect(store.watched(_show.id)!.episode, 3);
  });

  test('a player error switches to the other route at the same spot', () async {
    final repository = _PlaybackRepository();
    final store = await openStore();
    final (session, player) = await _open(repository, store);

    player.progress(_seconds(20), duration: _seconds(100));
    player.fail('connection reset by https://media.test/1.m3u8?token=x');
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    await pumpEventQueue();

    expect(repository.fallbacks, 1);
    expect(repository.resolved, hasLength(1));
    expect(player.opened, hasLength(2));
    expect(player.opened.last.start, _seconds(20));
    expect(session.ready, isTrue);
    expect(repository.released, contains('session-1'));
  });

  test('a quality change is saved and reloads where it was', () async {
    final repository = _PlaybackRepository();
    final store = await openStore();
    final (session, player) = await _open(repository, store);

    player.progress(_seconds(15), duration: _seconds(100));
    await session.setQuality(720);

    expect(store.playbackPreferences.quality, 720);
    expect(repository.resolved.last, (episode: 1, quality: 720));
    expect(player.opened.last.start, _seconds(15));
    expect(session.qualityLabel, '720P');
  });

  test('speed changes are saved and applied unless boosting', () async {
    final repository = _PlaybackRepository();
    final store = await openStore();
    final (session, player) = await _open(repository, store);

    await session.setSpeed(1.5);
    expect(store.playbackPreferences.speed, 1.5);
    expect(player.rates.last, 1.5);

    session.beginBoost();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(session.boosting, isTrue);
    expect(player.rates.last, 2);
    expect(session.endBoost(), isTrue);
    await pumpEventQueue();
    expect(player.rates.last, 1.5);
    expect(session.endBoost(), isFalse);
  });

  test('a volume change while paused flushes audio before resuming', () async {
    final repository = _PlaybackRepository();
    final store = await openStore();
    final (session, player) = await _open(repository, store);

    player.progress(_seconds(12), duration: _seconds(100));
    session.togglePlayback();
    await pumpEventQueue();
    expect(player.state.playing, isFalse);

    expect(session.toggleMute(), 0);
    session.togglePlayback();
    await pumpEventQueue();
    expect(player.seeks, [_seconds(12)]);
    expect(player.state.playing, isTrue);

    session.togglePlayback();
    session.togglePlayback();
    await pumpEventQueue();
    expect(player.seeks, hasLength(1));
  });

  test('a failed resolve shows the reason and retry loads again', () async {
    final repository = _PlaybackRepository()..resolveFailure = '站源暂时不可用';
    final store = await openStore();
    final (session, player) = await _open(repository, store);

    expect(session.ready, isFalse);
    expect(session.error, '站源暂时不可用');
    expect(player.opened, isEmpty);

    repository.resolveFailure = '';
    await session.retry();
    expect(session.error, isNull);
    expect(session.ready, isTrue);
    expect(player.opened, hasLength(1));
  });

  test('switching users pauses and stops recording progress', () async {
    final repository = _PlaybackRepository();
    final store = await openStore(viewerPreferences);
    final (session, player) = await _open(repository, store);

    player.progress(_seconds(30), duration: _seconds(100));
    await store.switchProfile('viewer');
    await pumpEventQueue();

    expect(player.state.playing, isFalse);
    await session.saveProgress();
    expect(store.watched(_show.id), isNull);
    expect(() => session.setSpeed(2), throwsStateError);
  });

  test('closing saves progress and releases the session and player', () async {
    final repository = _PlaybackRepository();
    final store = await openStore();
    final (session, player) = await _open(repository, store);

    player.progress(_seconds(50), duration: _seconds(100));
    _close(session);
    await pumpEventQueue();

    expect(store.watched(_show.id)!.position, 50);
    expect(repository.released, contains('session-1'));
    expect(player.disposed, isTrue);
  });

  test('video size sets the aspect ratio', () async {
    final repository = _PlaybackRepository();
    final store = await openStore();
    final (session, player) = await _open(repository, store);

    player.resize(1920, 1080);
    expect(session.aspectRatio, closeTo(16 / 9, .001));
    expect(
      videoDisplaySize(const VideoParams(w: 1920, h: 1080, rotate: 90)),
      const Size(1080, 1920),
    );
  });
}
