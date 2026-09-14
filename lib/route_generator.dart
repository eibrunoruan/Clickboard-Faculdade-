import 'package:clickboard/src/features/profile_screen/screens/change_password.dart';
import 'package:clickboard/src/features/authentication/screens/verify_email.dart';
import 'package:clickboard/src/features/profile_screen/screens/take_picture.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '/src/features/authentication/screens/login/login_page.dart';
import '/src/features/authentication/screens/signup/signup_page.dart';
import 'src/features/authentication/screens/forgot_password/forgot_password_screen.dart';
import 'src/core/utils/auth_redirect.dart';
import 'src/features/main_page/screens/main_page.dart';
import 'src/features/profile_screen/screens/about_us.dart';
import 'src/features/profile_screen/screens/my_account.dart';
part 'route_generator.g.dart';

const bool useFirebase =
    bool.fromEnvironment('USE_FIREBASE', defaultValue: true);

@riverpod
GoRouter myGoRouter(MyGoRouterRef ref) {
  return goRouter;
}

GoRouter goRouter = GoRouter(
  redirect: (context, state) {
    final User? user = useFirebase ? FirebaseAuth.instance.currentUser : null;
    return resolveRedirect(
      useFirebase: useFirebase,
      isSignedIn: user != null,
      isEmailVerified: user?.emailVerified ?? false,
      location: state.matchedLocation,
    );
  },
  routes: [
    GoRoute(
      name: 'Login',
      path: '/auth/login',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const LoginPage(), // Directly use the page content widget here
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
    ),
    GoRoute(
      name: 'Signup',
      path: '/auth/signup',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const SignupPage(), // Directly use the page content widget here
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
    ),
    GoRoute(
      name: 'Forgot Password',
      path: '/auth/forgot-password',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child:
            const ForgotPasswordScreen(), // Directly use the page content widget here
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
    ),
    GoRoute(
      name: 'Verify Email',
      path: '/app/verify-email',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child:
            const VerifyEmailScreen(), // Directly use the page content widget here
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
    ),
    GoRoute(
      name: 'Clickboard',
      path: '/',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: AppScreen(), // Directly use the page content widget here
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
    ),
    GoRoute(
      name: 'About us',
      path: '/app/about-us',
      pageBuilder: (context, state) => const MaterialPage(child: AboutUs()),
    ),
    GoRoute(
      name: 'My Account',
      path: '/app/my-account',
      pageBuilder: (context, state) => const MaterialPage(child: MyAccount()),
    ),
    GoRoute(
      name: 'Change Password',
      path: '/app/change-password',
      pageBuilder: (context, state) => MaterialPage(child: ChangePassword()),
    ),
    GoRoute(
      name: 'Take Picture',
      path: '/app/take-picture',
      pageBuilder: (context, state) =>
          const MaterialPage(child: TakePictureScreen()),
    ),
  ],
);
