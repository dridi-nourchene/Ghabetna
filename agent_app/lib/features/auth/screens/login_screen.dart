import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:agent_app/core/theme/app_colors.dart';
import 'package:agent_app/features/auth/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey            = GlobalKey<FormState>();
  bool  _obscurePassword    = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final ok = await ref.read(authProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text,
        );

    if (ok && mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final auth      = ref.watch(authProvider);
    final isLoading = auth.isLoading;

    ref.listen<AuthState>(authProvider, (_, next) {
      if (next.isAuthenticated && mounted) context.go('/home');
    });

    return Scaffold(
      backgroundColor: AgentColors.bgPage,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Logo + Titre ─────────────────────────────
                Center(
                  child: Column(children: [
                    // Logo Ghabetna — image asset
                    Image.asset(
                      'assets/images/logo.png',
                      width:  100,
                      height: 100,
                      errorBuilder: (_, __, ___) => Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          color:        AgentColors.primary,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color:      AgentColors.primary.withOpacity(0.3),
                              blurRadius: 20,
                              offset:     const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.park,
                            color: Colors.white, size: 36),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Ghabetna',
                        style: TextStyle(
                            fontSize:      28,
                            fontWeight:    FontWeight.w800,
                            color:         AgentColors.textPrimary,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    const Text('Application Agent DGF',
                        style: TextStyle(
                            fontSize: 14,
                            color:    AgentColors.textMuted)),
                  ]),
                ),

                const SizedBox(height: 48),

                // ── Card formulaire ──────────────────────────
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color:        Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color:      Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset:     const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Connexion',
                          style: TextStyle(
                              fontSize:   20,
                              fontWeight: FontWeight.w700,
                              color:      AgentColors.textPrimary)),
                      const SizedBox(height: 4),
                      const Text('Accédez à votre espace agent',
                          style: TextStyle(
                              fontSize: 13,
                              color:    AgentColors.textMuted)),

                      const SizedBox(height: 24),

                      const _FieldLabel('Email'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller:   _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect:  false,
                        style: const TextStyle(
                            fontSize: 14,
                            color:    AgentColors.textPrimary),
                        decoration: _inputDecoration(
                          hint: 'votre@email.com',
                          icon: Icons.mail_outline,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email requis';
                          }
                          if (!v.contains('@')) {
                            return 'Email invalide';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      const _FieldLabel('Mot de passe'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller:  _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(
                            fontSize: 14,
                            color:    AgentColors.textPrimary),
                        decoration: _inputDecoration(
                          hint: '••••••••',
                          icon: Icons.lock_outline,
                        ).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size:  18,
                              color: AgentColors.textMuted,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Mot de passe requis';
                          }
                          if (v.length < 6) {
                            return 'Minimum 6 caractères';
                          }
                          return null;
                        },
                      ),

                      if (auth.errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color:        const Color(0xFFFFF0EA),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AgentColors.danger.withOpacity(0.3),
                                width: 0.5),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline,
                                size: 14, color: AgentColors.danger),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                auth.errorMessage!,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color:    AgentColors.danger),
                              ),
                            ),
                          ]),
                        ),
                      ],

                      const SizedBox(height: 24),

                      SizedBox(
                        width:  double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AgentColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                AgentColors.primary.withOpacity(0.5),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                      color:       Colors.white,
                                      strokeWidth: 2.5))
                              : const Text('Se connecter',
                                  style: TextStyle(
                                      fontSize:   16,
                                      fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                Center(
                  child: Text(
                    'DGF — Direction Générale des Forêts',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        color:    AgentColors.textMuted.withOpacity(0.6),
                        height:   1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String   hint,
    required IconData icon,
  }) =>
      InputDecoration(
        hintText:   hint,
        hintStyle:  const TextStyle(
            fontSize: 14, color: AgentColors.textMuted),
        prefixIcon: Icon(icon, size: 18, color: AgentColors.textMuted),
        filled:     true,
        fillColor:  const Color(0xFFF5F7F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFFE8EDE8), width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFFE8EDE8), width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AgentColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AgentColors.danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AgentColors.danger, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        isDense: true,
      );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize:   12,
          fontWeight: FontWeight.w600,
          color:      AgentColors.textSecondary));
}