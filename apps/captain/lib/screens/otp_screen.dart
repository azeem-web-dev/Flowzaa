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
  final _codeController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
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
        verificationId: widget.verificationId,
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Incorrect or expired code');
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
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Text('Verify your number', style: AppText.h1),
              const SizedBox(height: 6),
              Text(
                'Enter the 6-digit code sent to ${Fmt.phone(widget.phoneNumber)}',
                style: AppText.bodySoft,
              ),
              const SizedBox(height: 28),
              const Text('OTP CODE', style: AppText.label),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: AppText.h2.copyWith(letterSpacing: 8),
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    hintText: '••••••',
                  ),
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
