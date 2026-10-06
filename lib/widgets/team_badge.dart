import 'package:flutter/material.dart';

import '../core/bracket/bracket_engine.dart';

const teamPalette = <Color>[
  Color(0xFF2F6BFF),
  Color(0xFF7C3AED),
  Color(0xFFFF7A1A),
  Color(0xFF111827),
  Color(0xFF16A34A),
  Color(0xFFDB2777),
  Color(0xFF0891B2),
  Color(0xFFCA8A04),
];

class TeamBadge extends StatelessWidget {
  final Team? team;
  final double size;

  const TeamBadge({super.key, required this.team, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final color = team == null
        ? const Color(0xFFE5E7EB)
        : teamPalette[team!.color % teamPalette.length];
    final letter = team?.initial ?? '?';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        letter,
        style: TextStyle(
          color: team == null ? const Color(0xFF9CA3AF) : Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.38,
        ),
      ),
    );
  }
}
