import 'package:flutter/material.dart';
import 'package:forest_app/core/theme/app_theme.dart';

class CustomButton extends StatelessWidget {
  final String   label;
  final VoidCallback? onPressed;
  final bool     isLoading;
  final bool     outlined;
  final IconData? icon;

  const CustomButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.outlined  = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primary,
          minimumSize: const Size(double.infinity, 48),
          side: const BorderSide(color: AppTheme.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _child(),
      );
    }

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      child: _child(),
    );
  }

  Widget _child() {
    if (isLoading) {
      return const SizedBox(
        height: 20,
        width:  20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppTheme.white,
        ),
      );
    }
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      );
    }
    return Text(label);
  }
}