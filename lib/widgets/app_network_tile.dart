// lib/widgets/app_network_tile.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_network_info.dart';
import '../services/network_service.dart';

class AppNetworkTile extends StatefulWidget {
  final AppNetworkInfo app;
  final VoidCallback? onKill;
  final VoidCallback? onForceStop;

  const AppNetworkTile({super.key, required this.app, this.onKill, this.onForceStop});

  @override
  State<AppNetworkTile> createState() => _AppNetworkTileState();
}

class _AppNetworkTileState extends State<AppNetworkTile> {
  Uint8List? _iconBytes;
  bool _iconLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadIcon();
  }

  @override
  void didUpdateWidget(AppNetworkTile old) {
    super.didUpdateWidget(old);
    if (old.app.packageName != widget.app.packageName) {
      _iconLoaded = false;
      _iconBytes = null;
      _loadIcon();
    }
  }

  Future<void> _loadIcon() async {
    if (_iconLoaded) return;
    final bytes = await NetworkService.getAppIcon(widget.app.packageName);
    if (mounted) {
      setState(() {
        _iconBytes = bytes;
        _iconLoaded = true;
      });
    }
  }

  void _showKillSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131318),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),

            // App icon + name
            Row(
              children: [
                _AppIcon(iconBytes: _iconBytes, appName: widget.app.appName, size: 52),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.app.appName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.app.packageName,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B3B).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFF3B3B).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFFFF3B3B), size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '"Kill" stops background processes.\n"Force Stop" opens system settings for a permanent stop.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Cancel
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFF2A2A35)),
                  ),
                ),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.white54, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                // Kill background
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onKill?.call();
                    },
                    icon: const Icon(Icons.power_settings_new_rounded, size: 15),
                    label: const Text('Kill'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Force stop via system settings
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onForceStop?.call();
                    },
                    icon: const Icon(Icons.block_rounded, size: 15),
                    label: const Text('Force Stop'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3B3B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final isActive = app.isActive;
    final totalSpeed = app.rxBytesPerSec + app.txBytesPerSec;

    // Speed bar max = 5 MB/s for visual scaling
    final barFraction = (totalSpeed / (5 * 1024 * 1024)).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF131318),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive
              ? const Color(0xFFFF6B00).withOpacity(0.35)
              : const Color(0xFF1E1E26),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: isActive ? () => _showKillSheet(context) : null,
          splashColor: const Color(0xFFFF6B00).withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    // App icon
                    _AppIcon(
                      iconBytes: _iconBytes,
                      appName: app.appName,
                      size: 44,
                    ),
                    const SizedBox(width: 12),

                    // App name + speed labels
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  app.appName,
                                  style: TextStyle(
                                    color: isActive ? Colors.white : Colors.white60,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isActive) ...[
                                const SizedBox(width: 6),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF00FF87),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              _MiniSpeed(
                                icon: Icons.south_rounded,
                                speed: NetworkService.formatSpeed(app.rxBytesPerSec),
                                color: const Color(0xFF00C2FF),
                                active: app.rxBytesPerSec > 512,
                              ),
                              const SizedBox(width: 12),
                              _MiniSpeed(
                                icon: Icons.north_rounded,
                                speed: NetworkService.formatSpeed(app.txBytesPerSec),
                                color: const Color(0xFFFF6B00),
                                active: app.txBytesPerSec > 512,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Kill button or total bytes
                    if (isActive)
                      GestureDetector(
                        onTap: () => _showKillSheet(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B3B).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFFF3B3B).withOpacity(0.4),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.power_settings_new_rounded,
                                  color: Color(0xFFFF3B3B), size: 13),
                              SizedBox(width: 4),
                              Text(
                                'KILL',
                                style: TextStyle(
                                  color: Color(0xFFFF3B3B),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Text(
                        NetworkService.formatBytes(app.totalBytes),
                        style: const TextStyle(
                          color: Colors.white24,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),

                // Speed bar (only show if active)
                if (isActive && barFraction > 0.01) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: barFraction,
                      backgroundColor: const Color(0xFF1E1E26),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color.lerp(
                          const Color(0xFFFF6B00),
                          const Color(0xFFFF3B3B),
                          barFraction,
                        )!,
                      ),
                      minHeight: 3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── App icon widget ──────────────────────────────────────────────────────────
class _AppIcon extends StatelessWidget {
  final Uint8List? iconBytes;
  final String appName;
  final double size;

  const _AppIcon({
    required this.iconBytes,
    required this.appName,
    required this.size,
  });

  Color _color(String name) {
    final colors = [
      const Color(0xFFFF6B00),
      const Color(0xFF00C2FF),
      const Color(0xFF00FF87),
      const Color(0xFFFF3B3B),
      const Color(0xFFFFD60A),
      const Color(0xFFBF5AF2),
      const Color(0xFF30D158),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (iconBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.memory(
          iconBytes!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final color = _color(appName);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Center(
        child: Text(
          appName.isNotEmpty ? appName[0].toUpperCase() : '?',
          style: TextStyle(
            color: color,
            fontSize: size * 0.4,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ── Mini speed chip ──────────────────────────────────────────────────────────
class _MiniSpeed extends StatelessWidget {
  final IconData icon;
  final String speed;
  final Color color;
  final bool active;

  const _MiniSpeed({
    required this.icon,
    required this.speed,
    required this.color,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            color: active ? color : Colors.white24,
            size: 10),
        const SizedBox(width: 3),
        Text(
          speed,
          style: TextStyle(
            color: active ? color.withOpacity(0.9) : Colors.white24,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}