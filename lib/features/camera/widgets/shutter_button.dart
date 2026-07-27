import 'package:flutter/material.dart';

/// 無音撮影用のシャッターボタン。
class ShutterButton extends StatelessWidget {
  const ShutterButton({
    required this.onPressed,
    this.isCapturing = false,
    super.key,
  });

  final VoidCallback? onPressed;
  final bool isCapturing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'シャッター',
      child: GestureDetector(
        onTap: isCapturing ? null : onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            color: isCapturing ? Colors.white54 : Colors.white,
          ),
          child: isCapturing
              ? const Padding(
                  padding: EdgeInsets.all(22),
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              : null,
        ),
      ),
    );
  }
}
