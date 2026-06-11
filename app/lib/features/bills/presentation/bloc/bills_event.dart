part of 'bills_bloc.dart';

abstract class BillsEvent extends Equatable {
  const BillsEvent();

  @override
  List<Object?> get props => [];
}

/// Fired on tab focus, pull-to-refresh, and after a successful settle.
class BillsLoadRequested extends BillsEvent {
  const BillsLoadRequested();
}
