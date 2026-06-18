import 'package:family_digital_heritage_vault/src/features/auth/state/auth_result.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final _secureStorage = const FlutterSecureStorage(
    webOptions: WebOptions(
      dbName: 'family_heritage_vault',
      publicKey: 'family_heritage_vault_public_key',
    ),
  );

  bool _isAuthenticated = false;
  // True while the initial session check is running — callers show a splash.
  bool _bootstrapping = true;

  bool get isAuthenticated => _isAuthenticated;
  bool get bootstrapping => _bootstrapping;

  User? get user => _supabase.auth.currentUser;

  // Callback invoked when the user signs out so parent can reset other providers.
  VoidCallback? onSignedOut;

  AuthProvider() {
    _bootstrap();
    _supabase.auth.onAuthStateChange.listen((data) {
      final wasAuthenticated = _isAuthenticated;
      _isAuthenticated = data.session != null;
      // Fire reset callback when transitioning from authenticated → unauthenticated.
      if (wasAuthenticated && !_isAuthenticated) {
        onSignedOut?.call();
      }
      notifyListeners();
    });
  }

  Future<void> _bootstrap() async {
    // currentSession is synchronous — no network call.
    final session = _supabase.auth.currentSession;
    _isAuthenticated = session != null;
    _bootstrapping = false;
    notifyListeners();
  }

  Future<void> signInWithEmail(String email, String password) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    if (response.session == null) {
      throw const AuthException('Sign in failed. Please try again.');
    }

    await _persistAccessToken(response.session!.accessToken);
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<AuthResult> registerWithEmail(
    String email,
    String password, {
    String? displayName,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: displayName != null && displayName.trim().isNotEmpty
            ? {'full_name': displayName.trim()}
            : null,
        emailRedirectTo: kIsWeb ? Uri.base.origin : null,
      );

      final user = response.user;
      if (user == null) {
        return AuthResult.failure('Registration failed. Please try again.');
      }

      final session = response.session;
      if (session != null) {
        await _persistAccessToken(session.accessToken);
        _isAuthenticated = true;
        notifyListeners();
        return AuthResult.signedIn();
      }

      final identities = user.identities;
      if (identities == null || identities.isEmpty) {
        return AuthResult.failure(
          'An account with this email may already exist. Try signing in instead.',
        );
      }

      return AuthResult.confirmEmail(email: email.trim());
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyAuthMessage(e.message));
    } catch (e) {
      return AuthResult.failure(
        'Registration failed: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } finally {
      await _clearAccessToken();
      _isAuthenticated = false;
      onSignedOut?.call();
      notifyListeners();
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    await _supabase.auth.updateUser(
      UserAttributes(data: {'full_name': displayName.trim()}),
    );
    notifyListeners();
  }

  String? get accessToken => _supabase.auth.currentSession?.accessToken;

  Future<void> _persistAccessToken(String token) async {
    if (kIsWeb) return;
    try {
      await _secureStorage.write(key: 'access_token', value: token);
    } catch (_) {}
  }

  Future<void> _clearAccessToken() async {
    try {
      await _secureStorage.delete(key: 'access_token');
    } catch (_) {}
  }

  String _friendlyAuthMessage(String? message) {
    final raw = (message ?? '').trim();
    if (raw.isEmpty) return 'Authentication failed. Please try again.';

    final lower = raw.toLowerCase();
    if (lower.contains('already registered') ||
        lower.contains('already exists') ||
        lower.contains('user already')) {
      return 'An account with this email already exists. Try signing in.';
    }
    if (lower.contains('password')) {
      return 'Password does not meet requirements. Use at least 6 characters.';
    }
    if (lower.contains('invalid email') || lower.contains('valid email')) {
      return 'Enter a valid email address.';
    }
    if (lower.contains('signup') && lower.contains('disabled')) {
      return 'New signups are disabled. Contact the administrator.';
    }
    if (lower.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Confirm your email using the link we sent, then sign in.';
    }

    return raw;
  }
}
