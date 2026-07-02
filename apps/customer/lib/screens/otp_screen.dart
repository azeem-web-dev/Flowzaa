import 'package:firebase_auth/firebase_auth.dart';
import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

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
  final _codeCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      _snack('Enter the 6-digit code');
      return;
    }
    setState(() => _loading = true);
    final auth = ref.read(authServiceProvider);
    try {
      await auth.verifyOtp(
        verificationId: widget.verificationId,
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text('Verify your number', style: AppText.h1),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-digit code sent to ${Fmt.phone(widget.phoneNumber)}.',
                style: AppText.bodySoft,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 12,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Verify',
                loading: _loading,
                onPressed: _verify,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
