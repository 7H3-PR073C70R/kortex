import 'package:equatable/equatable.dart';

abstract class DecksEvent extends Equatable {
  const DecksEvent();

  @override
  List<Object?> get props => [];
}

class DecksStarted extends DecksEvent {
  const DecksStarted();
}

class DecksRefreshed extends DecksEvent {
  const DecksRefreshed();
}

class DecksFilterChanged extends DecksEvent {
  const DecksFilterChanged(this.filter);

  final String filter;

  @override
  List<Object?> get props => [filter];
}

class DecksSearchQueryChanged extends DecksEvent {
  const DecksSearchQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}
