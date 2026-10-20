import 'package:duanju_app/core_bridge.dart';
import 'package:duanju_app/local_store.dart';
import 'package:duanju_app/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Drama drama(
  String key, {
  String source = 'hongguo',
  String? title,
  String category = '',
  int episodes = 80,
}) => Drama(
  id: '$source:$key',
  source: source,
  title: title ?? key,
  category: category,
  episodes: episodes,
);

WatchEntry watching(Drama drama, {int episode = 1, double position = 10}) =>
    WatchEntry(
      drama: drama,
      episode: episode,
      position: position,
      duration: 100,
      updatedAt: DateTime(2026, 10, 20),
    );

Future<LocalStore> openStore([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(Map.of(initial));
  final store = LocalStore(await SharedPreferences.getInstance());
  addTearDown(store.dispose);
  return store;
}

LocalStore restartStore(LocalStore store) {
  final restarted = LocalStore(store.preferences);
  addTearDown(restarted.dispose);
  return restarted;
}

class FakeRepository extends AppRepository {
  List<CatalogCategory> categoryList = const [
    CatalogCategory.all,
    CatalogCategory('short_play', '真人剧'),
  ];
  List<Drama> recommended = [
    drama('r1', title: '推荐剧一'),
    drama('r2', title: '推荐剧二'),
    drama('r3', title: '推荐剧三'),
  ];
  List<String> suggestionList = const [];
  final cachedPages = <String, CatalogPage>{};
  final catalogRequests = <String>[];
  final recommendRequests = <({bool more, bool force})>[];
  String failure = '';

  CatalogPage pageFor(String source, String category, String query, int page) =>
      CatalogPage([
        query.isEmpty
            ? drama('$category-$page', source: source, title: '分类$category')
            : drama('found', source: source, title: '搜到的剧'),
      ], page: page);

  @override
  Future<void> initialize() async {}

  @override
  Future<List<CatalogCategory>> categories(
    String source, {
    bool force = false,
  }) async => categoryList;

  @override
  Future<CatalogPage> recommendations(
    String genre, {
    bool more = false,
    bool force = false,
  }) async {
    recommendRequests.add((more: more, force: force));
    return CatalogPage(recommended);
  }

  @override
  Future<CatalogPage> catalog(
    String source, {
    int page = 1,
    String query = '',
    String category = '',
    bool force = false,
  }) async {
    catalogRequests.add('$source|$category|$query|$page${force ? '!' : ''}');
    if (failure.isNotEmpty) throw AppFailure(failure);
    return pageFor(source, category, query, page);
  }

  @override
  Future<CatalogPage> cached(String source, {String category = ''}) async =>
      cachedPages['$source|$category'] ?? CatalogPage(const []);

  @override
  Future<List<String>> suggestions(String query) async => suggestionList;

  @override
  Future<String> cover(Drama drama, {bool force = false}) async =>
      throw AppFailure('测试数据没有海报');

  @override
  Future<DramaDetail> detail(Drama drama) async => throw UnimplementedError();

  @override
  Future<PlaybackPlan> resolve(
    Drama drama,
    Episode episode, {
    int quality = 0,
  }) async => throw UnimplementedError();

  @override
  Future<PlaybackPlan> fallback(PlaybackPlan current) async =>
      throw UnimplementedError();

  @override
  Future<void> cancelPlayback() async {}

  @override
  Future<void> release(String session) async {}
}
