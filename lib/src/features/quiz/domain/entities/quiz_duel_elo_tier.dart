import 'package:flutter/material.dart';

/// ELO Division Tiers for 1v1 Quiz Duels (Bronze to Grandmaster & Legend).
enum QuizDuelEloTier {
  bronze,
  silver,
  gold,
  platinum,
  diamond,
  grandmaster,
  legend;

  static QuizDuelEloTier fromElo(int elo) {
    if (elo >= 2100) return QuizDuelEloTier.legend;
    if (elo >= 1900) return QuizDuelEloTier.grandmaster;
    if (elo >= 1700) return QuizDuelEloTier.diamond;
    if (elo >= 1500) return QuizDuelEloTier.platinum;
    if (elo >= 1300) return QuizDuelEloTier.gold;
    if (elo >= 1100) return QuizDuelEloTier.silver;
    return QuizDuelEloTier.bronze;
  }

  String get label {
    switch (this) {
      case QuizDuelEloTier.bronze:
        return '🥉 Bronze Scholar';
      case QuizDuelEloTier.silver:
        return '🥈 Silver Duelist';
      case QuizDuelEloTier.gold:
        return '🥇 Gold Strategist';
      case QuizDuelEloTier.platinum:
        return '💎 Platinum Master';
      case QuizDuelEloTier.diamond:
        return '👑 Diamond Polymath';
      case QuizDuelEloTier.grandmaster:
        return '⚔️ Grandmaster Apex';
      case QuizDuelEloTier.legend:
        return '⚡ Scholar Legend';
    }
  }

  Color get color {
    switch (this) {
      case QuizDuelEloTier.bronze:
        return const Color(0xFFCD7F32);
      case QuizDuelEloTier.silver:
        return const Color(0xFFC0C0C0);
      case QuizDuelEloTier.gold:
        return const Color(0xFFFFD700);
      case QuizDuelEloTier.platinum:
        return const Color(0xFFE5E4E2);
      case QuizDuelEloTier.diamond:
        return const Color(0xFF00BFFF);
      case QuizDuelEloTier.grandmaster:
        return const Color(0xFFA855F7);
      case QuizDuelEloTier.legend:
        return const Color(0xFFFF4500);
    }
  }

  int get seasonalRewardXp {
    switch (this) {
      case QuizDuelEloTier.bronze:
        return 100;
      case QuizDuelEloTier.silver:
        return 250;
      case QuizDuelEloTier.gold:
        return 500;
      case QuizDuelEloTier.platinum:
        return 1000;
      case QuizDuelEloTier.diamond:
        return 2000;
      case QuizDuelEloTier.grandmaster:
        return 3500;
      case QuizDuelEloTier.legend:
        return 5000;
    }
  }

  String get seasonalTitleReward {
    switch (this) {
      case QuizDuelEloTier.bronze:
        return 'Bronze Competitor Badge';
      case QuizDuelEloTier.silver:
        return 'Silver Scholar Emblem';
      case QuizDuelEloTier.gold:
        return 'Gold Quiz Master Frame';
      case QuizDuelEloTier.platinum:
        return 'Platinum Neural Crown';
      case QuizDuelEloTier.diamond:
        return 'Diamond Polymath Insignia';
      case QuizDuelEloTier.grandmaster:
        return 'Grandmaster Apex Aura';
      case QuizDuelEloTier.legend:
        return 'Legendary Celestial Crest';
    }
  }
}
