import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../core/common_widgets/large_button.dart';
import '../../../core/constants/image_strings.dart';
import '../../../core/utils/utils.dart';
import '../../../providers/utils_providers.dart';
import '../controllers/authentication_controller.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  Timer? timer, timer2;

  @override
  void initState() {
    super.initState();
    // O redirect do roteador so libera o app quando `emailVerified` vira true,
    // e isso depende de um reload(). Por isso o polling comeca junto com a
    // tela, e nao apenas quando o aluno pede o reenvio.
    WidgetsBinding.instance.addPostFrameCallback((_) => watchVerification());
  }

  @override
  void dispose() {
    timer?.cancel();
    timer2?.cancel();
    super.dispose();
  }

  void watchVerification() {
    timer?.cancel();
    timer =
        ref.read(authControllerProvider.notifier).reloadUserPeriodically(() {
      if (mounted) GoRouter.of(context).refresh();
    });
  }

  /// Contagem regressiva do botao de reenvio, para nao estourar a cota do
  /// Firebase com cliques seguidos.
  void startTimer({required double seconds, required Duration step}) {
    ref.read(timeRemainingProvider.notifier).set(seconds);
    timer2?.cancel();
    timer2 = Timer.periodic(step, (t) {
      ref.read(timeRemainingProvider.notifier).decrease(step);
      if (ref.read(timeRemainingProvider) == 0) t.cancel();
    });
    watchVerification();
  }

  Future<void> sendMail(double waitTime) async {
    if (ref.read(timeRemainingProvider) == 0) {
      await ref.read(authControllerProvider.notifier).verifyEmail((verify) {
        verify.fold(
            (l) => showSnackBar(
                context: context, title: l, snackBarType: SnackBarType.error),
            (r) => showSnackBar(
                context: context,
                title: 'E-mail de verificação enviado.',
                snackBarType: SnackBarType.good));
      });
      startTimer(seconds: waitTime, step: const Duration(milliseconds: 50));
    }
  }

  @override
  Widget build(BuildContext context) {
    double waitTime = 60;
    return Scaffold(
      floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.cancel),
          onPressed: () {
            timer?.cancel();
            timer2?.cancel();
          }),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox.square(dimension: 200, child: Lottie.asset(emailLottie)),
            const Text('Confirme seu e-mail para continuar'),
            Text(
              ref.watch(myUserProvider)?.email ??
                  FirebaseAuth.instance.currentUser?.email ??
                  '',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(color: Colors.red),
            ),
            const SizedBox(
              height: 10,
            ),
            MainButton(
              onPressed: () async {
                if (!ref.read(authControllerProvider)) {
                  await sendMail(waitTime);
                }
              },
              child: (!ref.watch(authControllerProvider))
                  ? ((ref.watch(timeRemainingProvider) > 0)
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                value: (ref.watch(timeRemainingProvider) /
                                    waitTime),
                                color: Colors.black,
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            Text(ref
                                .watch(timeRemainingProvider)
                                .ceil()
                                .toString()),
                          ],
                        )
                      : const Text(
                          'Reenviar e-mail de verificação',
                          style: TextStyle(fontSize: 10.37),
                          textAlign: TextAlign.center,
                        ))
                  : const CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2,
                    ),
            ),
            TextButton(
              onPressed: () {
                timer?.cancel();
                timer2?.cancel();
                ref
                    .read(authControllerProvider.notifier)
                    .logout(GoRouter.of(context).refresh);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Sair'),
            )
          ],
        ),
      ),
    );
  }
}
