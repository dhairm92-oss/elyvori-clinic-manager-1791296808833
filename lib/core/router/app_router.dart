import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/providers/account_controller.dart';
import '../../features/account/presentation/screens/forgot_password_screen.dart';
import '../../features/account/presentation/screens/sign_in_screen.dart';
import '../../features/account/presentation/screens/sign_up_screen.dart';
import '../../features/agents/presentation/screens/agents_dashboard_screen.dart';
import '../../features/auth/presentation/providers/auth_controller.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/records/presentation/providers/records_providers.dart';
import '../../features/records/presentation/screens/records_screen.dart';
import '../../features/registry.dart';
import '../../features/shell/main_shell.dart';
import '../widgets/splash_screen.dart';

abstract final class Routes {
  static const splash = '/';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const forgot = '/forgot';
  static const dashboard = '/dashboard';
  static const home = '/home';
  static const records = '/records/:key';
}

/// Start-up: restores the session and keeps the splash on screen long enough
/// for its progress bar to finish.
final bootProvider = FutureProvider<bool>((ref) async {
  final minimum = Future<void>.delayed(const Duration(milliseconds: 1900));
  if (cloudSyncEnabled) {
    try {
      await ref.read(accountControllerProvider.future);
    } catch (_) {
      // a broken saved session just means "signed out"
    }
  }
  await minimum;
  return true;
});

/// Rebuilds the router's redirect whenever the auth state changes.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref<Object?> ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }
}

class _AccountListenable extends ChangeNotifier {
  _AccountListenable(Ref<Object?> ref) {
    ref.listen(bootProvider, (_, __) => notifyListeners());
    ref.listen(accountControllerProvider, (_, __) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final moduleRoute = GoRoute(
    path: Routes.records,
    builder: (_, state) => RecordsScreen(resourceKey: state.pathParameters['key'] ?? ''),
  );

  if (!useElyvoriAgents) {
    final listenable = _AccountListenable(ref);
    ref.onDispose(listenable.dispose);
    const authRoutes = {Routes.signIn, Routes.signUp, Routes.forgot};
    return GoRouter(
      initialLocation: Routes.splash,
      refreshListenable: listenable,
      redirect: (context, state) {
        final location = state.matchedLocation;
        final booted = ref.read(bootProvider).valueOrNull == true;
        if (!booted) return location == Routes.splash ? null : Routes.splash;
        final atEntry = location == Routes.splash || authRoutes.contains(location);
        if (!cloudSyncEnabled) return atEntry ? Routes.home : null;
        final signedIn = ref.read(accountControllerProvider).valueOrNull != null;
        if (!signedIn) return authRoutes.contains(location) ? null : Routes.signIn;
        return atEntry ? Routes.home : null;
      },
      routes: [
        GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
        GoRoute(path: Routes.signIn, builder: (_, __) => const AccountSignInScreen()),
        GoRoute(path: Routes.signUp, builder: (_, __) => const AccountSignUpScreen()),
        GoRoute(path: Routes.forgot, builder: (_, __) => const ForgotPasswordScreen()),
        GoRoute(path: Routes.home, builder: (_, __) => const MainShell()),
        moduleRoute,
      ],
    );
  }

  final listenable = _AuthListenable(ref);
  ref.onDispose(listenable.dispose);
  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: listenable,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      if (auth.isLoading) return location == Routes.splash ? null : Routes.splash;
      final signedIn = auth.valueOrNull != null;
      if (!signedIn) return location == Routes.signIn ? null : Routes.signIn;
      if (location == Routes.signIn || location == Routes.splash) return Routes.dashboard;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: Routes.signIn, builder: (_, __) => const SignInScreen()),
      GoRoute(path: Routes.dashboard, builder: (_, __) => const AgentsDashboardScreen()),
      moduleRoute,
    ],
  );
});
