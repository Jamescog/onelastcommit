import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/commit_event_model.dart';

abstract class TrackerLocalDataSource {
  Future<List<CommitEventModel>> getLastEvents();
  Future<void> cacheEvents(List<CommitEventModel> events);
  Future<String?> getEtag();
  Future<void> saveEtag(String etag);
  Future<DateTime?> getLastFetchedAt();
  Future<void> saveLastFetchedAt(DateTime time);
}

class TrackerLocalDataSourceImpl implements TrackerLocalDataSource {
  final SharedPreferences sharedPreferences;

  TrackerLocalDataSourceImpl({required this.sharedPreferences});

  @override
  Future<List<CommitEventModel>> getLastEvents() async {
    final jsonString = sharedPreferences.getString('commit_events');
    if (jsonString == null) return [];

    final List<dynamic> maps = json.decode(jsonString);
    final events = maps.map((m) => CommitEventModel.fromMap(m)).toList();
    // Sort descending by date to match SQL behavior
    events.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return events;
  }

  @override
  Future<void> cacheEvents(List<CommitEventModel> events) async {
    // Get existing events
    final currentEvents = await getLastEvents();
    
    // Create a map for deduplication, keyed by event ID
    final eventMap = {for (var e in currentEvents) e.id: e};

    // Update with new events
    for (var event in events) {
      eventMap[event.id] = event;
    }

    // Convert back to list and sort
    final allEvents = eventMap.values.toList();
    allEvents.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    // Serialize to JSON
    // We need to cast the map for json encoding or ensure types are simple
    final maps = allEvents.map((e) => e.toMap()).toList();
    await sharedPreferences.setString('commit_events', json.encode(maps));
  }

  @override
  Future<String?> getEtag() async {
    return sharedPreferences.getString('etag');
  }

  @override
  Future<void> saveEtag(String etag) async {
    await sharedPreferences.setString('etag', etag);
  }

  @override
  Future<DateTime?> getLastFetchedAt() async {
    final str = sharedPreferences.getString('last_fetched_at');
    if (str != null) return DateTime.parse(str);
    return null;
  }

  @override
  Future<void> saveLastFetchedAt(DateTime time) async {
    await sharedPreferences.setString('last_fetched_at', time.toUtc().toIso8601String());
  }
}
