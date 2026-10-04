import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HubOverviewState extends Equatable {
  const HubOverviewState({
    this.activeTabIndex = 0,
    this.selectedTrack = 'All',
    this.isSearchExpanded = false,
    this.searchQuery = '',
  });

  final int activeTabIndex;
  final String selectedTrack;
  final bool isSearchExpanded;
  final String searchQuery;

  HubOverviewState copyWith({
    int? activeTabIndex,
    String? selectedTrack,
    bool? isSearchExpanded,
    String? searchQuery,
  }) {
    return HubOverviewState(
      activeTabIndex: activeTabIndex ?? this.activeTabIndex,
      selectedTrack: selectedTrack ?? this.selectedTrack,
      isSearchExpanded: isSearchExpanded ?? this.isSearchExpanded,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [
        activeTabIndex,
        selectedTrack,
        isSearchExpanded,
        searchQuery,
      ];
}

class HubOverviewCubit extends Cubit<HubOverviewState> {
  HubOverviewCubit() : super(const HubOverviewState());

  void setTab(int index) => emit(state.copyWith(activeTabIndex: index));
  void setTrack(String track) => emit(state.copyWith(selectedTrack: track));
  void toggleSearch({required bool expanded}) => emit(state.copyWith(isSearchExpanded: expanded));
  void updateSearchQuery(String query) => emit(state.copyWith(searchQuery: query));
}
