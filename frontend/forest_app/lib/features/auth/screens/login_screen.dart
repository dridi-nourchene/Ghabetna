import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

// ✅ ConsumerState remplace State
class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword     = true;

  static const _green      = Color(0xFF1F7522);
  static const _greenLight = Color(0xFFE8F5E9);
  static const _gray       = Color(0xFF6B7280);
  static const _border     = Color(0xFFD1D5DB);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email    = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Veuillez remplir tous les champs');
      return;
    }

    // ✅ ref.read remplace context.read
    await ref.read(authProvider.notifier).login(email, password);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:          Text(message),
        backgroundColor:  Colors.red.shade700,
        behavior:         SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Écouter les erreurs pour afficher le snackbar
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.error && next.error != null) {
        _showError(next.error!);
      }
    });

    final size     = MediaQuery.of(context).size;
    final isMobile = size.width < 800;

    return Scaffold(
      backgroundColor: Colors.white,
      body: isMobile
          ? _buildMobileLayout()
          : _buildDesktopLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          flex: 6,
          child: Container(
            color: const Color(0xFFF3F4F6),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/login.png',
                  fit: BoxFit.fill,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 56),
              child: _buildForm(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(
            height: 280,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/ghabetna_hero.png',
                  fit: BoxFit.cover,
                ),
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
                const Positioned(
                  bottom: 24, left: 24,
                  child: Text(
                    'Votre Vigilance\nfait la différence.',
                    style: TextStyle(
                      color:      Colors.white,
                      fontSize:   22,
                      fontWeight: FontWeight.w700,
                      height:     1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: _buildForm(),
          ),
        ],
      ),
    );
  }

  // ✅ Consumer remplacé par ref directement dans ConsumerState
  Widget _buildForm() {
    final auth = ref.watch(authProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize:       MainAxisSize.min,
      children: [

        const SizedBox(height: 32),

        const Text(
          'Connexion',
          style: TextStyle(
            fontSize:   28,
            fontWeight: FontWeight.w700,
            color:      Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Bienvenue sur la plateforme Ghabetna',
          style: TextStyle(fontSize: 14, color: _gray),
        ),

        const SizedBox(height: 32),

        _buildLabel('Adresse email'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _emailController,
          hint:       'nom@exemple.com',
          icon:       Icons.email_outlined,
          keyboard:   TextInputType.emailAddress,
        ),

        const SizedBox(height: 20),

        _buildLabel('Mot de passe'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _passwordController,
          hint:       '••••••••',
          icon:       Icons.lock_outline,
          obscure:    _obscurePassword,
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

        const SizedBox(height: 20),

        SizedBox(
          width:  double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: auth.isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor:         _green,
              foregroundColor:         Colors.white,
              disabledBackgroundColor: _green.withOpacity(0.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: auth.isLoading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                      color:       Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text(
                    'Se connecter',
                    style: TextStyle(
                      fontSize:   16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 16),

        Center(
          child: TextButton(
            onPressed: () {},
            child: const Text(
              'Mot de passe oublié ?',
              style: TextStyle(
                color:      Color(0xFF1F7522),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(child: Divider(color: _border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Direction Générale des Forêts',
                style: TextStyle(color: _gray, fontSize: 12),
              ),
            ),
            Expanded(child: Divider(color: _border)),
          ],
        ),

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
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize:   14,
        fontWeight: FontWeight.w500,
        color:      Color(0xFF374151),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller:   controller,
      obscureText:  obscure,
      keyboardType: keyboard,
      style: const TextStyle(fontSize: 15, color: Color(0xFF111827)),
      decoration: InputDecoration(
        hintText:   hint,
        hintStyle:  TextStyle(color: _gray, fontSize: 14),
        prefixIcon: Icon(icon, color: _gray, size: 20),
        suffixIcon: suffix,
        filled:     true,
        fillColor:  const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   const BorderSide(color: _green, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14,
        ),
      ),
    );
  }
}