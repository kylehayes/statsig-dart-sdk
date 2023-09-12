import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import 'internal_store.dart';
import 'statsig_event.dart';
import 'statsig_metadata.dart';
import 'statsig_options.dart';
import 'statsig_user.dart';

const defaultHost = 'https://statsigapi.net/v1';

const retryCodes = {
  408: true,
  500: true,
  502: true,
  503: true,
  504: true,
  522: true,
  524: true,
  599: true,
};

class NetworkService {
  final StatsigOptions _options;
  late String _host;
  late Map<String, String> _headers;

  NetworkService(this._options, String sdkKey) {
    _host = _options.api ?? defaultHost;
    _headers = {
      "Content-Type": "application/json",
      "STATSIG-API-KEY": sdkKey,
      "STATSIG-SDK-TYPE": StatsigMetadata.getSDKType(),
      "STATSIG-SDK-VERSION": StatsigMetadata.getSDKVersion(),
      "STATSIG-CLIENT-TIME": DateTime.now().millisecondsSinceEpoch.toString(),
    };
  }

  Future<Map?> initialize(StatsigUser user, InternalStore store) async {
    var url = Uri.parse(_host + '/initialize');
    return await _post(
            url,
            {
              "user": user.toJsonWithPrivateAttributes(),
              "statsigMetadata": StatsigMetadata.toJson(),
              "sinceTime": store.getSinceTime(user),
              "previousDerivedFields": store.getPreviousDerivedFields(user)
            },
            3,
            initialBackoffSeconds)
        .timeout(Duration(seconds: _options.initTimeout), onTimeout: () {
      print("[Statsig]: Initialize timed out.");
      return null;
    });
  }

  Future<bool> sendEvents(List<StatsigEvent> events) async {
    var url = Uri.parse(_host + '/rgstr');
    var result = await _post(
        url,
        {'events': events, 'statsigMetadata': StatsigMetadata.toJson()},
        2,
        initialBackoffSeconds);
    return result?['success'] ?? false;
  }

  Future<Map?> _post(Uri url,
      [Map? body, int retries = 0, int backoff = 1]) async {
    String data = json.encode(body);
    try {
      var response = await http.post(url, headers: _headers, body: data);

      if (response.statusCode >= 200 && response.statusCode <= 299) {
        return response.bodyBytes.isEmpty
            ? {}
            : jsonDecode(utf8.decode(response.bodyBytes)) as Map;
      } else if (retryCodes.containsKey(response.statusCode) && retries > 0) {
        await Future.delayed(Duration(seconds: backoff));
        return await _post(url, body, retries - 1, backoff * 2);
      }
    } catch (_) {}

    return null;
  }

  @visibleForTesting
  static int initialBackoffSeconds = 1;
}
