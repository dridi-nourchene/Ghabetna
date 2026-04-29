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
  static const _green = Color(0xFF1F7522);
  static const _gray = Color(0xFF6B7280);
  static const _border = Color(0xFFCCD0D5);
  static const _dark = Color(0xFF1C1E21);
  static const _red = Color(0xFFDC2626);

  @override
  void initState() {
    super.initState();
    print('=== LoginScreen initState ===');
  }

  @override
  void dispose() {
    print('=== LoginScreen dispose ===');
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Validation locale ─────────────────────────────────
  bool _validateLocally() {
    print('=== Local validation ===');
    String? emailErr;
    String? passErr;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      emailErr = 'Veuillez entrer votre adresse email.';
    } else if (!email.contains('@') || !email.contains('.')) {
      emailErr = 'L\'adresse email n\'est pas valide.';
    }

    if (password.isEmpty) {
      passErr = 'Veuillez entrer votre mot de passe.';
    }

    print('Email error: $emailErr');
    print('Password error: $passErr');

    setState(() {
      _emailError = emailErr;
      _passwordError = passErr;
    });

    return emailErr == null && passErr == null;
  }

  // ── Routing de l'erreur API vers le bon champ ─────────
 void _routeApiError(String error) {
  if (!mounted) return;
  
  final lower = error.toLowerCase();
  final isEmailError = lower.contains('email') ||
      (lower.contains('adresse') && lower.contains('invalide'));

  setState(() {
    if (isEmailError) {
      _emailError = error;
      _passwordError = null;
    } else {
      _emailError = null;
      _passwordError = error;
    }
  });
}

  // ── Submit ────────────────────────────────────────────
  Future<void> _handleLogin() async {
    print('\n=== STARTING LOGIN PROCESS ===');
    
    // Reset toutes les erreurs UI
    setState(() {
      print('Resetting UI errors');
      _emailError = null;
      _passwordError = null;
    });

    // Validation locale
    if (!_validateLocally()) {
      print('❌ Local validation failed, aborting login');
      return;
    }

    print('✅ Local validation passed');
    print('🌐 Calling API login with email: ${_emailController.text.trim()}');
    
    // Appel API
    await ref.read(authProvider.notifier).login(
      _emailController.text.trim(),
      _passwordController.text,
    );
    
    print('API call completed\n');
  }

  @override
  Widget build(BuildContext context) {
    print('\n=== BUILD METHOD CALLED ===');
    
    // Écouter les changements d'état de l'auth
    ref.listen(authProvider, (previous, next) {
      print('\n=== LISTENER TRIGGERED ===');
      print('Previous status: ${previous?.status}');
      print('Current status: ${next.status}');
      print('Current error: ${next.error}');
      print('Current role: ${next.role}');
      print('Is loading: ${next.isLoading}');
      print('Is authenticated: ${next.isAuthenticated}');
      
      if (!mounted) {
        print('⚠️ Widget not mounted, ignoring listener');
        return;
      }

      // Gestion des erreurs
      if (next.status == AuthStatus.error && next.error != null) {
        print('❌ ERROR DETECTED: ${next.error}');
        _routeApiError(next.error!);
      }

      // Gestion du succès
      if (next.status == AuthStatus.authenticated) {
        print('✅ LOGIN SUCCESS! Navigating to home...');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connexion réussie !'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        });
      }
    });

    final auth = ref.watch(authProvider);
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 800;
    
    // Debug: Afficher l'état actuel des erreurs UI
    print('UI State - Email error: "${_emailError}"');
    print('UI State - Password error: "${_passwordError}"');
    print('Auth State - Status: ${auth.status}');
    print('Auth State - Error: ${auth.error}');
    print('Auth State - isLoading: ${auth.isLoading}');

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
              child: Image.asset('assets/images/login.png', fit: BoxFit.fill),
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
                Image.asset('assets/images/ghabetna_hero.png', fit: BoxFit.cover),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 6),

          const Text('Connexion à Ghabetna',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _dark)),

          const SizedBox(height: 20),

          // ── Email ─────────────────────────────────────
          _buildTextField(
            controller: _emailController,
            label: 'Adresse email',
            keyboard: TextInputType.emailAddress,
            hasError: _emailError != null,
            onChanged: (_) {
              print('Email field changed, clearing error');
              if (_emailError != null) setState(() => _emailError = null);
            },
          ),
          _InlineError(message: _emailError),

          const SizedBox(height: 12),

          // ── Mot de passe ──────────────────────────────
          _buildTextField(
            controller: _passwordController,
            label: 'Mot de passe',
            obscure: _obscurePassword,
            hasError: _passwordError != null,
            onChanged: (_) {
              print('Password field changed, clearing error');
              if (_passwordError != null) setState(() => _passwordError = null);
            },
            onSubmitted: (_) => _handleLogin(),
            suffix: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: _gray,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          _InlineError(message: _passwordError),

          const SizedBox(height: 16),

          // ── Bouton ────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton(
              onPressed: auth.isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryMid,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _primaryMid.withOpacity(0.6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                elevation: 0,
              ),
              child: auth.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Se connecter', style: TextStyle(fontSize: 14)),
            ),
          ),

          const SizedBox(height: 12),

          Center(
            child: TextButton(
              onPressed: () {
              },
              child: const Text('Mot de passe oublié ?',
                  style: TextStyle(color: _primaryMid, fontWeight: FontWeight.w500, fontSize: 12)),
            ),
          ),

          const SizedBox(height: 24),

          Row(children: [
            const Expanded(child: Divider(color: _border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('Direction Générale des Forêts',
                  style: const TextStyle(color: _gray, fontSize: 12)),
            ),
            const Expanded(child: Divider(color: _border)),
          ]),

          const SizedBox(height: 24),

          Center(
            child: const Text(
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
    required String label,
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
    bool hasError = false,
    Widget? suffix,
    void Function(String)? onChanged,
    void Function(String)? onSubmitted,
  }) =>
      SizedBox(
        height: 51,
        child: TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboard,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: const TextStyle(fontSize: 15, color: _dark),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: hasError ? _red : _gray, fontSize: 13),
            floatingLabelStyle: TextStyle(color: hasError ? _red : _green, fontSize: 13),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            suffixIcon: suffix,
            filled: true,
            fillColor: hasError ? _red.withOpacity(0.04) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: hasError ? _red : _border, width: hasError ? 1.5 : 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: hasError ? _red : _border, width: hasError ? 1.5 : 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: hasError ? _red : _green, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
    print('_InlineError build - message: "$message"');
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
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
                        fontSize: 12,
                        color: _red,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
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