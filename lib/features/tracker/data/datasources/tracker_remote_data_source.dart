import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/error/exceptions.dart';
import '../models/commit_event_model.dart';

abstract class TrackerRemoteDataSource {
  Future<List<CommitEventModel>> getPushEvents(
    String username, {
    String? etag,
    String? token,
  });
  String? get lastEtag;
}

class TrackerRemoteDataSourceImpl implements TrackerRemoteDataSource {
  final http.Client client;
  String? _lastEtag;

  TrackerRemoteDataSourceImpl({required this.client});

  @override
  String? get lastEtag => _lastEtag;

  @override
  Future<List<CommitEventModel>> getPushEvents(
    String username, {
    String? etag,
    String? token,
  }) async {
    final url = 'https://api.github.com/users/$username/events';
    
    final response = await client.get(
      Uri.parse(url),
      headers: {
        if (etag != null) 'If-None-Match': etag,
        if (token != null && token.isNotEmpty) ...{
          'Authorization': 'token $token',
        },
        'User-Agent': 'olc-app',
      },
    );

    if (response.statusCode == 200) {
      _lastEtag = response.headers['etag'];
      final List decoded = json.decode(response.body);
      return decoded
          .where((e) => e['type'] == 'PushEvent')
          .map((e) => CommitEventModel.fromJson(e))
          .toList();
    } else if (response.statusCode == 304) {
      return [];
    } else {
      throw ServerException();
    }
  }
}
