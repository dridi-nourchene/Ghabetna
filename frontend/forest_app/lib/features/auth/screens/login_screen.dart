// features/auth/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  String? _emailError;
  String? _passwordError;

  static const _primaryMid = Color(0xFF1A6B45);
  static const _green  = Color(0xFF1F7522);
  static const _gray   = Color(0xFF6B7280);
  static const _border = Color(0xFFCCD0D5);
  static const _dark   = Color(0xFF1C1E21);
  static const _red    = Color(0xFFDC2626);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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

  void _routeApiError(String error) {
    if (!mounted) return;
    final lower = error.toLowerCase();
    final isEmailError = lower.contains('email') ||
        (lower.contains('adresse') && lower.contains('invalide'));

    setState(() {
      if (isEmailError) {
        _emailError    = error;
        _passwordError = null;
      } else {
        _emailError    = null;
        _passwordError = error;
      }
    });
  }

  Future<void> _handleLogin() async {
    setState(() {
      _emailError    = null;
      _passwordError = null;
    });

    if (!_validateLocally()) return;

    await ref.read(authProvider.notifier).login(
      _emailController.text.trim(),
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (!mounted) return;

      if (next.status == AuthStatus.error && next.error != null) {
        _routeApiError(next.error!);
      }

      if (next.status == AuthStatus.authenticated) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Navigator.pushReplacementNamed(context, '/home');
        });
      }
    });

    final auth     = ref.watch(authProvider);
    final size     = MediaQuery.of(context).size;
    final isMobile = size.width < 800;

    return Scaffold(
      backgroundColor: Colors.white,
      body: isMobile
          ? _buildMobileLayout(auth)
          : _buildDesktopLayout(auth),
    );
  }

  // ── Desktop : ligne verticale + ligne horizontale ─────

  Widget _buildDesktopLayout(AuthState auth) {
    return Column(
      children: [
        // ✅ Partie principale : image | ligne verticale | formulaire
        Expanded(
          child: Row(
            
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
  flex: 6,
  child: ColoredBox(
    color: Colors.white,  // ✅ blanc
    child: Center(        // ✅ centre l'image
      child: Image.asset(
        'assets/images/login.png',
        fit:    BoxFit.contain,
        width:  1700,
        height: 750,
      ),
    ),
  ),
),

              // ✅ Ligne verticale
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: Color(0xFFCCD0D5),
              ),

              Expanded(
                flex: 4,
                child: Align(
                  alignment: const Alignment(0, -0.1),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 56),
                    child: _buildForm(auth),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ✅ Ligne horizontale sur toute la largeur
        const Divider(
          height: 1,
          thickness: 1,
          color: Color(0xFFCCD0D5),
        ),

        const SizedBox(height: 16),

        Center(
          child: Text(
            '© 2026 Ghabetna — Ministère de l\'Agriculture',
            style: TextStyle(color: _gray, fontSize: 11),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMobileLayout(AuthState auth) => SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 280,
              width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                Image.asset('assets/images/ghabetna_hero.png', fit: BoxFit.cover),
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

  Widget _buildForm(AuthState auth) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 6),

          const Text(
            'Connexion à Ghabetna',
            style: TextStyle(
              fontSize:   17,
              fontWeight: FontWeight.w700,
              color:      _dark,
            ),
          ),

          const SizedBox(height: 20),

          // ── Email ───────────────────────────────────────
          _buildTextField(
            controller: _emailController,
            label:      'Adresse email',
            keyboard:   TextInputType.emailAddress,
            hasError:   _emailError != null,
            onChanged: (_) {
              if (_emailError != null) setState(() => _emailError = null);
            },
          ),
          _InlineError(message: _emailError),

          const SizedBox(height: 12),

          // ── Mot de passe ────────────────────────────────
          _buildTextField(
            controller: _passwordController,
            label:      'Mot de passe',
            obscure:    _obscurePassword,
            hasError:   _passwordError != null,
            onChanged: (_) {
              if (_passwordError != null) setState(() => _passwordError = null);
            },
            onSubmitted: (_) => _handleLogin(),
            suffix: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: _gray,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          _InlineError(message: _passwordError),

          const SizedBox(height: 16),

          // ── Bouton ──────────────────────────────────────
          SizedBox(
            width:  double.infinity,
            height: 36,
            child: ElevatedButton(
              onPressed: auth.isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor:         _primaryMid,
                foregroundColor:         Colors.white,
                disabledBackgroundColor: _primaryMid.withOpacity(0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                elevation: 0,
              ),
              child: auth.isLoading
                  ? const SizedBox(
                      width:  22,
                      height: 22,
                      child:  CircularProgressIndicator(
                        color:       Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Se connecter',
                      style: TextStyle(fontSize: 14),
                    ),
            ),
          ),

          const SizedBox(height: 12),

          Center(
            child: TextButton(
              onPressed: () {},
              child: const Text(
                'Mot de passe oublié ?',
                style: TextStyle(
                  color:      _primaryMid,
                  fontWeight: FontWeight.w500,
                  fontSize:   12,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          Row(children: [
            const Expanded(child: Divider(color: _border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Direction Générale des Forêts',
                style: const TextStyle(color: _gray, fontSize: 12),
              ),
            ),
            const Expanded(child: Divider(color: _border)),
          ]),

          const SizedBox(height: 24),
        ],
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboard = TextInputType.text,
    bool obscure  = false,
    bool hasError = false,
    Widget? suffix,
    void Function(String)? onChanged,
    void Function(String)? onSubmitted,
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
            labelText:  label,
            labelStyle: TextStyle(
              color:    hasError ? _red : _gray,
              fontSize: 13,
            ),
            floatingLabelStyle: TextStyle(
              color:    hasError ? _red : _green,
              fontSize: 13,
            ),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            suffixIcon: suffix,
            filled:    true,
            fillColor: hasError ? _red.withOpacity(0.04) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? _red : _border,
                width: hasError ? 1.5 : 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? _red : _border,
                width: hasError ? 1.5 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? _red : _green,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical:   14,
            ),
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
      child: message != null && message!.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(top: 5, left: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, size: 14, color: _red),
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