import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_elo_tier.dart';
import 'package:kortex/src/features/quiz/domain/repositories/quiz_duel_repository.dart';

/// Modal bottom sheet showcasing ELO Leaderboards, Division Tiers, and Rankings (QZ-13).
class QuizDuelLeaderboardSheet extends HookWidget {
  const QuizDuelLeaderboardSheet({super.key});

  static Future<void> show(BuildContext context) {
    final colors = context.colors;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.transparent,
      builder: (_) => const QuizDuelLeaderboardSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final repo = locator<QuizDuelRepository>();
    final authBloc = locator.isRegistered<AuthBloc>() ? locator<AuthBloc>() : null;
    final currentUser = authBloc?.state.userProfile;
    final userElo = currentUser?.eloRating ?? 1250;
    final userTier = QuizDuelEloTier.fromElo(userElo);

    final selectedSubject = useState<String>('All');
    final leaderboardState = useState<AsyncSnapshot<List<Map<String, dynamic>>>>(
      const AsyncSnapshot.waiting(),
    );

    void fetchLeaderboard() {
      leaderboardState.value = const AsyncSnapshot.waiting();
      repo
          .getEloLeaderboard(
            subject: selectedSubject.value == 'All' ? null : selectedSubject.value,
            limit: 25,
          )
          .then((res) {
        res.fold(
          (failure) {
            leaderboardState.value = AsyncSnapshot.withError(
              ConnectionState.done,
              failure.message ?? 'Error fetching rankings',
            );
          },
          (data) {
            leaderboardState.value = AsyncSnapshot.withData(
              ConnectionState.done,
              data,
            );
          },
        );
      });
    }

    useEffect(() {
      fetchLeaderboard();
      return null;
    }, [selectedSubject.value]);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.dialog),
        ),
        border: Border.all(
          color: colors.surfaceBorder.withValues(alpha: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.micro),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sheet Title Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '🏆',
                      style: typography.title1.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quiz Duel Leaderboard',
                          style: typography.title2.bold.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'ELO Ratings & Division Tiers',
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // User Tier Banner Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      userTier.color.withValues(alpha: 0.2),
                      colors.primary.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: userTier.color.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: userTier.color.withValues(alpha: 0.2),
                      child: Text(
                        userTier.label.characters.first,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentUser?.displayName ?? 'Scholar Duelist',
                            style: typography.title3.bold.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: userTier.color,
                                  borderRadius: BorderRadius.circular(AppRadius.micro),
                                ),
                                child: Text(
                                  userTier.label,
                                  style: typography.caption.bold.copyWith(
                                    color: colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$userElo ELO',
                                style: typography.caption.bold.copyWith(
                                  color: colors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Subject Filter Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  'All',
                  'Mathematics',
                  'Physics',
                  'Chemistry',
                  'Biology',
                  'Literature',
                  'Economics',
                ].map((subject) {
                  final isSelected = selectedSubject.value == subject;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(subject),
                      selected: isSelected,
                      onSelected: (_) => selectedSubject.value = subject,
                      selectedColor: colors.primary,
                      backgroundColor: colors.surfaceSecondary,
                      labelStyle: typography.caption.bold.copyWith(
                        color: isSelected ? colors.white : colors.textSecondary,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: colors.surfaceBorder),

            // Leaderboard List
            Expanded(
              child: leaderboardState.value.connectionState == ConnectionState.waiting
                  ? Center(
                      child: CircularProgressIndicator(color: colors.primary),
                    )
                  : leaderboardState.value.hasError
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '🔥',
                                  style: typography.title1.bold,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Rankings will populate as duels finish!',
                                  style: typography.body.regular.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : _buildLeaderboardList(
                          context,
                          leaderboardState.value.data ?? [],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardList(
    BuildContext context,
    List<Map<String, dynamic>> items,
  ) {
    final colors = context.colors;
    final typography = context.typography;

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '⚔️',
                style: typography.title1.bold,
              ),
              const SizedBox(height: 12),
              Text(
                'Be the first to claim the top rank!',
                style: typography.title3.bold.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Play 1v1 duels to earn ELO rating points.',
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final rank = index + 1;
        final name = item['display_name'] as String? ?? 'Scholar Duelist';
        final avatar = item['avatar_url'] as String? ?? '';
        final elo = item['elo_rating'] as int? ?? 1200;
        final tier = QuizDuelEloTier.fromElo(elo);

        Widget rankWidget;
        if (rank == 1) {
          rankWidget = const Text('🥇', style: TextStyle(fontSize: 22));
        } else if (rank == 2) {
          rankWidget = const Text('🥈', style: TextStyle(fontSize: 22));
        } else if (rank == 3) {
          rankWidget = const Text('🥉', style: TextStyle(fontSize: 22));
        } else {
          rankWidget = Text(
            '#$rank',
            style: typography.caption.bold.copyWith(
              color: colors.textSecondary,
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: rank <= 3
                ? tier.color.withValues(alpha: 0.08)
                : colors.surfaceSecondary,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: rank <= 3
                  ? tier.color.withValues(alpha: 0.3)
                  : colors.surfaceBorder.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Center(child: rankWidget),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 18,
                backgroundColor: tier.color.withValues(alpha: 0.2),
                child: Text(
                  avatar.isNotEmpty ? avatar : tier.label.characters.first,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: typography.body.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      tier.label,
                      style: typography.caption.bold.copyWith(
                        color: tier.color,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.micro),
                ),
                child: Text(
                  '$elo ELO',
                  style: typography.caption.bold.copyWith(
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
