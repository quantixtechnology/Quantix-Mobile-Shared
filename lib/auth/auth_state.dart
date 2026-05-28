import 'user_model.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final bool isRestoring;
  final String? error;
  final UserModel? user;
  final String? pendingSessionToken;
  final String? pendingEmail;
  final String? devOtp;
  // True immediately after a first-time OTP login where user has no password yet
  final bool needsPasswordCreation;
  // Used during forgot-password flow
  final String? forgotPasswordResetToken;
  final bool isForgotPasswordFlow;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.isRestoring = true,
    this.error,
    this.user,
    this.pendingSessionToken,
    this.pendingEmail,
    this.devOtp,
    this.needsPasswordCreation = false,
    this.forgotPasswordResetToken,
    this.isForgotPasswordFlow = false,
  });

  bool get requiresOtp => pendingEmail != null && !isAuthenticated && !isForgotPasswordFlow;

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    bool? isRestoring,
    String? error,
    bool clearError = false,
    UserModel? user,
    String? pendingSessionToken,
    bool clearPendingSession = false,
    String? pendingEmail,
    bool clearPendingEmail = false,
    String? devOtp,
    bool clearDevOtp = false,
    bool? needsPasswordCreation,
    String? forgotPasswordResetToken,
    bool clearForgotPasswordResetToken = false,
    bool? isForgotPasswordFlow,
  }) =>
      AuthState(
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        isLoading: isLoading ?? this.isLoading,
        isRestoring: isRestoring ?? this.isRestoring,
        error: clearError ? null : (error ?? this.error),
        user: user ?? this.user,
        pendingSessionToken: clearPendingSession
            ? null
            : (pendingSessionToken ?? this.pendingSessionToken),
        pendingEmail:
            clearPendingEmail ? null : (pendingEmail ?? this.pendingEmail),
        devOtp: clearDevOtp ? null : (devOtp ?? this.devOtp),
        needsPasswordCreation:
            needsPasswordCreation ?? this.needsPasswordCreation,
        forgotPasswordResetToken: clearForgotPasswordResetToken
            ? null
            : (forgotPasswordResetToken ?? this.forgotPasswordResetToken),
        isForgotPasswordFlow:
            isForgotPasswordFlow ?? this.isForgotPasswordFlow,
      );
}
