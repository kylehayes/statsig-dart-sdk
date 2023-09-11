import 'dart:convert';

import 'disk_util.dart';
import 'statsig_user.dart';

class InternalStore {
  Map featureGates = {};
  Map dynamicConfigs = {};
  Map layerConfigs = {};
  int time = 0;
  Map derivedFields = {};
  String userHash = "";

  int getSinceTime(StatsigUser user) {
    if (userHash != user.getFullHash()) {
      return 0;
    }
    return time;
  }

  Map getPreviousDerivedFields(StatsigUser user) {
    if (userHash != user.getFullHash()) {
      return {};
    }
    return derivedFields;
  }

  Future<void> load(StatsigUser user) async {
    var store = await _read(user);
    featureGates = store?["feature_gates"] ?? {};
    dynamicConfigs = store?["dynamic_configs"] ?? {};
    layerConfigs = store?["layer_configs"] ?? {};
    time = store?["time"] ?? 0;
    derivedFields = store?["derived_fields"] ?? {};
    userHash = store?["user_hash"] ?? "";
  }

  Future<void> save(StatsigUser user, Map? response) async {
    featureGates = response?["feature_gates"] ?? {};
    dynamicConfigs = response?["dynamic_configs"] ?? {};
    layerConfigs = response?["layer_configs"] ?? {};
    time = response?["time"] ?? 0;
    derivedFields = response?["derived_fields"] ?? {};
    userHash = user.getFullHash();

    await _write(
        user,
        json.encode({
          "feature_gates": featureGates,
          "dynamic_configs": dynamicConfigs,
          "layer_configs": layerConfigs,
          "time": time,
          "derived_fields": derivedFields,
          "user_hash": userHash
        }));
  }

  Future<void> clear() async {
    featureGates = {};
    dynamicConfigs = {};
    layerConfigs = {};
    time = 0;
    derivedFields = {};
    userHash = "";
  }

  Future<void> _write(StatsigUser user, String content) async {
    var userId = user.userId.isNotEmpty ? user.userId : "STATSIG_NULL_USER";
    await DiskUtil.write("$userId.statsig_store", content);
  }

  Future<Map?> _read(StatsigUser user) async {
    try {
      var userId = user.userId.isNotEmpty ? user.userId : "STATSIG_NULL_USER";
      var content = await DiskUtil.read("$userId.statsig_store");
      var data = json.decode(content);
      return data is Map ? data : null;
    } catch (_) {}
    return null;
  }
}
