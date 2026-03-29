// lib/models/app_network_info.dart

class AppNetworkInfo {
  final int uid;
  final String packageName;
  final String appName;
  final int rxBytes;
  final int txBytes;
  final int rxBytesPerSec;
  final int txBytesPerSec;
  final bool isActive;
  final bool isSystemApp;

  const AppNetworkInfo({
    required this.uid,
    required this.packageName,
    required this.appName,
    required this.rxBytes,
    required this.txBytes,
    required this.rxBytesPerSec,
    required this.txBytesPerSec,
    required this.isActive,
    required this.isSystemApp,
  });

  int get totalBytesPerSec => rxBytesPerSec + txBytesPerSec;
  int get totalBytes => rxBytes + txBytes;

  factory AppNetworkInfo.fromMap(Map map) {
    return AppNetworkInfo(
      uid: (map['uid'] as num).toInt(),
      packageName: map['packageName'] as String,
      appName: map['appName'] as String,
      rxBytes: (map['rxBytes'] as num).toInt(),
      txBytes: (map['txBytes'] as num).toInt(),
      rxBytesPerSec: (map['rxBytesPerSec'] as num).toInt(),
      txBytesPerSec: (map['txBytesPerSec'] as num).toInt(),
      isActive: map['isActive'] as bool,
      isSystemApp: map['isSystemApp'] as bool,
    );
  }

  @override
  String toString() => 'AppNetworkInfo($appName, ↓${rxBytesPerSec}B/s ↑${txBytesPerSec}B/s)';
}