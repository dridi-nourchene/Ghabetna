import 'package:flutter/material.dart';
import 'package:forest_app/core/theme/app_theme.dart';

class CustomTextField extends StatefulWidget {
  final String        label;
  final String?       hint;
  final TextEditingController controller;
  final bool          isPassword;
  final TextInputType keyboardType;
  final String?       Function(String?)? validator;
  final IconData?     prefixIcon;

  const CustomTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.isPassword    = false,
    this.keyboardType  = TextInputType.text,
    this.validator,
    this.prefixIcon,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize:   14,
            fontWeight: FontWeight.w500,
            color:      AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller:   widget.controller,
          obscureText:  widget.isPassword && _obscure,
          keyboardType: widget.keyboardType,
          validator:    widget.validator,
          style: const TextStyle(
            fontSize: 15,
            color:    AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(color: AppTheme.textSecondary),
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon, color: AppTheme.textSecondary, size: 20)
                : null,
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}