import 'dart:convert';

import 'package:duanju_app/local_profiles.dart';
import 'package:duanju_app/local_snapshot.dart';
import 'package:duanju_app/local_store.dart';
import 'package:duanju_app/playback_preferences.dart';
import 'package:duanju_app/theme_color.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'support/fakes.dart';

class _FailingPlatform extends InMemorySharedPreferencesStore {
  _FailingPlatform(super.data) : super.withData();
  String failure = '';
  int snapshotWrites = 0;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.endsWith(LocalSnapshot.storageKey)) {
      snapshotWrites++;
      switch (failure) {
        case 'false':
          return false;
        case 'throw':
          throw StateError('写入失败');
        case 'after':
          failure = '';
          await super.setValue(valueType, key, value);
          throw StateError('写入后确认失败');
      }
    }
    return super.setValue(valueType, key, value);
  }
}

Map<String, Object?> _snapshotValues(LocalStore store) =>
    (jsonDecode(store.preferences.getString(LocalSnapshot.storageKey)!)
            as Map)['values']
        as Map<String, Object?>;

String _snapshot(Map<String, Object> values) => jsonEncode({
  'version': 1,
  'values': {
    'profiles': jsonEncode([
      const LocalProfile(id: 'default', name: '管理员', admin: true).toJson(),
    ]),
    ...values,
  },
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final first = drama('1', title: '旧资料');
  final second = drama('2', title: '新资料');

  group('compatibility', () {
    test('the snapshot holds exactly the fields older versions read', () {
      expect(LocalSnapshot.globalKeys, {
        'profiles',
        'activeProfile',
        'displayMode',
        'themeMode',
        'autoExport',
        'exportPosters',
        'sourceSwitches',
        'forceLogin',
      });
      expect(LocalSnapshot.libraryKeys, {
        'history',
        'favorites',
        'followStates',
        'seriesCandidates',
        'mediaHistory',
        'source',
        'hideVip',
        'playback',
        'downloadPreferences',
        'catalogView',
        'recentSearches',
        'lanRecords',
        'lanSettings',
        'lanReceipts',
      });
    });

    test('settings added by the rebuild stay outside the snapshot', () async {
      final store = await openStore();
      await store.setFollowSystemColor(false);
      await store.setThemeColor(ThemeColor.teal);
      await store.setSideBarExpanded(false);
      await store.setDisplayMode('pad');
      await store.rememberSearch('剧名');

      final values = _snapshotValues(store);
      expect(values.keys.where((key) => !LocalSnapshot.owns(key)), isEmpty);
      expect(values['displayMode'], 'pad');

      final restarted = restartStore(store);
      expect(restarted.followSystemColor, isFalse);
      expect(restarted.themeColor, ThemeColor.teal);
      expect(restarted.sideBarExpanded, isFalse);
      expect(restarted.displayMode, 'pad');
      expect(restarted.recentSearches, ['剧名']);
    });

    test('records saved before the snapshot load and move into it', () async {
      final store = await openStore({
        'favorites': jsonEncode([first.toJson()]),
        'history': jsonEncode([watching(first, episode: 3).toJson()]),
        'themeMode': 'dark',
        'plugin_secret': 'not-ours',
      });
      expect(store.configurationError, isNull);
      expect(store.favorites.single.id, first.id);
      expect(store.watched(first.id)?.episode, 3);
      expect(store.themeMode, 'dark');

      await store.toggleFavorite(second);
      final values = _snapshotValues(store);
      expect(values['themeMode'], 'dark');
      expect(values, isNot(contains('plugin_secret')));
      final restarted = restartStore(store);
      expect(restarted.favorites.map((item) => item.id), [second.id, first.id]);
      expect(restarted.watched(first.id)?.episode, 3);
    });

    test('values written by other versions fall back to defaults', () async {
      final store = await openStore({
        LocalSnapshot.storageKey: _snapshot({
          'displayMode': 'foldable',
          'themeMode': 'sepia',
          'sourceSwitches': 'not json',
          'sourceGateEnabled': false,
          'sourceGateHash': '',
        }),
        'themeColor': 'unknown',
      });
      expect(store.configurationError, isNull);
      expect(store.displayMode, 'auto');
      expect(store.themeMode, 'system');
      expect(store.themeColor, ThemeColor.orange);
      expect(store.sourceEnabled('hongguo'), isTrue);
      expect(store.sourceEnabled('huangdou'), isFalse);

      await store.setThemeMode('dark');
      expect(_snapshotValues(store).keys, isNot(contains('sourceGateEnabled')));
    });

    for (final (name, records) in [
      (
        'an unknown snapshot field',
        {
          LocalSnapshot.storageKey: _snapshot({
            'favorites': jsonEncode([first.toJson()]),
            'newerFeature': 'on',
          }),
        },
      ),
      (
        'unreadable profiles',
        {
          'profiles': 'broken-json',
          'favorites': jsonEncode([first.toJson()]),
        },
      ),
      (
        'an invalid profile',
        {
          'profiles': jsonEncode([
            {
              'id': 'default',
              'name': '管理员',
              'admin': true,
              'sources': [],
              'salt': 'bad',
            },
          ]),
          'favorites': jsonEncode([first.toJson()]),
        },
      ),
    ]) {
      test('$name locks access and keeps the raw records', () async {
        final store = await openStore(records);
        expect(store.configurationError, isNotNull);
        expect(store.locked, isTrue);
        expect(store.canDownload, isFalse);
        expect(store.favorites, isEmpty);
        expect(store.sources, isEmpty);
        await expectLater(store.switchProfile('default'), throwsStateError);
        await store.toggleFavorite(second);

        for (final entry in records.entries) {
          expect(store.preferences.get(entry.key), entry.value);
        }
        expect(store.exportRecoveryData(), contains('旧资料'));
      });
    }
  });

  group('failed writes', () {
    Future<LocalStore> launch(_FailingPlatform platform) async {
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance = platform;
      final store = LocalStore(await SharedPreferences.getInstance());
      addTearDown(store.dispose);
      return store;
    }

    for (final failure in ['false', 'throw', 'after']) {
      test('a "$failure" failure leaves memory and disk unchanged', () async {
        final platform = _FailingPlatform({'flutter.plugin_secret': 'kept'});
        final store = await launch(platform);
        await store.toggleFavorite(first);
        await store.saveWatch(watching(first, position: 15));

        for (final change in <Future<void> Function()>[
          () => store.toggleFavorite(second),
          () => store.clearHistory(),
          () => store.setThemeMode('light'),
          () => store.setPlaybackPreferences(
            const PlaybackPreferences(speed: 2, autoAdvance: false),
          ),
        ]) {
          platform.failure = failure;
          await expectLater(change(), throwsStateError);
          for (final current in [store, await launch(platform)]) {
            expect(current.favorites.map((item) => item.id), [first.id]);
            expect(current.watched(first.id)?.position, 15);
            expect(current.themeMode, 'system');
            expect(current.playbackPreferences.speed, 1);
          }
          expect(store.preferences.getString('plugin_secret'), 'kept');
        }

        platform.failure = '';
        await store.toggleFavorite(second);
        expect((await launch(platform)).favorites, hasLength(2));
      });
    }

    test('a failed backup import keeps every old record', () async {
      final platform = _FailingPlatform({});
      final store = await launch(platform);
      await store.toggleFavorite(first);
      final old = await store.exportBackup();
      final backup = jsonDecode(old) as Map<String, dynamic>;
      ((backup['libraries'] as Map)['default'] as Map)
        ..remove('followSync')
        ..['favorites'] = [second.toJson()]
        ..['followStates'] = {};
      final content = jsonEncode(backup);

      for (final failure in ['false', 'throw', 'after']) {
        platform.failure = failure;
        await expectLater(store.importBackup(content), throwsStateError);
        expect(await store.exportBackup(), old);
        expect(await (await launch(platform)).exportBackup(), old);
      }

      platform.failure = '';
      final before = platform.snapshotWrites;
      await store.importBackup(content);
      expect(platform.snapshotWrites - before, 1);
      expect((await launch(platform)).favorites.single.id, second.id);
    });
  });

  group('backup', () {
    test('a round trip restores records and theme, nothing else', () async {
      final store = await openStore({'plugin_secret': 'stays-local'});
      await store.toggleFavorite(first);
      await store.saveWatch(watching(first, episode: 2, position: 11));
      await store.setThemeMode('dark');
      await store.setFollowSystemColor(false);
      await store.setThemeColor(ThemeColor.violet);
      final backup = await store.exportBackup();
      expect(backup, isNot(contains('stays-local')));

      await store.toggleFavorite(first);
      await store.clearHistory();
      await store.setThemeMode('light');
      await store.setFollowSystemColor(true);
      await store.setThemeColor(ThemeColor.blue);
      await store.importBackup(backup);

      final restarted = restartStore(store);
      expect(restarted.favorites.single.id, first.id);
      expect(restarted.watched(first.id)?.position, 11);
      expect(restarted.themeMode, 'dark');
      expect(restarted.followSystemColor, isFalse);
      expect(restarted.themeColor, ThemeColor.violet);
      expect(restarted.preferences.getString('plugin_secret'), 'stays-local');
    });

    test('older backups without newer fields still import', () async {
      final store = await openStore();
      await store.toggleFavorite(first);
      final backup = jsonDecode(await store.exportBackup()) as Map;
      for (final key in ['themeMode', 'followSystemColor', 'themeColor']) {
        backup.remove(key);
      }
      final library = (backup['libraries'] as Map)['default'] as Map;
      for (final key in [
        'followSync',
        'playback',
        'downloadPreferences',
        'catalogView',
        'recentSearches',
        'seriesCandidates',
      ]) {
        library.remove(key);
      }

      await store.toggleFavorite(first);
      await store.setThemeMode('dark');
      await store.setThemeColor(ThemeColor.rose);
      await store.importBackup(jsonEncode(backup));
      expect(store.favorites.single.id, first.id);
      expect(store.themeMode, 'dark');
      expect(store.themeColor, ThemeColor.rose);
      expect(
        store.playbackPreferences.toJson(),
        const PlaybackPreferences().toJson(),
      );
    });

    for (final (name, change) in <(String, void Function(Map))>[
      ('another app', (data) => data['app'] = 'other'),
      ('an unknown theme mode', (data) => data['themeMode'] = 'sepia'),
      ('an unknown theme color', (data) => data['themeColor'] = 'gold'),
      (
        'a profile id with a path',
        (data) => (data['profiles'] as List).add({
          'id': '../escape',
          'name': '坏数据',
          'admin': false,
          'sources': [],
        }),
      ),
    ]) {
      test('a backup from $name is rejected before anything changes', () async {
        final store = await openStore();
        await store.toggleFavorite(first);
        final old = await store.exportBackup();
        final data = jsonDecode(old) as Map;
        change(data);
        await expectLater(
          store.importBackup(jsonEncode(data)),
          throwsA(anything),
        );
        expect(await store.exportBackup(), old);
      });
    }
  });
}
