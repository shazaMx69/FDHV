class AuthResult {
  final bool success;
  final bool needsEmailConfirmation;
  final String? message;

  const AuthResult({
    required this.success,
    this.needsEmailConfirmation = false,
    this.message,
  });

  factory AuthResult.signedIn() => const AuthResult(success: true);

  factory AuthResult.confirmEmail({String? email}) => AuthResult(
        success: true,
        needsEmailConfirmation: true,
        message: email != null
            ? 'Account created. Check $email for a confirmation link, then sign in.'
            : 'Account created. Check your email for a confirmation link, then sign in.',
      );

  factory AuthResult.failure(String message) => AuthResult(
        success: false,
        message: message,
      );
}
