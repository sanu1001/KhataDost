import 'package:equatable/equatable.dart';

/// Events are just definitions — no logic, no state.
/// The BLoC handles what actually happens when each event fires.
sealed class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

/// Fired when the user lands on the dashboard or switches to the Home tab.
/// Triggers a fresh fetch of today's sales + recent bills.
final class DashboardLoadRequested extends DashboardEvent {
  const DashboardLoadRequested();
}
