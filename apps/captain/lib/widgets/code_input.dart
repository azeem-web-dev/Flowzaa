import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A row of [length] styled digit boxes driven by a single hidden text field.
/// Used for the 6-digit OTP and the 4-digit ride-start PIN. Fires
/// [onCompleted] as soon as the last digit is typed (auto-submit).
class CodeInput extends StatefulWidget {
  final int length;
  final TextEditingController controller;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;

  /// When true the boxes flash the danger color (wrong PIN, etc.).
  final bool error;
  final bool enabled;
  final bool autofocus;
  final double boxHeight;

  const CodeInput({
    super.key,
    required this.length,
    required this.controller,
    this.onCompleted,
    this.onChanged,
    this.error = false,
    this.enabled = true,
    this.autofocus = true,
    this.boxHeight = 58,
  });

  @override
  State<CodeInput> createState() => _CodeInputState();
}

class _CodeInputState extends State<CodeInput> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Rebuild the boxes whenever the text or focus changes (covers external
    // clears from the parent, not just keystrokes).
    widget.controller.addListener(_onExternalChange);
    _focus.addListener(_onExternalChange);
  }

  void _onExternalChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onExternalChange);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Hidden field that owns the keyboard input.
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              autofocus: widget.autofocus,
              enabled: widget.enabled,
              keyboardType: TextInputType.number,
              maxLength: widget.length,
              showCursor: false,
              enableInteractiveSelection: false,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
              ),
              onChanged: (v) {
                widget.onChanged?.call(v);
                if (v.length == widget.length) {
                  widget.onCompleted?.call(v);
                }
              },
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? _focus.requestFocus : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                _box(i),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _box(int i) {
    final text = widget.controller.text;
    final filled = i < text.length;
    final active = _focus.hasFocus && i == text.length && !widget.error;

    final Color borderColor;
    if (widget.error) {
      borderColor = AppColors.danger;
    } else if (active || filled) {
      borderColor = AppColors.primary;
    } else {
      borderColor = AppColors.line;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: 46,
      height: widget.boxHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: active || filled ? 1.6 : 1),
      ),
      child: Text(
        filled ? text[i] : '',
        style: AppText.h2.copyWith(
          color: widget.error ? AppColors.danger : AppColors.ink,
        ),
      ),
    );
  }
}
