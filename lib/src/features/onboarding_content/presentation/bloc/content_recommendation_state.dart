import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/onboarding_content/domain/entities/recommended_content_item.dart';

enum ContentRecommendationStatus {
  initial,
  loading,
  loaded,
  error,
}

class ContentRecommendationState extends Equatable {
  const ContentRecommendationState({
    this.status = ContentRecommendationStatus.initial,
    this.items = const [],
    this.currentIndex = 0,
    this.errorMessage,
  });

  final ContentRecommendationStatus status;
  final List<RecommendedContentItem> items;
  final int currentIndex;
  final String? errorMessage;

  bool get isLoading => status == ContentRecommendationStatus.loading;
  bool get isLastPage => items.isNotEmpty && currentIndex == items.length - 1;

  ContentRecommendationState copyWith({
    ContentRecommendationStatus? status,
    List<RecommendedContentItem>? items,
    int? currentIndex,
    String? errorMessage,
  }) {
    return ContentRecommendationState(
      status: status ?? this.status,
      items: items ?? this.items,
      currentIndex: currentIndex ?? this.currentIndex,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        items,
        currentIndex,
        errorMessage,
      ];
}
