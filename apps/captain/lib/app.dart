import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/providers.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'widgets/brand_logo.dart';

/// Routes the user based on auth + profile completeness.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const _Splash(),
      error: (e, _) => _ErrorScaffold(message: '$e'),
      data: (user) {
        if (user == null) return const LoginScreen();
        return const _CaptainGate();
      },
    );
  }
}

/// Loads the captain profile once signed in.
class _CaptainGate extends ConsumerWidget {
  const _CaptainGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final captainAsync = ref.watch(captainProvider);

    return captainAsync.when(
      loading: () => const _Splash(),
      error: (e, _) => _ErrorScaffold(message: '$e'),
      data: (captain) {
        // Profile row may still be creating right after OTP.
        if (captain == null) return const _Splash();
        if (!captain.isProfileComplete) return const ProfileSetupScreen();
        return const HomeScreen();
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.scaffold,
      body: Center(
        child: FadeSlideIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandLogo(size: 76),
              SizedBox(height: 18),
              Text('Flowzaa', style: AppText.display),
              SizedBox(height: 4),
              Text('Captain', style: AppText.bodySoft),
              SizedBox(height: 24),
              VehicleLoaderSmall(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  final String message;
  const _ErrorScaffold({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message,
              textAlign: TextAlign.center, style: AppText.bodySoft),
        ),
      ),
    );
  }
}
