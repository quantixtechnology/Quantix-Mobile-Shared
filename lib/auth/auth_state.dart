import 'user_model.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final bool isRestoring;
  final String? error;
  final UserModel? user;
  final String? pendingEmail;
  final String? devOtp;
  final bool needsPasswordCreation;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.isRestoring = true,
    this.error,
    this.user,
    this.pendingEmail,
    this.devOtp,
    this.needsPasswordCreation = false,
  });

  bool get requiresOtp => pendingEmail != null && !isAuthenticated;

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    bool? isRestoring,
    String? error,
    bool clearError = false,
    UserModel? user,
    String? pendingEmail,
    bool clearPendingEmail = false,
    String? devOtp,
    bool clearDevOtp = false,
    bool? needsPasswordCreation,
  }) =>
      AuthState(
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        isLoading: isLoading ?? this.isLoading,
        isRestoring: isRestoring ?? this.isRestoring,
        error: clearError ? null : (error ?? this.error),
        user: user ?? this.user,
        pendingEmail: clearPendingEmail ? null : (pendingEmail ?? this.pendingEmail),
        devOtp: clearDevOtp ? null : (devOtp ?? this.devOtp),
        needsPasswordCreation: needsPasswordCreation ?? this.needsPasswordCreation,
      );
}
