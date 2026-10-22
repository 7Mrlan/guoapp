part of 'local_store.dart';

extension LocalStoreSync on LocalStore {
  Map<String, dynamic> _backupFollowSync(String profile) {
    final raw = _string(_key('lanRecords', profile));
    if (raw == null) return {};
    final document = LanDocument.fromJson(jsonDecode(raw));
    return {
      'followSync': document.records.values
          .map((record) => record.toJson())
          .toList(),
    };
  }

  Map<String, LanRecord>? _readBackupFollowSync(Map library) {
    final raw = library['followSync'];
    if (raw == null) return null;
    if (raw is! List || raw.length > LanDocument.limit) {
      throw const FormatException('备份同步记录数量无效');
    }
    final records = <String, LanRecord>{};
    for (final row in raw) {
      final record = LanRecord.fromJson(row);
      if (records.containsKey(record.id)) {
        throw const FormatException('备份同步记录重复');
      }
      records[record.id] = record;
    }
    final favorites = (library['favorites'] as List)
        .map((row) => (row as Map)['id'])
        .toSet();
    final followed = records.values
        .where((record) => record.followed)
        .map((record) => record.id)
        .toSet();
    if (favorites.length != followed.length ||
        !followed.containsAll(favorites)) {
      throw const FormatException('备份同步记录与追剧列表不一致');
    }
    return records;
  }

  LanDocument get lanDocument {
    if (locked) throw StateError('请先解锁当前用户');
    final cached = _lanDocumentCache;
    if (cached != null) return cached.copy();
    final raw = _string(_key('lanRecords'));
    final document = raw == null
        ? LanDocument.empty()
        : LanDocument.fromJson(jsonDecode(raw));
    if (raw == null) {
      document.reconcile(
        previous: const {},
        favorites: _favorites,
        states: _followStates,
        history: _history,
        oldHistory: const {},
      );
    }
    _lanDocumentCache = document;
    return document.copy();
  }

  void _trackLanChanges(
    Map<String, Object> values, {
    required Set<String> keys,
    Set<String> clearProgress = const {},
  }) {
    if (locked ||
        !keys.any(
          (key) =>
              key == _key('favorites') ||
              key == _key('history') ||
              key == _key('followStates'),
        )) {
      return;
    }
    final document = lanDocument;
    final favorites = <String, Drama>{};
    final history = <String, WatchEntry>{};
    final states = <String, FollowState>{};
    for (final row in readJsonList(values[_key('favorites')] as String?)) {
      final drama = Drama.fromJson(row);
      favorites[drama.id] = drama;
    }
    for (final row in readJsonList(values[_key('history')] as String?)) {
      final watch = WatchEntry.fromJson(row);
      history[watch.drama.id] = watch;
    }
    final rawStates = lanMap(
      jsonDecode(values[_key('followStates')] as String? ?? '{}'),
    );
    for (final drama in favorites.values) {
      states[drama.id] = rawStates[drama.id] == null
          ? FollowState.initial(drama, history[drama.id])
          : FollowState.fromJson(lanMap(rawStates[drama.id]));
    }
    document.reconcile(
      previous: _favorites,
      favorites: favorites,
      states: states,
      history: history,
      oldHistory: _history,
      clearProgress: clearProgress,
    );
    values[_key('lanRecords')] = jsonEncode(document.toJson());
  }
}
