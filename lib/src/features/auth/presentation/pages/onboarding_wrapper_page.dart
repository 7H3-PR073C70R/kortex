import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/domain/use_cases/complete_onboarding_use_case.dart';
import 'package:kortex/src/features/auth/presentation/bloc/chat_onboarding_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/onboarding_cubit.dart';
import 'package:kortex/src/features/auth/presentation/pages/conversational_onboarding_page.dart';
import 'package:kortex/src/features/auth/presentation/pages/traditional_form_onboarding_page.dart';
import 'package:kortex/src/features/auth/presentation/widgets/onboarding_mode_toggle_bar.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';

@RoutePage()
class OnboardingWrapperPage extends StatelessWidget {
  const OnboardingWrapperPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => OnboardingCubit(
            completeOnboardingUseCase: locator<CompleteOnboardingUseCase>(),
          ),
        ),
        BlocProvider(
          create: (context) => ChatOnboardingBloc(),
        ),
      ],
      child: const _OnboardingWrapperView(),
    );
  }
}

class _OnboardingWrapperView extends StatelessWidget {
  const _OnboardingWrapperView();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    return BlocConsumer<OnboardingCubit, OnboardingState>(
      listener: (context, state) {
        if (state.isCompleted) {
          // Synchronize Dashboard Bloc
          locator<DashboardBloc>().add(const DashboardStarted());
          unawaited(context.router.replace(const MainRoute()));
        } else if (state.status == OnboardingStatus.error &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: colors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<OnboardingCubit>();

        return Scaffold(
          backgroundColor:
              isDark ? colors.backgroundPrimary : colors.surfacePrimary,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('Kortex Onboarding'),
            centerTitle: true,
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 1024;

              if (isDesktop) {
                // Desktop Split View
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Row(
                      children: [
                        // Left: Conversational AI Chat View
                        Expanded(
                          flex: 3,
                          child: Container(
                            margin: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? colors.surfaceSecondary
                                  : colors.surfacePrimary,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color:
                                    colors.primary.withAlpha(isDark ? 40 : 20),
                              ),
                            ),
                            child: const ConversationalOnboardingPage(),
                          ),
                        ),

                        // Right: Form Preview / Stepper
                        Expanded(
                          flex: 2,
                          child: Container(
                            margin: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? colors.surfaceSecondary
                                  : colors.surfacePrimary,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color:
                                    colors.primary.withAlpha(isDark ? 40 : 20),
                              ),
                            ),
                            child: const TraditionalFormOnboardingPage(),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Mobile & Tablet Single-View with Mode Switcher
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    children: [
                      OnboardingModeToggleBar(
                        activeMode: state.activeMode,
                        onModeChanged: cubit.setMode,
                      ),
                      Expanded(
                        child: state.activeMode == OnboardingMode.chat
                            ? const ConversationalOnboardingPage()
                            : const TraditionalFormOnboardingPage(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
