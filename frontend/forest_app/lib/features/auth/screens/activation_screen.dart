
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants.dart';
import '../../../../core/theme/app_colors.dart';

class ActivationScreen extends StatefulWidget {
  final String token;
  const ActivationScreen({super.key, required this.token});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool    _obscurePass    = true;
  bool    _obscureConfirm = true;
  bool    _isSubmitting   = false;
  bool    _success        = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isSubmitting = true; _errorMessage = null; });

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/users/activate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token':    widget.token,
          'password': _passCtrl.text,   // ← correspond au schema UserActivate
        }),
      ).timeout(ApiConstants.requestTimeout);

      if (response.statusCode == 200) {
        setState(() => _success = true);
      } else {
        final error = jsonDecode(response.body);
        setState(() =>
            _errorMessage = error['detail'] ?? "Erreur lors de l'activation");
      }
    } catch (e) {
      setState(() =>
          _errorMessage = 'Erreur réseau — vérifiez votre connexion');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F3),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Logo ─────────────────────────────────────
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Icon(Icons.park,
                        color: AppColors.primaryAccent, size: 28),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Ghabetna',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary, letterSpacing: -0.5)),
                const SizedBox(height: 4),
                const Text('Direction Générale des Forêts',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(height: 32),

                // ── Card ─────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _success
                      ? const _SuccessView()
                      : _FormView(
                          formKey:        _formKey,
                          passCtrl:       _passCtrl,
                          confirmCtrl:    _confirmCtrl,
                          obscurePass:    _obscurePass,
                          obscureConfirm: _obscureConfirm,
                          isSubmitting:   _isSubmitting,
                          errorMessage:   _errorMessage,
                          onTogglePass:   () => setState(() => _obscurePass = !_obscurePass),
                          onToggleConfirm:() => setState(() => _obscureConfirm = !_obscureConfirm),
                          onDismissError: () => setState(() => _errorMessage = null),
                          onSubmit:       _activate,
                        ),
                ),

                const SizedBox(height: 24),
                const Text(
                  "© 2025 Ghabetna — Ministère de l'Agriculture",
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Vue succès
// ─────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  const _SuccessView();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64, height: 64,
          decoration: const BoxDecoration(
            color: AppColors.successBg,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_outline,
              size: 32, color: AppColors.success),
        ),
        const SizedBox(height: 20),
        const Text('Compte activé !',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        const Text(
          'Votre mot de passe a été défini avec succès. Vous pouvez maintenant vous connecter.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13, color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => context.go('/login'),
            icon: const Icon(Icons.login, size: 16),
            label: const Text('Se connecter',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Vue formulaire
// ─────────────────────────────────────────────────────────────

class _FormView extends StatelessWidget {
  final GlobalKey<FormState>  formKey;
  final TextEditingController passCtrl;
  final TextEditingController confirmCtrl;
  final bool        obscurePass;
  final bool        obscureConfirm;
  final bool        isSubmitting;
  final String?     errorMessage;
  final VoidCallback onTogglePass;
  final VoidCallback onToggleConfirm;
  final VoidCallback onDismissError;
  final VoidCallback onSubmit;

  const _FormView({
    required this.formKey,
    required this.passCtrl,
    required this.confirmCtrl,
    required this.obscurePass,
    required this.obscureConfirm,
    required this.isSubmitting,
    required this.errorMessage,
    required this.onTogglePass,
    required this.onToggleConfirm,
    required this.onDismissError,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Activez votre compte',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary, letterSpacing: -0.3)),
          const SizedBox(height: 6),
          const Text(
            'Choisissez un mot de passe sécurisé pour finaliser la création de votre compte.',
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),

          // ── Error banner ──────────────────────────────────
          if (errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.danger.withOpacity(0.3), width: 0.5),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline,
                    size: 16, color: AppColors.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(errorMessage!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.danger)),
                ),
                GestureDetector(
                  onTap: onDismissError,
                  child: const Icon(Icons.close,
                      size: 16, color: AppColors.danger),
                ),
              ]),
            ),
            const SizedBox(height: 16),
          ],

          // ── Mot de passe ──────────────────────────────────
          _PassField(
            label:      'Nouveau mot de passe *',
            controller: passCtrl,
            obscure:    obscurePass,
            onToggle:   onTogglePass,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Champ requis';
              if (v.length < 8) return 'Minimum 8 caractères';
              if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Au moins une majuscule';
              if (!RegExp(r'[a-z]').hasMatch(v)) return 'Au moins une minuscule';
              if (!RegExp(r'[0-9]').hasMatch(v)) return 'Au moins un chiffre';
              if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(v))
                return 'Au moins un caractère spécial (!@#\$...)';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // ── Confirmation ──────────────────────────────────
          _PassField(
            label:      'Confirmer le mot de passe *',
            controller: confirmCtrl,
            obscure:    obscureConfirm,
            onToggle:   onToggleConfirm,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Champ requis';
              if (v != passCtrl.text)
                return 'Les mots de passe ne correspondent pas';
              return null;
            },
          ),
          const SizedBox(height: 8),

          // ── Hint règles ───────────────────────────────────
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, size: 13, color: AppColors.textMuted),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Min. 8 car. · Majuscule · Minuscule · Chiffre · Caractère spécial',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 28),

          // ── Bouton ────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSubmitting ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.primaryDark.withOpacity(0.6),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Text('Activer mon compte',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Champ mot de passe réutilisable
// ─────────────────────────────────────────────────────────────

class _PassField extends StatelessWidget {
  final String                     label;
  final TextEditingController      controller;
  final bool                       obscure;
  final VoidCallback               onToggle;
  final String? Function(String?)? validator;

  const _PassField({
    required this.label,
    required this.controller,
    required this.obscure,
    required this.onToggle,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextFormField(
            controller:  controller,
            obscureText: obscure,
            validator:   validator,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText:  '••••••••',
              hintStyle: const TextStyle(
                  fontSize: 12, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.lock_outline,
                  size: 16, color: AppColors.textMuted),
              suffixIcon: IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 16, color: AppColors.textMuted,
                ),
                onPressed: onToggle,
              ),
              filled: true, fillColor: AppColors.bgInput,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: AppColors.border, width: 0.5)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: AppColors.border, width: 0.5)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: AppColors.primaryMid, width: 1.2)),
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: AppColors.danger, width: 0.8)),
              focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: AppColors.danger, width: 1.2)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              isDense: true,
            ),
          ),
        ],
      );
}