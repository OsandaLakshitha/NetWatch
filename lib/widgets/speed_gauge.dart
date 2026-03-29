// lib/widgets/speed_gauge.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';

class SpeedGauge extends StatefulWidget {
  final int rxBytesPerSec;
  final int txBytesPerSec;
  final bool isWifi;

  const SpeedGauge({
    super.key,
    required this.rxBytesPerSec,
    required this.txBytesPerSec,
    required this.isWifi,
  });

  @override
  State<SpeedGauge> createState() => _SpeedGaugeState();
}

class _SpeedGaugeState extends State<SpeedGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  String _val(int bps) {
    if (bps < 1024) return bps.toString();
    if (bps < 1024 * 1024) return (bps / 1024).toStringAsFixed(1);
    return (bps / (1024 * 1024)).toStringAsFixed(2);
  }

  String _unit(int bps) {
    if (bps < 1024) return 'B/s';
    if (bps < 1024 * 1024) return 'KB/s';
    return 'MB/s';
  }

  @override
  Widget build(BuildContext context) {
    final bool hasActivity = widget.rxBytesPerSec > 512 || widget.txBytesPerSec > 512;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131318),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: hasActivity
              ? const Color(0xFFFF6B00).withOpacity(0.4)
              : const Color(0xFF2A2A35),
          width: 1.5,
        ),
        boxShadow: hasActivity
            ? [
                BoxShadow(
                  color: const Color(0xFFFF6B00).withOpacity(0.12),
                  blurRadius: 32,
                  spreadRadius: 0,
                ),
              ]
            : [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Connection badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: widget.isWifi
                        ? const Color(0xFF00C2FF).withOpacity(0.1)
                        : const Color(0xFFFF6B00).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: widget.isWifi
                          ? const Color(0xFF00C2FF).withOpacity(0.3)
                          : const Color(0xFFFF6B00).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.isWifi
                            ? Icons.wifi_rounded
                            : Icons.signal_cellular_alt_rounded,
                        color: widget.isWifi
                            ? const Color(0xFF00C2FF)
                            : const Color(0xFFFF6B00),
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        widget.isWifi ? 'Wi-Fi' : 'Mobile Data',
                        style: TextStyle(
                          color: widget.isWifi
                              ? const Color(0xFF00C2FF)
                              : const Color(0xFFFF6B00),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                // Live dot
                if (hasActivity)
                  AnimatedBuilder(
                    animation: _shimmer,
                    builder: (_, __) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF87).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color.fromRGBO(
                                0, 255, 135,
                                0.5 + 0.5 * math.sin(_shimmer.value * 2 * math.pi),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'ACTIVE',
                            style: TextStyle(
                              color: Color(0xFF00FF87),
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

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: _SpeedBlock(
                    label: 'DOWNLOAD',
                    icon: Icons.south_rounded,
                    value: _val(widget.rxBytesPerSec),
                    unit: _unit(widget.rxBytesPerSec),
                    color: const Color(0xFF00C2FF),
                    bps: widget.rxBytesPerSec,
                  ),
                ),
                Container(
                  width: 1,
                  height: 64,
                  color: const Color(0xFF2A2A35),
                ),
                Expanded(
                  child: _SpeedBlock(
                    label: 'UPLOAD',
                    icon: Icons.north_rounded,
                    value: _val(widget.txBytesPerSec),
                    unit: _unit(widget.txBytesPerSec),
                    color: const Color(0xFFFF6B00),
                    bps: widget.txBytesPerSec,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedBlock extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final String unit;
  final Color color;
  final int bps;

  const _SpeedBlock({
    required this.label,
    required this.icon,
    required this.value,
    required this.unit,
    required this.color,
    required this.bps,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color.withOpacity(0.6), size: 12),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.6),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  color: bps > 512 ? color : Colors.white38,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  height: 1,
                ),
              ),
              TextSpan(
                text: '\n$unit',
                style: TextStyle(
                  color: bps > 512 ? color.withOpacity(0.6) : Colors.white24,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}