// lib/screens/home_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/app_network_info.dart';
import '../services/network_service.dart';
import '../widgets/speed_gauge.dart';
import '../widgets/app_network_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // State
  bool _hasPermission = false;
  bool _isLoading = true;
  bool _isWifi = false;
  int _rxSpeed = 0;
  int _txSpeed = 0;
  List<AppNetworkInfo> _apps = [];
  bool _showSystemApps = false;
  bool _showActiveOnly = true;

  Timer? _refreshTimer;
  String? _killedAppName;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final hasPerm = await NetworkService.hasUsagePermission();
    setState(() => _hasPermission = hasPerm);

    if (hasPerm) {
      await _refresh();
      _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
    }

    setState(() => _isLoading = false);
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
      });
    }
  }

  Future<void> _killApp(AppNetworkInfo app) async {
    final success = await NetworkService.killApp(app.packageName);
    if (mounted) {
      setState(() => _killedAppName = app.appName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF00E676), size: 18),
              const SizedBox(width: 8),
              Text(
                success
                    ? '${app.appName} background processes killed'
                    : 'Could not kill ${app.appName}',
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0D1B2A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
      // Refresh after kill
      Future.delayed(const Duration(seconds: 1), _refresh);
    }
  }

  List<AppNetworkInfo> get _filteredApps {
    return _apps.where((app) {
      if (_showActiveOnly && !app.isActive) return false;
      if (!_showSystemApps && app.isSystemApp) return false;
      return true;
    }).toList();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060E18),
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
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFF00D4FF)),
    );
  }

  Widget _buildPermissionScreen() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B2A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF1E3A5F)),
            ),
            child: const Icon(Icons.lock_open_rounded,
                color: Color(0xFF00D4FF), size: 64),
          ),
          const SizedBox(height: 32),
          const Text(
            'Usage Access Required',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'NetWatch needs Usage Access permission to see which apps are using your network.\n\nGo to Settings → Apps → Special App Access → Usage Access → enable NetWatch.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await NetworkService.requestUsagePermission();
                // Poll for permission after returning
                await Future.delayed(const Duration(seconds: 1));
                _init();
              },
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Grant Permission'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D4FF),
                foregroundColor: const Color(0xFF060E18),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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
            child: const Text(
              "I've granted it, retry",
              style: TextStyle(color: Color(0xFF00D4FF)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMain() {
    final filtered = _filteredApps;

    return RefreshIndicator(
      color: const Color(0xFF00D4FF),
      backgroundColor: const Color(0xFF0D1B2A),
      onRefresh: _refresh,
      child: CustomScrollView(
        slivers: [
          // ─── Header ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NetWatch',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Real-time network monitor',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Live indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF00E676).withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PulseDot(),
                        SizedBox(width: 6),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: Color(0xFF00E676),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Speed Gauge ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SpeedGauge(
              rxBytesPerSec: _rxSpeed,
              txBytesPerSec: _txSpeed,
              isWifi: _isWifi,
            ),
          ),

          // ─── Filter bar ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${filtered.length} app${filtered.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  _FilterChip(
                    label: 'Active only',
                    selected: _showActiveOnly,
                    onTap: () =>
                        setState(() => _showActiveOnly = !_showActiveOnly),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'System',
                    selected: _showSystemApps,
                    onTap: () =>
                        setState(() => _showSystemApps = !_showSystemApps),
                  ),
                ],
              ),
            ),
          ),

          // ─── App list ────────────────────────────────────────────────────
          if (filtered.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  children: [
                    Icon(Icons.wifi_off_rounded,
                        color: Colors.white.withOpacity(0.2), size: 48),
                    const SizedBox(height: 16),
                    Text(
                      _showActiveOnly
                          ? 'No apps using internet right now'
                          : 'No apps found',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final app = filtered[i];
                  return AppNetworkTile(
                    key: ValueKey(app.packageName),
                    app: app,
                    onKill: () => _killApp(app),
                  );
                },
                childCount: filtered.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ─── Animated pulse dot for LIVE badge ────────────────────────────────────────
class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _anim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color.fromRGBO(0, 230, 118, _anim.value),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF00D4FF).withOpacity(0.15)
              : const Color(0xFF0D1B2A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF00D4FF).withOpacity(0.5)
                : const Color(0xFF1E3A5F),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF00D4FF) : Colors.white38,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}