// features/auth/screens/login_screen.dart
// FIX : on lit authProvider.error après l'await, pas dans ref.listen

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword     = true;

  String? _emailError;
  String? _passwordError;

  static const _green  = Color(0xFF1F7522);
  static const _gray   = Color(0xFF6B7280);
  static const _border = Color(0xFFCCD0D5);
  static const _dark   = Color(0xFF1C1E21);
  static const _red    = Color(0xFFDC2626);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Validation locale ─────────────────────────────────
  bool _validateLocally() {
    String? emailErr;
    String? passErr;

    final email    = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      emailErr = 'Veuillez entrer votre adresse email.';
    } else if (!email.contains('@') || !email.contains('.')) {
      emailErr = 'L\'adresse email n\'est pas valide.';
    }

    if (password.isEmpty) {
      passErr = 'Veuillez entrer votre mot de passe.';
    }

    setState(() {
      _emailError    = emailErr;
      _passwordError = passErr;
    });

    return emailErr == null && passErr == null;
  }

  // ── Submit ────────────────────────────────────────────
  Future<void> _handleLogin() async {
    // 1. Reset
    setState(() {
      _emailError    = null;
      _passwordError = null;
    });

    // 2. Validation locale
    if (!_validateLocally()) return;

    // 3. Appel API — on attend la fin
    await ref.read(authProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text,
        );

    // 4. FIX : lire l'état APRÈS l'await avec ref.read (pas listen)
    //    À ce moment le state est déjà mis à jour par le notifier
    if (!mounted) return;

    final authState = ref.read(authProvider);
    if (authState.status == AuthStatus.error && authState.error != null) {
      setState(() {
        // On affiche l'erreur API sous le champ mot de passe
        // (identique au comportement Facebook)
        _passwordError = authState.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ref.watch pour avoir isLoading et bloquer le bouton
    final auth     = ref.watch(authProvider);
    final size     = MediaQuery.of(context).size;
    final isMobile = size.width < 800;

    return Scaffold(
      backgroundColor: Colors.white,
      body: isMobile ? _buildMobileLayout(auth) : _buildDesktopLayout(auth),
    );
  }

  // ── Layouts ───────────────────────────────────────────

  Widget _buildDesktopLayout(AuthState auth) => Row(
        children: [
          Expanded(
            flex: 6,
            child: Container(
              color: const Color(0xFFF3F4F6),
              child: Image.asset('assets/images/login.png',
                  fit: BoxFit.fill),
            ),
          ),
          Expanded(
            flex: 4,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                child: _buildForm(auth),
              ),
            ),
          ),
        ],
      );

  Widget _buildMobileLayout(AuthState auth) => SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 280,
              width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                Image.asset('assets/images/ghabetna_hero.png',
                    fit: BoxFit.cover),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end:   Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: _buildForm(auth),
            ),
          ],
        ),
      );

  // ── Form ──────────────────────────────────────────────

  Widget _buildForm(AuthState auth) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize:       MainAxisSize.min,
        children: [
          const SizedBox(height: 6),

          const Text('Connexion à Ghabetna',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: _dark)),

          const SizedBox(height: 20),

          // Email + erreur inline
          _buildTextField(
            controller: _emailController,
            label:      'Adresse email',
            keyboard:   TextInputType.emailAddress,
            hasError:   _emailError != null,
            onChanged:  (_) {
              if (_emailError != null) setState(() => _emailError = null);
            },
          ),
          _InlineError(message: _emailError),

          const SizedBox(height: 12),

          // Mot de passe + erreur inline
          _buildTextField(
            controller: _passwordController,
            label:      'Mot de passe',
            obscure:    _obscurePassword,
            hasError:   _passwordError != null,
            onChanged:  (_) {
              if (_passwordError != null) setState(() => _passwordError = null);
            },
            onSubmitted: (_) => _handleLogin(),
            suffix: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: _gray, size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          _InlineError(message: _passwordError),

          const SizedBox(height: 16),

          // Bouton
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton(
              onPressed: auth.isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor:         _green,
                foregroundColor:         Colors.white,
                disabledBackgroundColor: _green.withOpacity(0.6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22)),
                elevation: 0,
              ),
              child: auth.isLoading
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Text('Se connecter',
                      style: TextStyle(fontSize: 14)),
            ),
          ),

          const SizedBox(height: 12),

          Center(
            child: TextButton(
              onPressed: () {},
              child: const Text('Mot de passe oublié ?',
                  style: TextStyle(
                      color: _green, fontWeight: FontWeight.w500,
                      fontSize: 12)),
            ),
          ),

          const SizedBox(height: 24),

          Row(children: [
            Expanded(child: Divider(color: _border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('Direction Générale des Forêts',
                  style: TextStyle(color: _gray, fontSize: 12)),
            ),
            Expanded(child: Divider(color: _border)),
          ]),

          const SizedBox(height: 24),

          Center(
            child: Text(
              '© 2025 Ghabetna — Ministère de l\'Agriculture',
              style: TextStyle(color: _gray, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );

  // ── TextField ─────────────────────────────────────────

  Widget _buildTextField({
    required TextEditingController controller,
    required String                label,
    TextInputType                  keyboard    = TextInputType.text,
    bool                           obscure     = false,
    bool                           hasError    = false,
    Widget?                        suffix,
    void Function(String)?         onChanged,
    void Function(String)?         onSubmitted,
  }) =>
      SizedBox(
        height: 51,
        child: TextField(
          controller:   controller,
          obscureText:  obscure,
          keyboardType: keyboard,
          onChanged:    onChanged,
          onSubmitted:  onSubmitted,
          style: const TextStyle(fontSize: 15, color: _dark),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
                color: hasError ? _red : _gray, fontSize: 13),
            floatingLabelStyle: TextStyle(
                color: hasError ? _red : _green, fontSize: 13),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            suffixIcon: suffix,
            filled:    true,
            fillColor: hasError ? _red.withOpacity(0.04) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: hasError ? _red : _border,
                  width: hasError ? 1.5 : 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: hasError ? _red : _border,
                  width: hasError ? 1.5 : 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: hasError ? _red : _green, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════
//  Erreur inline animée
// ═══════════════════════════════════════════════════════════════

class _InlineError extends StatelessWidget {
  final String? message;
  static const _red = Color(0xFFDC2626);

  const _InlineError({this.message});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve:    Curves.easeOut,
      child: message != null
          ? Padding(
              padding: const EdgeInsets.only(top: 5, left: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline,
                      size: 14, color: _red),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      message!,
                      style: const TextStyle(
                        fontSize:   12,
                        color:      _red,
                        fontWeight: FontWeight.w400,
                        height:     1.3,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}