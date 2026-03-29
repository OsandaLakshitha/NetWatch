// lib/widgets/speed_gauge.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';

class SpeedGauge extends StatelessWidget {
  final int rxBytesPerSec;
  final int txBytesPerSec;
  final bool isWifi;

  const SpeedGauge({
    super.key,
    required this.rxBytesPerSec,
    required this.txBytesPerSec,
    required this.isWifi,
  });

  String _format(int bps) {
    if (bps < 1024) return '${bps}\nB/s';
    if (bps < 1024 * 1024) return '${(bps / 1024).toStringAsFixed(1)}\nKB/s';
    return '${(bps / (1024 * 1024)).toStringAsFixed(2)}\nMB/s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E3A5F), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D4FF).withOpacity(0.08),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Connection type badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isWifi ? Icons.wifi : Icons.signal_cellular_alt,
                color: isWifi ? const Color(0xFF00D4FF) : const Color(0xFFFF6B35),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                isWifi ? 'Wi-Fi Connected' : 'Mobile Data',
                style: TextStyle(
                  color: isWifi ? const Color(0xFF00D4FF) : const Color(0xFFFF6B35),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Speed row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _SpeedIndicator(
                label: 'DOWNLOAD',
                icon: Icons.arrow_downward_rounded,
                bytesPerSec: rxBytesPerSec,
                color: const Color(0xFF00D4FF),
              ),
              Container(
                width: 1,
                height: 60,
                color: const Color(0xFF1E3A5F),
              ),
              _SpeedIndicator(
                label: 'UPLOAD',
                icon: Icons.arrow_upward_rounded,
                bytesPerSec: txBytesPerSec,
                color: const Color(0xFF7C4DFF),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpeedIndicator extends StatelessWidget {
  final String label;
  final IconData icon;
  final int bytesPerSec;
  final Color color;

  const _SpeedIndicator({
    required this.label,
    required this.icon,
    required this.bytesPerSec,
    required this.color,
  });

  String get _value {
    if (bytesPerSec < 1024) return bytesPerSec.toString();
    if (bytesPerSec < 1024 * 1024) return (bytesPerSec / 1024).toStringAsFixed(1);
    return (bytesPerSec / (1024 * 1024)).toStringAsFixed(2);
  }

  String get _unit {
    if (bytesPerSec < 1024) return 'B/s';
    if (bytesPerSec < 1024 * 1024) return 'KB/s';
    return 'MB/s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: _value,
                style: TextStyle(
                  color: color,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              TextSpan(
                text: '\n$_unit',
                style: TextStyle(
                  color: color.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}