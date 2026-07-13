import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import '../models/song.dart';

/// Loads bundled song data from assets/songs/ and keeps it up to date by
/// downloading new songs from the GitHub repo (no backend needed).
class SongRepository {
  String get _remoteBase => appConfig.remoteBase;

  final Map<String, Song> _cache = {};
  List<SongSummary> _bundled = [];
  // 동기화된(또는 캐시된) 원격 manifest 전체. 있으면 이게 "어떤 곡이 있는지"의
  // 기준이 된다(추가·삭제·교체 모두 OTA 반영). null이면 번들만 사용(오프라인).
  List<SongSummary>? _remoteManifest;
  final Set<String> _downloadedIds = {};
  Directory? _dir;

  Future<Directory> _songsDir() async {
    if (_dir != null) return _dir!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/${appConfig.localDirName}');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _dir = dir;
    return dir;
  }

  List<SongSummary> _parseManifest(String raw) =>
      (jsonDecode(raw) as List<dynamic>)
          .map((e) => SongSummary.fromJson(e as Map<String, dynamic>))
          .toList();

  /// Bundled songs, or the synced remote roster once available.
  Future<List<SongSummary>> loadManifest() async {
    _bundled = _parseManifest(
        await rootBundle.loadString('${appConfig.assetDir}/manifest.json'));

    final dir = await _songsDir();
    final cached = File('${dir.path}/manifest.json');
    if (cached.existsSync()) {
      try {
        _remoteManifest = _parseManifest(cached.readAsStringSync());
        _refreshDownloadedIds(dir);
      } on FormatException {
        _remoteManifest = null;
      }
    }
    return _roster();
  }

  void _refreshDownloadedIds(Directory dir) {
    _downloadedIds
      ..clear()
      ..addAll((_remoteManifest ?? const <SongSummary>[])
          .where((s) => File('${dir.path}/${s.id}.json').existsSync())
          .map((s) => s.id));
  }

  /// 원격 manifest가 있으면 그것이 곡 목록의 기준(삭제된 곡은 사라진다).
  /// 실제로 불러올 수 있는 곡만 노출(로컬 다운로드됨 또는 같은 id의 번들 존재).
  List<SongSummary> _roster() {
    final remote = _remoteManifest;
    if (remote != null && remote.isNotEmpty) {
      final bundledIds = {for (final s in _bundled) s.id};
      final list = remote
          .where((s) => _downloadedIds.contains(s.id) || bundledIds.contains(s.id))
          .toList();
      if (list.isNotEmpty) return _sorted(list);
    }
    return _sorted(List<SongSummary>.of(_bundled));
  }

  List<SongSummary> _sorted(List<SongSummary> list) {
    // Most recently added first; fall back to artist for equal/absent order.
    list.sort((a, b) {
      if (a.order != b.order) return b.order.compareTo(a.order);
      return a.artist.compareTo(b.artist);
    });
    return list;
  }

  bool _changed(SongSummary local, SongSummary remote) {
    // Prefer the content hash: it changes on ANY edit (cards, youtubeId, ...),
    // so every content change re-syncs.
    if (local.hash.isNotEmpty || remote.hash.isNotEmpty) {
      return local.hash != remote.hash;
    }
    // Fallback for manifests predating the hash field.
    return local.cardCount != remote.cardCount ||
        local.youtubeId != remote.youtubeId;
  }

  /// Checks GitHub for new or updated songs and downloads them.
  /// Returns the updated list if anything changed, null otherwise.
  Future<List<SongSummary>?> syncRemote() async {
    try {
      final res = await http
          .get(Uri.parse('$_remoteBase/manifest.json'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final remote = _parseManifest(utf8.decode(res.bodyBytes));

      final dir = await _songsDir();
      final local = {
        for (final s in _bundled) s.id: s,
        for (final s in (_remoteManifest ?? const <SongSummary>[])) s.id: s,
      };
      var fetched = 0;
      for (final summary in remote) {
        final known = local[summary.id];
        if (known != null && !_changed(known, summary)) continue;
        final song = await http
            .get(Uri.parse('$_remoteBase/${summary.id}.json'))
            .timeout(const Duration(seconds: 10));
        if (song.statusCode != 200) continue;
        final body = utf8.decode(song.bodyBytes);
        jsonDecode(body); // validate before persisting
        File('${dir.path}/${summary.id}.json').writeAsStringSync(body);
        _cache.remove(summary.id);
        fetched++;
      }
      // manifest는 곡 목록이 바뀌면(추가·삭제·순서·조회수) 항상 갱신해야 하므로
      // fetched 여부와 무관하게 로컬 캐시를 최신 원격으로 덮어쓴다.
      File('${dir.path}/manifest.json')
          .writeAsStringSync(utf8.decode(res.bodyBytes));
      final prevIds = {for (final s in (_remoteManifest ?? const <SongSummary>[])) s.id};
      _remoteManifest = remote;
      _refreshDownloadedIds(dir);
      // 목록 구성/순서/곡 내용 중 하나라도 바뀌었으면 갱신된 목록 반환.
      final changed = fetched > 0 || prevIds.length != remote.length ||
          remote.any((s) => !prevIds.contains(s.id));
      if (!changed) return null;
      return _roster();
    } on Exception {
      return null; // offline or GitHub unreachable — bundled songs still work
    }
  }

  Future<Song> loadSong(String id) async {
    final cached = _cache[id];
    if (cached != null) return cached;

    String raw;
    final dir = await _songsDir();
    final file = File('${dir.path}/$id.json');
    if (file.existsSync()) {
      raw = file.readAsStringSync();
    } else {
      raw = await rootBundle.loadString('${appConfig.assetDir}/$id.json');
    }
    final song = Song.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    _cache[id] = song;
    return song;
  }
}
