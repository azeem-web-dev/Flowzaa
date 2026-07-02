import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../widgets/code_input.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const OtpScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _codeController = TextEditingController();
  late String _verificationId = widget.verificationId;
  bool _loading = false;
  bool _resending = false;
  Timer? _timer;
  int _secondsLeft = 30;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    _secondsLeft = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) t.cancel();
      });
    });
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await ref.read(authServiceProvider).sendOtp(
            phoneNumber: widget.phoneNumber,
            onCodeSent: (verificationId) {
              if (!mounted) return;
              setState(() {
                _verificationId = verificationId;
                _resending = false;
              });
              _codeController.clear();
              _startCountdown();
              _snack('New code sent');
            },
            onError: (e) {
              if (!mounted) return;
              setState(() => _resending = false);
              _snack(AuthService.friendlyError(e));
            },
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _resending = false);
      _snack('$e');
    }
  }

  Future<void> _verify() async {
    if (_loading) return;
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _snack('Enter the 6-digit code');
      return;
    }
    setState(() => _loading = true);
    final auth = ref.read(authServiceProvider);
    final captains = ref.read(captainServiceProvider);
    final fcm = ref.read(fcmServiceProvider);
    try {
      final cred = await auth.verifyOtp(
        verificationId: _verificationId,
        smsCode: code,
      );
      final uid = cred.user!.uid;

      // Register/refresh FCM token then ensure the captain profile exists.
      String? token;
      try {
        token = await fcm.init();
      } catch (_) {
        token = null;
      }
      await captains.ensureProfile(
        uid: uid,
        phone: widget.phoneNumber,
        fcmToken: token,
      );
      if (token != null) {
        await auth.updateFcmToken(token, captain: true);
      }

      if (!mounted) return;
      // AuthGate (listening to authState) takes over from here.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _codeController.clear();
      _snack(AuthService.friendlyError(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Sign-in failed: $e');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const FadeSlideIn(
                child: Text('Verify your number', style: AppText.h1),
              ),
              const SizedBox(height: 6),
              FadeSlideIn(
                delay: const Duration(milliseconds: 60),
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Enter the 6-digit code sent to ',
                        style: AppText.bodySoft,
                      ),
                      TextSpan(
                        text: Fmt.phone(widget.phoneNumber),
                        style: AppText.bodySoft.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              FadeSlideIn(
                delay: const Duration(milliseconds: 120),
                child: CodeInput(
                  length: 6,
                  controller: _codeController,
                  enabled: !_loading,
                  onCompleted: (_) => _verify(),
                ),
              ),
              const SizedBox(height: 24),
              FadeSlideIn(
                delay: const Duration(milliseconds: 180),
                child: PrimaryButton(
                  label: 'Verify',
                  loading: _loading,
                  onPressed: _verify,
                ),
              ),
              const SizedBox(height: 8),
              FadeSlideIn(
                delay: const Duration(milliseconds: 240),
                child: Center(
                  child: _secondsLeft > 0
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Resend code in ${_secondsLeft}s',
                            style: AppText.label,
                          ),
                        )
                      : TextButton(
                          onPressed: _resending ? null : _resend,
                          child: Text(_resending ? 'Sending…' : 'Resend code'),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
