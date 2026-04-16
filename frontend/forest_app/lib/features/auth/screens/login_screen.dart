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

  static const _green  = Color(0xFF1F7522);
  static const _gray   = Color(0xFF6B7280);
  static const _border = Color(0xFFCCD0D5);
  static const _dark   = Color(0xFF1C1E21);

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

    await ref.read(authProvider.notifier).login(email, password);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:         Text(message),
        backgroundColor: Colors.red.shade700,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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

  Widget _buildForm() {
    final auth = ref.watch(authProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize:       MainAxisSize.min,
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

        // Champ email — style Facebook (pas de label, pas d'icône)
        _buildTextField(
          controller: _emailController,
          label:       'Adresse email ou numéro de téléphone',
          keyboard:   TextInputType.emailAddress,
        ),

        const SizedBox(height: 12),

        // Champ mot de passe
        _buildTextField(
          controller: _passwordController,
          label:       'Mot de passe',
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

        const SizedBox(height: 16),

        // Bouton Se connecter
        SizedBox(
          width:  double.infinity,
          height: 36,
          child: ElevatedButton(
            onPressed: auth.isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor:         _green,
              foregroundColor:         Colors.white,
              disabledBackgroundColor: _green.withOpacity(0.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
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
                      fontSize:   14,
                      fontWeight: FontWeight.normal,
                    ),
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
                color:      _green,
                fontWeight: FontWeight.w500,
                fontSize:   12,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,   
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
  }) {
    return SizedBox(
  height: 51, 
   child: TextField(
      controller:   controller,
      obscureText:  obscure,
      keyboardType: keyboard,
      style: const TextStyle(fontSize: 15, color: _dark),
      decoration: InputDecoration(
        labelText:  label,
        labelStyle: TextStyle(color: _gray, fontSize: 13),
        floatingLabelStyle: const TextStyle(color: _green, fontSize: 13),
        floatingLabelBehavior: FloatingLabelBehavior.auto,    
        suffixIcon: suffix,
        filled:    true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: _border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: _border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: _green, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical:   14,
        ),
      ),
    ),
    );
  }
}