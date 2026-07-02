import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Six individual OTP digit boxes driven by a single hidden [TextField].
/// Tapping anywhere focuses the field; digits fill left-to-right and
/// [onCompleted] fires once all boxes are filled.
class OtpBoxes extends StatefulWidget {
  final int length;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;

  const OtpBoxes({
    super.key,
    this.length = 6,
    this.onChanged,
    this.onCompleted,
  });

  @override
  State<OtpBoxes> createState() => OtpBoxesState();
}

class OtpBoxesState extends State<OtpBoxes> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  String get code => _ctrl.text;

  /// Clears the boxes (e.g. after a failed verification or resend).
  void clear() {
    _ctrl.clear();
    _focus.requestFocus();
  }

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onText);
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onText() {
    setState(() {});
    widget.onChanged?.call(_ctrl.text);
    if (_ctrl.text.length == widget.length) {
      widget.onCompleted?.call(_ctrl.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        children: [
          // Invisible text field spanning the row — it owns the keyboard.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
                showCursor: false,
                enableInteractiveSelection: false,
                decoration: const InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  counterText: '',
                ),
              ),
            ),
          ),
          // The visible boxes.
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _focus.requestFocus,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(widget.length, _box),
            ),
          ),
        ],
      ),
    );
  }

  Widget _box(int i) {
    final text = _ctrl.text;
    final filled = i < text.length;
    final active = _focus.hasFocus &&
        (i == text.length || (i == widget.length - 1 && filled));
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      width: 44,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? AppColors.primary
              : filled
                  ? AppColors.primary
                  : AppColors.line,
          width: active ? 1.8 : 1.2,
        ),
      ),
      child: Text(
        filled ? text[i] : '',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    );
  }
}
