// lib/widgets/app_network_tile.dart

import 'package:flutter/material.dart';
import '../models/app_network_info.dart';
import '../services/network_service.dart';

class AppNetworkTile extends StatefulWidget {
  final AppNetworkInfo app;
  final VoidCallback? onKill;

  const AppNetworkTile({super.key, required this.app, this.onKill});

  @override
  State<AppNetworkTile> createState() => _AppNetworkTileState();
}

class _AppNetworkTileState extends State<AppNetworkTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _pulse = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    if (widget.app.isActive) {
      _pulseCtrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AppNetworkTile old) {
    super.didUpdateWidget(old);
    if (widget.app.isActive && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!widget.app.isActive && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
      _pulseCtrl.value = 0.8;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _confirmKill(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF6B35), size: 48),
            const SizedBox(height: 12),
            Text(
              'Stop ${widget.app.appName}?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This will kill background processes for this app.\nIt may restart automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF1E3A5F)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.white70)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onKill?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3B3B),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Kill App',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final isActive = app.isActive;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? const Color(0xFF00D4FF).withOpacity(0.3)
              : const Color(0xFF1E3A5F),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isActive ? () => _confirmKill(context) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Active pulse dot
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? Color.lerp(
                              const Color(0xFF00D4FF),
                              const Color(0xFFFF6B35),
                              _pulse.value,
                            )!
                          : const Color(0xFF1E3A5F),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // App icon placeholder (initials)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _appColor(app.packageName).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _appColor(app.packageName).withOpacity(0.3),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      app.appName.isNotEmpty
                          ? app.appName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: _appColor(app.packageName),
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // App name + speeds
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.appName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _SpeedChip(
                            icon: Icons.arrow_downward_rounded,
                            speed: NetworkService.formatSpeed(app.rxBytesPerSec),
                            color: const Color(0xFF00D4FF),
                          ),
                          const SizedBox(width: 8),
                          _SpeedChip(
                            icon: Icons.arrow_upward_rounded,
                            speed: NetworkService.formatSpeed(app.txBytesPerSec),
                            color: const Color(0xFF7C4DFF),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Kill button (only for active apps)
                if (isActive)
                  GestureDetector(
                    onTap: () => _confirmKill(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B3B).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFFF3B3B).withOpacity(0.5),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stop_circle_outlined,
                              color: Color(0xFFFF3B3B), size: 14),
                          SizedBox(width: 4),
                          Text(
                            'KILL',
                            style: TextStyle(
                              color: Color(0xFFFF3B3B),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _appColor(String packageName) {
    final colors = [
      const Color(0xFF00D4FF),
      const Color(0xFF7C4DFF),
      const Color(0xFF00E676),
      const Color(0xFFFF6B35),
      const Color(0xFFFFD600),
      const Color(0xFFFF4081),
    ];
    return colors[packageName.hashCode.abs() % colors.length];
  }
}

class _SpeedChip extends StatelessWidget {
  final IconData icon;
  final String speed;
  final Color color;

  const _SpeedChip({
    required this.icon,
    required this.speed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color.withOpacity(0.7), size: 10),
        const SizedBox(width: 2),
        Text(
          speed,
          style: TextStyle(
            color: color.withOpacity(0.85),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}