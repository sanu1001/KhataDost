import 'package:equatable/equatable.dart';
import '../../domain/entities/dashboard_summary.dart';

/// What "phase" the dashboard is in right now.
enum DashboardStatus { initial, loading, loaded, error }

/// Single state class — no sealed variants.
/// Every variable the BLoC / UI needs lives here.
/// The BLoC emits copies via copyWith() to update individual fields.
class DashboardState extends Equatable {
  const DashboardState({
    this.status = DashboardStatus.initial,
    this.summary,
    this.errorMessage,
  });

  final DashboardStatus status;

  /// Non-null when status == loaded.
  /// Stays populated across refetches so the UI never flashes empty.
  final DashboardSummary? summary;

  /// Non-null when status == error.
  final String? errorMessage;

  // ── Convenience getters ────────────────────────────────────────────────────

  bool get isInitial => status == DashboardStatus.initial;
  bool get isLoading => status == DashboardStatus.loading;
  bool get isLoaded => status == DashboardStatus.loaded;
  bool get hasError => status == DashboardStatus.error;

  // ── Immutable update ───────────────────────────────────────────────────────

  DashboardState copyWith({
    DashboardStatus? status,
    DashboardSummary? summary,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DashboardState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, summary, errorMessage];
}
