import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config.dart';

class WordPressService {
  final String baseUrl;
  WordPressService({String? baseUrl}) : baseUrl = baseUrl ?? AppConfig.wordpressBaseUrl;

  Future<List<Map<String, dynamic>>> fetchLatestPosts({int perPage = 20}) async {
    final uri = Uri.parse('$baseUrl${AppConfig.wpPostsEndpoint}?per_page=$perPage&_embed');
    final res = await http.get(uri, headers: {'Accept': 'application/json'});
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = jsonDecode(res.body) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } else {
      throw Exception('WordPress fetch failed ${res.statusCode}');
    }
  }
}

