import 'package:flutter/material.dart';

/// Interactive Cosmic Knowledge Orb collected during flight.
class KnowledgeOrb {
  KnowledgeOrb({
    required this.symbol,
    required this.label,
    required this.xRatio,
    required this.y,
    required this.color,
  });

  final String symbol;
  final String label;
  final double xRatio; // 0.0 to 1.0 of screen width
  final Color color;
  double y; // pixels from top
  bool isCollected = false;
}

/// Dynamic particle emitted by rocket thrusters or explosions.
class FlightParticle {
  FlightParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.color,
    required this.maxLife,
  }) : life = maxLife;

  double x;
  double y;
  double vx;
  double vy;
  double radius;
  Color color;
  double life;
  final double maxLife;

  bool get isDead => life <= 0;
}

/// Floating score / popup text.
class FloatingScore {
  FloatingScore({
    required this.text,
    required this.x,
    required this.y,
    required this.color,
  });

  final String text;
  final double x;
  final Color color;
  double y;
  double opacity = 1;
}
