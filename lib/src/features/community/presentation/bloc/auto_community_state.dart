import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/community/domain/entities/study_community_entity.dart';

enum AutoCommunityStatus { initial, provisioning, provisioned, error }

class AutoCommunityState extends Equatable {
  const AutoCommunityState({
    this.status = AutoCommunityStatus.initial,
    this.community,
    this.isBannerDismissed = false,
    this.errorMessage,
  });

  final AutoCommunityStatus status;
  final StudyCommunityEntity? community;
  final bool isBannerDismissed;
  final String? errorMessage;

  bool get shouldShowBanner =>
      status == AutoCommunityStatus.provisioned &&
      community != null &&
      !isBannerDismissed;

  AutoCommunityState copyWith({
    AutoCommunityStatus? status,
    StudyCommunityEntity? community,
    bool? isBannerDismissed,
    String? errorMessage,
  }) {
    return AutoCommunityState(
      status: status ?? this.status,
      community: community ?? this.community,
      isBannerDismissed: isBannerDismissed ?? this.isBannerDismissed,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        community,
        isBannerDismissed,
        errorMessage,
      ];
}
