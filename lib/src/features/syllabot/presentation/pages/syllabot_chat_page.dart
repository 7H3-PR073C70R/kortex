import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/services/device_capability_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/utils/uuid_utils.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/repositories/calibration_repository.dart';
import 'package:kortex/src/features/syllabot/data/client/local_llm_engine_client.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_bloc.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_event.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/chat/syllabot_chat_action_coordinator.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/chat/syllabot_chat_view.dart';

/// Interactive conversation page with Syllabot AI.
@RoutePage()
class SyllabotChatPage extends HookWidget {
  const SyllabotChatPage({
    this.initialPrompt,
    this.initialMode,
    this.onCollapse,
    this.chatBloc,
    this.actionCoordinator,
    this.calibrationRepository,
    this.subscriptionGuard,
    this.localLlmEngineClient,
    this.deviceCapabilityService,
    this.localStorageService,
    this.communityRepository,
    super.key,
  });

  final String? initialPrompt;
  final SocraticMode? initialMode;
  final VoidCallback? onCollapse;
  final SyllabotChatBloc? chatBloc;
  final SyllabotChatActionCoordinator? actionCoordinator;
  final CalibrationRepository? calibrationRepository;
  final SubscriptionGuard? subscriptionGuard;
  final LocalLlmEngineClient? localLlmEngineClient;
  final DeviceCapabilityService? deviceCapabilityService;
  final LocalStorageService? localStorageService;
  final CommunityRepository? communityRepository;

  @override
  Widget build(BuildContext context) {
    final effectiveBloc = chatBloc ??
        useMemoized(() {
          return locator.isRegistered<SyllabotChatBloc>()
              ? locator<SyllabotChatBloc>()
              : null;
        });

    useEffect(() {
      if (effectiveBloc != null &&
          initialPrompt != null &&
          initialPrompt!.trim().isNotEmpty) {
        final sid = UuidUtils.generate();
        effectiveBloc.add(
          SubmitPromptEvent(
            prompt: initialPrompt!.trim(),
            sessionId: sid,
            socraticMode: initialMode ?? effectiveBloc.state.socraticMode,
            engineType: ExecutionEngineType.cloudRemote,
          ),
        );
      }
      return null;
    }, const []);

    final view = SyllabotChatView(
      initialPrompt: initialPrompt,
      onCollapse: onCollapse,
      actionCoordinator: actionCoordinator,
      calibrationRepository: calibrationRepository,
      subscriptionGuard: subscriptionGuard,
      localLlmEngineClient: localLlmEngineClient,
      deviceCapabilityService: deviceCapabilityService,
      localStorageService: localStorageService,
      communityRepository: communityRepository,
    );

    if (effectiveBloc != null) {
      return BlocProvider<SyllabotChatBloc>.value(
        value: effectiveBloc,
        child: view,
      );
    }

    return view;
  }
}
