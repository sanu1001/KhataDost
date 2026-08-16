import 'package:equatable/equatable.dart';

/// Events are just definitions — no logic, no state.
/// The BLoC handles what actually happens when each event fires.
sealed class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

/// Fired when the Settings page opens (and on Retry after a failure).
/// Triggers GET /v1/me.
final class LoadProfile extends SettingsEvent {
  const LoadProfile();
}
