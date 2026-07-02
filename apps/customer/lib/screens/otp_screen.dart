import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../widgets/otp_boxes.dart';

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
  final _otpKey = GlobalKey<OtpBoxesState>();
  late String _verificationId = widget.verificationId;
  bool _loading = false;
  bool _resending = false;
  int _resendIn = 30;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendIn <= 1) {
        t.cancel();
        setState(() => _resendIn = 0);
      } else {
        setState(() => _resendIn--);
      }
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
              _otpKey.currentState?.clear();
              _startResendCountdown();
              _snack('Code sent again');
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
      _snack('Could not resend code: $e');
    }
  }

  Future<void> _verify(String code) async {
    if (_loading) return;
    if (code.length != 6) {
      _snack('Enter the 6-digit code');
      return;
    }
    setState(() => _loading = true);
    final auth = ref.read(authServiceProvider);
    try {
      await auth.verifyOtp(
        verificationId: _verificationId,
        smsCode: code,
      );

      // Register for push notifications (best-effort).
      String? token;
      try {
        token = await ref.read(fcmServiceProvider).init();
      } catch (_) {
        token = null;
      }

      var profile = await auth.ensureUserProfile(fcmToken: token);

      // New user without a real name → prompt for one.
      if (profile.name.isEmpty || profile.name == 'Rider') {
        final name = await _askName();
        if (name != null && name.trim().isNotEmpty) {
          profile = await auth.ensureUserProfile(name: name.trim());
        }
      }

      if (!mounted) return;
      // Pop back to AuthGate; it will now show HomeScreen.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _otpKey.currentState?.clear();
      _snack(AuthService.friendlyError(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Sign-in failed: $e');
    }
  }

  Future<String?> _askName() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('What should we call you?'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Your name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const FadeSlideIn(
                child: Text('Verify your number', style: AppText.h1),
              ),
              const SizedBox(height: 10),
              // Phone being verified, with an edit-back affordance.
              FadeSlideIn(
                delay: const Duration(milliseconds: 80),
                child: ScaleTap(
                  onTap: () => Navigator.of(context).pop(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Code sent to ${Fmt.phone(widget.phoneNumber)}',
                        style: AppText.bodySoft,
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.edit_rounded,
                          size: 16, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              FadeSlideIn(
                delay: const Duration(milliseconds: 160),
                child: OtpBoxes(
                  key: _otpKey,
                  onCompleted: _verify,
                ),
              ),
              const SizedBox(height: 20),
              FadeSlideIn(
                delay: const Duration(milliseconds: 240),
                child: Center(
                  child: _resendIn > 0
                      ? Text('Resend code in ${_resendIn}s',
                          style: AppText.bodySoft)
                      : TextButton(
                          onPressed: _resending ? null : _resend,
                          child: Text(_resending ? 'Sending…' : 'Resend code'),
                        ),
                ),
              ),
              const Spacer(),
              FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: PrimaryButton(
                  label: 'Verify',
                  loading: _loading,
                  onPressed: () => _verify(_otpKey.currentState?.code ?? ''),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
