import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/dashboard/dashboard_layouts.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/dashboard/dashboard_shimmer_loading.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/welcome_walkthrough_dialog.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_guided_tour_overlay.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:kortex/src/shared/widgets/syllabot_avatar.dart';

@RoutePage()
class DashboardPage extends HookWidget {
  const DashboardPage({
    super.key,
    this.cramPlannerCubit,
    this.dashboardBloc,
    this.localStorageService,
  });

  final CramPlannerCubit? cramPlannerCubit;
  final DashboardBloc? dashboardBloc;
  final LocalStorageService? localStorageService;

  @override
  Widget build(BuildContext context) {
    final effectiveCramPlannerCubit =
        cramPlannerCubit ?? locator<CramPlannerCubit>();
    final effectiveDashboardBloc = dashboardBloc ?? locator<DashboardBloc>();
    final effectiveLocalStorage =
        localStorageService ?? locator<LocalStorageService>();

    useEffect(() {
      unawaited(effectiveCramPlannerCubit.loadExams());
      effectiveDashboardBloc.add(const DashboardStarted());
      return null;
    }, [effectiveCramPlannerCubit, effectiveDashboardBloc]);

    return MultiBlocProvider(
      providers: [
        BlocProvider<DashboardBloc>.value(
          value: effectiveDashboardBloc,
        ),
        BlocProvider<CramPlannerCubit>.value(
          value: effectiveCramPlannerCubit,
        ),
      ],
      child: _DashboardView(
        localStorageService: effectiveLocalStorage,
      ),
    );
  }
}

class _DashboardView extends HookWidget {
  const _DashboardView({
    required this.localStorageService,
  });

  final LocalStorageService localStorageService;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    final authState = context.watch<AuthBloc?>()?.state;
    final userName =
        authState?.userProfile?.displayName ?? authState?.user?.displayName;
    final userPhotoUrl =
        authState?.userProfile?.photoUrl ?? authState?.user?.photoUrl;
    final targetTrack = authState?.userProfile?.targetTrack;

    final confettiController = useMemoized(
      () => ConfettiController(duration: const Duration(seconds: 4)),
    );
    useEffect(() => confettiController.dispose, [confettiController]);

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final storage = localStorageService;
        final userId = authState?.userProfile?.id ?? authState?.user?.id ?? '';
        final userSeenKey = '${PrefKeys.hasSeenWelcomeWalkthrough}_$userId';
        final isNewlyRegistered =
            storage.getPreference(key: PrefKeys.isNewlyRegistered) == 'true';
        final hasSeenWelcome =
            (userId.isNotEmpty &&
                storage.getPreference(key: userSeenKey) == 'true') ||
            storage.getPreference(key: PrefKeys.hasSeenWelcomeWalkthrough) ==
                'true';

        // Welcome dialog should ONLY show to newly registered users who just created their account,
        // and never to users who already own an account and are logging back in.
        final shouldShowWelcome = isNewlyRegistered && !hasSeenWelcome;

        if (shouldShowWelcome && context.mounted) {
          confettiController.play();
          unawaited(
            showDialog<void>(
              context: context,
              builder: (_) => WelcomeWalkthroughDialog(
                onDismissed: () {
                  unawaited(
                    storage.savePreference(
                      key: PrefKeys.hasSeenWelcomeWalkthrough,
                      data: 'true',
                    ),
                  );
                  if (userId.isNotEmpty) {
                    unawaited(
                      storage.savePreference(
                        key: userSeenKey,
                        data: 'true',
                      ),
                    );
                  }
                  unawaited(
                    storage.savePreference(
                      key: PrefKeys.isNewlyRegistered,
                      data: 'false',
                    ),
                  );
                },
                onEnterWorkspace: () {
                  unawaited(
                    storage.savePreference(
                      key: PrefKeys.hasSeenWelcomeWalkthrough,
                      data: 'true',
                    ),
                  );
                  if (userId.isNotEmpty) {
                    unawaited(
                      storage.savePreference(
                        key: userSeenKey,
                        data: 'true',
                      ),
                    );
                  }
                  unawaited(
                    storage.savePreference(
                      key: PrefKeys.isNewlyRegistered,
                      data: 'false',
                    ),
                  );
                  if (context.mounted) {
                    unawaited(AppGuidedTourOverlay.start(context));
                  }
                },
              ),
            ),
          );
        } else if (!hasSeenWelcome) {
          unawaited(
            storage.savePreference(
              key: PrefKeys.hasSeenWelcomeWalkthrough,
              data: 'true',
            ),
          );
          if (userId.isNotEmpty) {
            unawaited(
              storage.savePreference(
                key: userSeenKey,
                data: 'true',
              ),
            );
          }
        }

        final profileTrack = authState?.userProfile?.targetTrack;
        final effectiveTrack =
            (profileTrack != null && profileTrack.trim().isNotEmpty)
                ? profileTrack.trim()
                : (targetTrack != null && targetTrack.trim().isNotEmpty
                    ? targetTrack.trim()
                    : '');
        final hasTrack = effectiveTrack.isNotEmpty;

        if (hasTrack && userId.isNotEmpty) {
          final promptKey = 'prompted_track_$userId';
          unawaited(storage.savePreference(key: promptKey, data: 'true'));
        }
      });
      return null;
    }, [
      authState?.status,
      authState?.userProfile?.targetTrack,
      targetTrack,
      localStorageService,
    ]);

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            bottom: false,
            child: BlocBuilder<DashboardBloc, DashboardState>(
              builder: (context, state) {
                // Show full shimmer only on genuine cold-start loading (no
                // cached data available). Stale-while-revalidate keeps
                // existing content visible during background refresh.
                if (state.isLoading && !state.hasDisplayableFeed) {
                  return const DashboardShimmerLoading();
                }

                if (state.isError || state.displayFeed == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SyllabotAvatar(size: 48, isError: true),
                          const SizedBox(height: 16),
                          Text(
                            l10n.dashboardUnableToLoad,
                            style: typography.title3.bold.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            state.errorMessage ?? l10n.dashboardConnectionError,
                            textAlign: TextAlign.center,
                            style: typography.footnote.regular.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ShrinkableButton(
                            onTap: () {
                              context.read<DashboardBloc>().add(
                                    const DashboardStarted(),
                                  );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                l10n.dashboardRetry,
                                style: typography.caption.bold.copyWith(
                                  color: colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final feed = state.displayFeed!;

                return RefreshIndicator(
                  onRefresh: () async {
                    final completer = Completer<void>();
                    context.read<DashboardBloc>().add(
                          const DashboardRefreshed(),
                        );
                    Timer(
                      const Duration(milliseconds: 600),
                      completer.complete,
                    );
                    return completer.future;
                  },
                  color: colors.primary,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isExpanded = constraints.maxWidth >= 1024;
                      final isMedium =
                          constraints.maxWidth >= 600 && !isExpanded;

                      if (isExpanded) {
                        return DashboardExpandedLayout(
                          feed: feed,
                          userName: userName,
                          userPhotoUrl: userPhotoUrl,
                          targetTrack: targetTrack,
                        );
                      } else if (isMedium) {
                        return DashboardMediumLayout(
                          feed: feed,
                          userName: userName,
                          userPhotoUrl: userPhotoUrl,
                          targetTrack: targetTrack,
                        );
                      } else {
                        return DashboardCompactLayout(
                          feed: feed,
                          userName: userName,
                          userPhotoUrl: userPhotoUrl,
                          targetTrack: targetTrack,
                        );
                      }
                    },
                  ),
                );
              },
            ),
          ),
          // Confetti celebration overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 45,
              emissionFrequency: 0.05,
              maxBlastForce: 25,
              minBlastForce: 10,
              gravity: 0.25,
              colors: [
                colors.primary,
                colors.syllabotAccent,
                colors.warning,
                colors.success,
                colors.surfaceBorderHighlight,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
