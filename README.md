# NetWatch — Per-App Network Monitor for Android

## What it does
- Shows **real-time download/upload speed** for the whole device
- Lists **every app** using your network with its individual speed (KB/s or MB/s)
- **KILL button** to stop an app's background processes instantly
- **Wi-Fi vs Mobile data** indicator
- Filter toggle: Active Only | Show System Apps
- Auto-refreshes every 2 seconds

---

## Project Setup

### 1. Create a new Flutter project
```bash
flutter create netwatch --org com.osanda
cd netwatch
```

### 2. Replace these files from this zip:
```
lib/
  main.dart
  models/app_network_info.dart
  services/network_service.dart
  screens/home_screen.dart
  widgets/speed_gauge.dart
  widgets/app_network_tile.dart

android/app/src/main/
  AndroidManifest.xml
  kotlin/com/osanda/netwatch/MainActivity.kt

pubspec.yaml
```

### 3. Update build.gradle (android/app/build.gradle)
Make sure these are set:
```groovy
android {
    compileSdkVersion 34
    defaultConfig {
        minSdkVersion 23        // Required for NetworkStatsManager
        targetSdkVersion 34
    }
}
```

### 4. Update settings.gradle namespace
In `android/app/build.gradle`, set:
```groovy
android {
    namespace "com.osanda.netwatch"
    ...
}
```

### 5. Install dependencies
```bash
flutter pub get
```

### 6. Run on your phone
```bash
flutter run
```

---

## Permissions Explained

| Permission | Why |
|---|---|
| `PACKAGE_USAGE_STATS` | See per-app network stats — requires manual grant in Settings |
| `KILL_BACKGROUND_PROCESSES` | Kill app background processes |
| `ACCESS_NETWORK_STATE` | Detect Wi-Fi vs mobile |
| `QUERY_ALL_PACKAGES` | List all installed apps (Android 11+) |

When you first open the app, it will detect if Usage Access is missing and guide you directly to the settings screen to enable it.

---

## How the Kill button works

The app uses `ActivityManager.killBackgroundProcesses()`. This is the same as going to Settings → Apps → Force Stop, but only kills **background** processes.

> **Note:** Some apps (like system services) cannot be killed this way. Google Play Services in particular will restart immediately. For those, you'd need root, which this app doesn't require.

---

## Troubleshooting

**"No apps using internet right now" even though something is clearly downloading:**
- Toggle off "Active only" — the speed sampling window may have just missed it
- Make sure Usage Access is granted for NetWatch

**Kill button doesn't seem to work:**
- The app likely restarted itself (common with system apps and Google services)
- You can disable auto-start in Settings → Battery → App Launch for that specific app

**Build error about namespace:**
- Add `namespace "com.osanda.netwatch"` to your `android/app/build.gradle` under the `android {}` block

---

## Color Scheme
- Background: `#060E18` (deep navy)  
- Card: `#0D1B2A`  
- Download: `#00D4FF` (cyan)  
- Upload: `#7C4DFF` (purple)  
- Kill/Alert: `#FF3B3B` (red)  
- Active: `#00E676` (green)