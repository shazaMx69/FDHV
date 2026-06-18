import 'package:family_digital_heritage_vault/src/core/theme/app_theme.dart';
import 'package:family_digital_heritage_vault/src/features/auth/presentation/welcome_screen.dart';
import 'package:family_digital_heritage_vault/src/features/family/state/family_provider.dart';
import 'package:family_digital_heritage_vault/src/features/main/presentation/main_screen.dart';
import 'package:family_digital_heritage_vault/src/features/auth/state/auth_provider.dart';
import 'package:family_digital_heritage_vault/src/features/memories/state/memory_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FamilyVaultApp extends StatelessWidget {
  const FamilyVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FamilyProvider()),
        ChangeNotifierProvider(create: (_) => MemoryProvider()),
      ],
      child: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  @override
  void initState() {
    super.initState();
    // Wire the sign-out callback once providers are available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _wireSignOutCallback();
    });
  }

  void _wireSignOutCallback() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final family = context.read<FamilyProvider>();
    final memories = context.read<MemoryProvider>();

    auth.onSignedOut = () {
      family.reset();
      memories.reset();
    };
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return MaterialApp(
          title: 'Family Digital Heritage Vault',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: auth.bootstrapping
              ? const _SplashScreen()
              : auth.isAuthenticated
                  ? const MainScreen()
                  : const WelcomeScreen(),
        );
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LogoMark(),
              SizedBox(height: 32),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: const Center(
            child: Text('🏛️', style: TextStyle(fontSize: 46)),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Family Digital Heritage Vault',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Preserve memories. Connect generations.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}
