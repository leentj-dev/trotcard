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
  List<SongSummary> _downloaded = [];
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

  /// Bundled songs + previously downloaded songs, synced first.
  Future<List<SongSummary>> loadManifest() async {
    _bundled = _parseManifest(
        await rootBundle.loadString('${appConfig.assetDir}/manifest.json'));

    final dir = await _songsDir();
    final cached = File('${dir.path}/manifest.json');
    if (cached.existsSync()) {
      try {
        final remote = _parseManifest(cached.readAsStringSync());
        _downloaded = remote
            .where((s) => File('${dir.path}/${s.id}.json').existsSync())
            .toList();
      } on FormatException {
        _downloaded = [];
      }
    }
    return _merged();
  }

  /// Downloaded entries override bundled ones with the same id.
  List<SongSummary> _merged() {
    final map = {for (final s in _bundled) s.id: s};
    for (final s in _downloaded) {
      map[s.id] = s;
    }
    final list = map.values.toList();
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
        for (final s in _downloaded) s.id: s,
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
      if (fetched == 0) return null;

      File('${dir.path}/manifest.json')
          .writeAsStringSync(utf8.decode(res.bodyBytes));
      _downloaded = remote
          .where((s) => File('${dir.path}/${s.id}.json').existsSync())
          .toList();
      return _merged();
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
