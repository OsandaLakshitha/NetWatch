// lib/screens/home_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_network_info.dart';
import '../services/network_service.dart';
import '../widgets/speed_gauge.dart';
import '../widgets/app_network_tile.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Logo — defined at TOP LEVEL so Flutter can always resolve it
// ═══════════════════════════════════════════════════════════════════════════════
class NetWatchLogo extends StatelessWidget {
  final double size;
  const NetWatchLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF9500), Color(0xFFFF2D00)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B00).withOpacity(0.5),
            blurRadius: size * 0.6,
            spreadRadius: -2,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.58, size * 0.58),
          painter: _LogoPainter(),
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = s.width * 0.38;
    final cy = s.height * 0.62;

    // Three wifi-style arcs radiating from bottom-left
    for (int i = 1; i <= 3; i++) {
      final r = s.width * 0.18 * i;
      p.strokeWidth = s.width * 0.085;
      p.color = Colors.white.withOpacity(i == 3 ? 0.6 : 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -math.pi * 0.95,   // start angle: pointing up-right
        math.pi * 0.55,    // sweep: 99 degrees
        false,
        p,
      );
    }

    // Center dot
    canvas.drawCircle(
      Offset(cx, cy),
      s.width * 0.07,
      Paint()..color = Colors.white,
    );

    // Speed arrow (↗ top-right)
    final ap = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final ax = s.width * 0.55;
    final ay = s.height * 0.48;
    final ex = s.width * 0.88;
    final ey = s.height * 0.15;

    canvas.drawLine(Offset(ax, ay), Offset(ex, ey), ap); // shaft
    canvas.drawLine(Offset(ex, ey), Offset(ex - s.width * 0.22, ey), ap); // right cap
    canvas.drawLine(Offset(ex, ey), Offset(ex, ey + s.height * 0.22), ap); // down cap
  }

  @override
  bool shouldRepaint(_) => false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Home Screen
// ═══════════════════════════════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _hasPermission = false;
  bool _isLoading = true;
  bool _isWifi = false;
  int _rxSpeed = 0;
  int _txSpeed = 0;
  List<AppNetworkInfo> _apps = [];
  bool _showSystemApps = false;
  bool _showActiveOnly = true;
  int _pollCount = 0;

  List<Map<String, dynamic>> _debugStats = [];
  bool _showDebug = false;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final hasPerm = await NetworkService.hasUsagePermission();
    if (mounted) setState(() => _hasPermission = hasPerm);

    if (hasPerm) {
      await _refresh(); // seeds byte counters
      _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _refresh() async {
    final speedData = await NetworkService.getDeviceSpeed();
    final apps = await NetworkService.getAppNetworkStats();
    final wifi = await NetworkService.isOnWifi();
    if (mounted) {
      setState(() {
        _rxSpeed = speedData['rxBytesPerSec'] ?? 0;
        _txSpeed = speedData['txBytesPerSec'] ?? 0;
        _apps = apps;
        _isWifi = wifi;
        _pollCount++;
      });
    }
  }

  Future<void> _loadDebugStats() async {
    final stats = await NetworkService.getDebugStats();
    if (mounted) setState(() => _debugStats = stats);
  }

  // Kill: first tries killBackgroundProcesses, then offers to open Force Stop page
  Future<void> _killApp(AppNetworkInfo app) async {
    final result = await NetworkService.killApp(app.packageName);

    if (!mounted) return;

    // Show snackbar + offer Force Stop option
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.power_settings_new_rounded,
                color: Color(0xFF00FF87), size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${app.appName} background processes stopped',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF131318),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF2A2A35)),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Force Stop',
          textColor: const Color(0xFFFF6B00),
          onPressed: () {
            NetworkService.killApp(app.packageName, openSettings: true);
          },
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 1));
    _refresh();
  }

  List<AppNetworkInfo> get _filteredApps {
    return _apps.where((app) {
      if (_showActiveOnly && !app.isActive) return false;
      if (!_showSystemApps && app.isSystemApp) return false;
      return true;
    }).toList();
  }

  int get _activeCount => _apps.where((a) => a.isActive).length;

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: _isLoading
            ? _buildLoading()
            : !_hasPermission
                ? _buildPermissionScreen()
                : _buildMain(),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          NetWatchLogo(size: 72),
          const SizedBox(height: 28),
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              color: Color(0xFFFF6B00),
              strokeWidth: 2.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          NetWatchLogo(size: 80),
          const SizedBox(height: 12),
          const Text(
            'NetWatch',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 36),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF131318),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF2A2A35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Usage Access needed',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'NetWatch needs Usage Access permission to see which apps are using your network.\n\n'
                  'Tap below → find NetWatch in the list → enable it.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await NetworkService.requestUsagePermission();
                await Future.delayed(const Duration(seconds: 2));
                _init();
              },
              icon: const Icon(Icons.settings_rounded, size: 18),
              label: const Text('Open Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _init,
            child: const Text("I've enabled it, check again",
                style: TextStyle(color: Color(0xFFFF6B00))),
          ),
        ],
      ),
    );
  }

  Widget _buildMain() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Header ─────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 0),
          child: Row(
            children: [
              // Logo
              NetWatchLogo(size: 38),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NetWatch',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    'Network Monitor',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (_activeCount > 0)
                _ActiveBadge(count: _activeCount),
              const SizedBox(width: 8),
              _DebugButton(
                active: _showDebug,
                onTap: () {
                  setState(() => _showDebug = !_showDebug);
                  if (_showDebug) _loadDebugStats();
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Speed gauge ────────────────────────────────────────────────────
        SpeedGauge(
          rxBytesPerSec: _rxSpeed,
          txBytesPerSec: _txSpeed,
          isWifi: _isWifi,
        ),

        // ── Warming up banner ──────────────────────────────────────────────
        if (_pollCount < 3)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD60A).withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFFFD60A).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timelapse_rounded,
                      color: Color(0xFFFFD60A), size: 14),
                  const SizedBox(width: 8),
                  Text(
                    'Warming up — speeds appear after a few seconds  ($_pollCount/3)',
                    style: const TextStyle(
                        color: Color(0xFFFFD60A), fontSize: 11),
                  ),
                ],
              ),
            ),
          ),

        // ── Debug panel ────────────────────────────────────────────────────
        if (_showDebug)
          Expanded(child: _buildDebugPanel())
        else ...[
          // ── Filter bar ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 16, 6),
            child: Row(
              children: [
                Text(
                  'APPS',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.28),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${_filteredApps.length}',
                  style: const TextStyle(
                      color: Colors.white24,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                _Toggle(
                  label: 'Active only',
                  value: _showActiveOnly,
                  onChanged: (v) => setState(() => _showActiveOnly = v),
                ),
                const SizedBox(width: 8),
                _Toggle(
                  label: 'System',
                  value: _showSystemApps,
                  onChanged: (v) => setState(() => _showSystemApps = v),
                ),
              ],
            ),
          ),

          // ── App list ────────────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFFFF6B00),
              backgroundColor: const Color(0xFF131318),
              onRefresh: _refresh,
              child: _filteredApps.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 40),
                      itemCount: _filteredApps.length,
                      itemBuilder: (ctx, i) => AppNetworkTile(
                        key: ValueKey(_filteredApps[i].packageName),
                        app: _filteredApps[i],
                        onKill: () => _killApp(_filteredApps[i]),
                        onForceStop: () => NetworkService.killApp(
                          _filteredApps[i].packageName,
                          openSettings: true,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDebugPanel() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD60A).withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFD60A).withOpacity(0.2)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DEBUG — Last 24h usage',
                  style: TextStyle(
                      color: Color(0xFFFFD60A),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 1.5)),
              SizedBox(height: 6),
              Text(
                'Apps with any network usage in the last 24 hours, sorted by total data.',
                style: TextStyle(
                    color: Colors.white54, fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ..._debugStats.map((s) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF131318),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2A35)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s['appName'] as String,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        Text('uid: ${s['uid']}',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 10)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('↓ ${s['rxMB']} MB',
                          style: const TextStyle(
                              color: Color(0xFF00C2FF),
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                      Text('↑ ${s['txMB']} MB',
                          style: const TextStyle(
                              color: Color(0xFFFF6B00),
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            )),
        if (_debugStats.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('Loading...',
                  style: TextStyle(color: Colors.white38)),
            ),
          ),
      ],
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Column(
          children: [
            Icon(
              _showActiveOnly ? Icons.wifi_off_rounded : Icons.apps_rounded,
              color: Colors.white12,
              size: 52,
            ),
            const SizedBox(height: 14),
            Text(
              _showActiveOnly
                  ? 'No apps actively using internet'
                  : 'No apps found',
              style: const TextStyle(color: Colors.white24, fontSize: 14),
            ),
            if (_showActiveOnly) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _showActiveOnly = false),
                child: const Text('Show all apps',
                    style: TextStyle(color: Color(0xFFFF6B00))),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ── Supporting widgets ─────────────────────────────────────────────────────────

class _ActiveBadge extends StatelessWidget {
  final int count;
  const _ActiveBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B00).withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF6B00).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Color(0xFF00FF87)),
          ),
          const SizedBox(width: 6),
          Text(
            '$count active',
            style: const TextStyle(
              color: Color(0xFFFF6B00),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _DebugButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFFFD60A).withOpacity(0.15)
              : const Color(0xFF131318),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? const Color(0xFFFFD60A).withOpacity(0.4)
                : const Color(0xFF2A2A35),
          ),
        ),
        child: Text(
          'DEBUG',
          style: TextStyle(
            color: active ? const Color(0xFFFFD60A) : Colors.white30,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: value
              ? const Color(0xFFFF6B00).withOpacity(0.15)
              : const Color(0xFF131318),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: value
                ? const Color(0xFFFF6B00).withOpacity(0.5)
                : const Color(0xFF2A2A35),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: value ? const Color(0xFFFF6B00) : Colors.white30,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}