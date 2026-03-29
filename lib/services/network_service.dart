// lib/services/network_service.dart

import 'package:flutter/services.dart';
import '../models/app_network_info.dart';

class NetworkService {
  static const _channel = MethodChannel('com.osanda.netwatch/network');

  static Future<bool> hasUsagePermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasUsagePermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestUsagePermission() async {
    await _channel.invokeMethod('requestUsagePermission');
  }

  static Future<Map<String, int>> getDeviceSpeed() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('getDeviceSpeed');
      return {
        'rxBytesPerSec': (result?['rxBytesPerSec'] as num?)?.toInt() ?? 0,
        'txBytesPerSec': (result?['txBytesPerSec'] as num?)?.toInt() ?? 0,
      };
    } catch (_) {
      return {'rxBytesPerSec': 0, 'txBytesPerSec': 0};
    }
  }

  static Future<List<AppNetworkInfo>> getAppNetworkStats() async {
    try {
      final List<dynamic> raw =
          await _channel.invokeMethod('getAppNetworkStats') ?? [];
      return raw.cast<Map>().map((m) => AppNetworkInfo.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Kills background processes. Returns "killed" or "opened_settings".
  static Future<String> killApp(String packageName, {bool openSettings = false}) async {
    try {
      final result = await _channel.invokeMethod<String>('killApp', {
        'packageName': packageName,
        'openSettings': openSettings,
      });
      return result ?? 'killed';
    } catch (_) {
      return 'error';
    }
  }

  static Future<bool> isOnWifi() async {
    try {
      return await _channel.invokeMethod<bool>('isOnWifi') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getDebugStats() async {
    try {
      final List<dynamic> raw =
          await _channel.invokeMethod('getDebugStats') ?? [];
      return raw.cast<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<Uint8List?> getAppIcon(String packageName) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>('getAppIcon', {'packageName': packageName});
      return result;
    } catch (_) {
      return null;
    }
  }

  static String formatSpeed(int bytesPerSec) {
    if (bytesPerSec < 1024) return '$bytesPerSec B/s';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}