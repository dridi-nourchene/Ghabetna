// features/admin/screens/admin_edit_user_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../features/user/models/user_model.dart';
import '../../../features/user/providers/user_provider.dart';
import '../../../features/user/services/user_service.dart';

// ═══════════════════════════════════════════════════════════════
//  AdminEditUserScreen — Formulaire de modification
//  Route : /admin/users/:id
//  Le user est récupéré depuis le provider local (déjà chargé)
//  pour éviter un appel API supplémentaire.
// ═══════════════════════════════════════════════════════════════

class AdminEditUserScreen extends ConsumerStatefulWidget {
  final String userId;
  const AdminEditUserScreen({super.key, required this.userId});

  @override
  ConsumerState<AdminEditUserScreen> createState() =>
      _AdminEditUserScreenState();
}

class _AdminEditUserScreenState
    extends ConsumerState<AdminEditUserScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers — initialisés après que le user soit trouvé
  late final TextEditingController _fullNameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _cinCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _birthDateCtrl;

  String  _selectedRole   = 'agent';
  String  _selectedStatus = 'inactive';
  bool    _isSubmitting   = false;
  bool    _initialized    = false;
  String? _errorMessage;
  AppUser? _originalUser;

  static const _roles = {
    'agent':      'Agent de terrain',
    'supervisor': 'Superviseur',
  };

  static const _statuses = {
    'active':   'Actif',
    'inactive': 'Inactif',
    'banned':   'Banni',
  };

  // ── Init controllers from the found user ──────────────
  void _initFromUser(AppUser user) {
    if (_initialized) return;
    _originalUser  = user;
    _fullNameCtrl  = TextEditingController(text: user.fullName);
    _emailCtrl     = TextEditingController(text: user.email);
    _cinCtrl       = TextEditingController(text: user.cin);
    _phoneCtrl     = TextEditingController(text: user.phone ?? '');
    _birthDateCtrl = TextEditingController(text: user.birthDate ?? '');
    _selectedRole  = (user.role == 'admin') ? 'agent' : user.role;
    _selectedStatus= user.status;
    _initialized   = true;
  }

  @override
  void dispose() {
    if (_initialized) {
      _fullNameCtrl.dispose();
      _emailCtrl.dispose();
      _cinCtrl.dispose();
      _phoneCtrl.dispose();
      _birthDateCtrl.dispose();
    }
    super.dispose();
  }

  // ── Pick birth date ───────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDateCtrl.text.isNotEmpty
          ? DateTime.tryParse(_birthDateCtrl.text) ?? DateTime(1990)
          : DateTime(1990),
      firstDate: DateTime(1950),
      lastDate:
          DateTime.now().subtract(const Duration(days: 365 * 18)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
              primary: AppColors.primaryDark),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _birthDateCtrl.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  // ── Submit ────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final service     = UserService();
      final updatedUser = await service.updateUser(widget.userId, {
        'full_name':  _fullNameCtrl.text.trim(),
        'email':      _emailCtrl.text.trim(),
        'cin':        _cinCtrl.text.trim(),
        'phone':      _phoneCtrl.text.trim().isEmpty
            ? null
            : _phoneCtrl.text.trim(),
        'role':       _selectedRole,
        'status':     _selectedStatus,
        'birth_date': _birthDateCtrl.text.isEmpty
            ? null
            : _birthDateCtrl.text,
      });

      // Update local state instantly
      ref.read(userListProvider.notifier).updateUserLocally(updatedUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('${updatedUser.fullName} mis à jour'),
            ]),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        );
        context.go('/admin/users');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userListProvider);

    // Find the user from local state
    AppUser? user;
    try {
      user = userState.allUsers
          .firstWhere((u) => u.userId == widget.userId);
    } catch (_) {
      user = null;
    }

    // User not found yet → trigger load
    if (user == null && !userState.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(userListProvider.notifier).loadUsers();
      });
    }

    if (user == null && userState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryMid),
      );
    }

    if (user == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.person_off_outlined,
              size: 40, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Text('Utilisateur introuvable',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go('/admin/users'),
            child: const Text('Retour à la liste'),
          ),
        ]),
      );
    }

    // Init controllers once
    _initFromUser(user);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête ──────────────────────────────────
          Row(
            children: [
              GestureDetector(
                onTap: () => context.go('/admin/users'),
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.bgInput,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.border, width: 0.5),
                  ),
                  child: const Icon(Icons.arrow_back,
                      size: 16, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Modifier l\'utilisateur',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3)),
                  const SizedBox(height: 3),
                  Text(user.email,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
              const Spacer(),
              // User initials badge
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.successBg,
                child: Text(user.initials,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryMid)),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Form card ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMessage != null) ...[
                    _ErrorBanner(
                        message: _errorMessage!,
                        onDismiss: () =>
                            setState(() => _errorMessage = null)),
                    const SizedBox(height: 20),
                  ],

                  // ── Identité ─────────────────────────
                  _SectionTitle(
                      icon: Icons.person_outline, label: 'Identité'),
                  const SizedBox(height: 16),

                  Row(children: [
                    Expanded(
                      child: _FormField(
                        label:      'Nom complet *',
                        controller: _fullNameCtrl,
                        hint:       'Ex : Karim Amrani',
                        icon:       Icons.badge_outlined,
                        validator:  (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Champ requis'
                                : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _FormField(
                        label:      'CIN *',
                        controller: _cinCtrl,
                        hint:       '8 chiffres',
                        icon:       Icons.credit_card_outlined,
                        keyboard:   TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(8),
                        ],
                        validator: (v) {
                          if (v == null || v.isEmpty)
                            return 'Champ requis';
                          if (v.length != 8)
                            return 'Exactement 8 chiffres';
                          return null;
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  Row(children: [
                    Expanded(
                      child: _FormField(
                        label:      'Date de naissance',
                        controller: _birthDateCtrl,
                        hint:       'AAAA-MM-JJ',
                        icon:       Icons.cake_outlined,
                        readOnly:   true,
                        onTap:      _pickDate,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _FormField(
                        label:      'Téléphone',
                        controller: _phoneCtrl,
                        hint:       '06 XX XX XX XX',
                        icon:       Icons.phone_outlined,
                        keyboard:   TextInputType.phone,
                      ),
                    ),
                  ]),

                  const SizedBox(height: 24),
                  const _Divider(),
                  const SizedBox(height: 24),

                  // ── Compte ───────────────────────────
                  _SectionTitle(
                      icon: Icons.manage_accounts_outlined,
                      label: 'Compte'),
                  const SizedBox(height: 16),

                  Row(children: [
                    Expanded(
                      child: _FormField(
                        label:      'Adresse email *',
                        controller: _emailCtrl,
                        hint:       'nom@exemple.com',
                        icon:       Icons.email_outlined,
                        keyboard:   TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'Champ requis';
                          if (!v.contains('@'))
                            return 'Email invalide';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Role dropdown
                    Expanded(
                      child: _RoleDropdown(
                        value:     _selectedRole,
                        roles:     _roles,
                        onChanged: (v) =>
                            setState(() => _selectedRole = v),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // Status dropdown — edit only
                  _StatusDropdown(
                    value:     _selectedStatus,
                    statuses:  _statuses,
                    onChanged: (v) =>
                        setState(() => _selectedStatus = v),
                  ),

                  const SizedBox(height: 32),

                  // ── Actions ──────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => context.go('/admin/users'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(
                              color: AppColors.border, width: 0.8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9)),
                        ),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submit,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2))
                            : const Icon(Icons.save_outlined, size: 16),
                        label: Text(
                            _isSubmitting ? 'Mise à jour...' : 'Enregistrer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  WIDGETS PARTAGÉS (copiés depuis create_screen pour autonomie)
// ═══════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: AppColors.successBg,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 15, color: AppColors.primaryMid),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      ]);
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Container(height: 0.5, color: AppColors.borderLight);
}

class _FormField extends StatelessWidget {
  final String                     label;
  final TextEditingController      controller;
  final String                     hint;
  final IconData                   icon;
  final TextInputType              keyboard;
  final bool                       readOnly;
  final VoidCallback?              onTap;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>?  inputFormatters;

  const _FormField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboard        = TextInputType.text,
    this.readOnly        = false,
    this.onTap,
    this.validator,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextFormField(
            controller:      controller,
            keyboardType:    keyboard,
            readOnly:        readOnly,
            onTap:           onTap,
            validator:       validator,
            inputFormatters: inputFormatters,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText:  hint,
              hintStyle: const TextStyle(
                  fontSize: 12, color: AppColors.textMuted),
              prefixIcon:
                  Icon(icon, size: 16, color: AppColors.textMuted),
              filled:    true,
              fillColor: AppColors.bgInput,
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

class _RoleDropdown extends StatelessWidget {
  final String              value;
  final Map<String, String> roles;
  final void Function(String) onChanged;

  const _RoleDropdown({
    required this.value,
    required this.roles,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rôle *',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                isDense: true,
                icon: const Icon(Icons.keyboard_arrow_down,
                    size: 18, color: AppColors.textMuted),
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary),
                items: roles.entries.map((e) {
                  final (icon, color) = switch (e.key) {
                    'supervisor' => (
                        Icons.supervisor_account_outlined,
                        AppColors.info
                      ),
                    _ => (
                        Icons.person_pin_circle_outlined,
                        AppColors.primaryMid
                      ),
                  };
                  return DropdownMenuItem<String>(
                    value: e.key,
                    child: Row(children: [
                      Icon(icon, size: 15, color: color),
                      const SizedBox(width: 8),
                      Text(e.value),
                    ]),
                  );
                }).toList(),
                onChanged: (v) { if (v != null) onChanged(v); },
              ),
            ),
          ),
        ],
      );
}

class _StatusDropdown extends StatelessWidget {
  final String              value;
  final Map<String, String> statuses;
  final void Function(String) onChanged;

  const _StatusDropdown({
    required this.value,
    required this.statuses,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final (dotColor, _) = switch (value) {
      'active'   => (AppColors.success, ''),
      'inactive' => (AppColors.warning, ''),
      'banned'   => (AppColors.danger,  ''),
      _          => (AppColors.textMuted, ''),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Statut du compte *',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.bgInput,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down,
                  size: 18, color: AppColors.textMuted),
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textPrimary),
              items: statuses.entries.map((e) {
                final color = switch (e.key) {
                  'active'   => AppColors.success,
                  'inactive' => AppColors.warning,
                  'banned'   => AppColors.danger,
                  _          => AppColors.textMuted,
                };
                return DropdownMenuItem<String>(
                  value: e.key,
                  child: Row(children: [
                    Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(e.value),
                  ]),
                );
              }).toList(),
              onChanged: (v) { if (v != null) onChanged(v); },
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String       message;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppColors.danger.withOpacity(0.3), width: 0.5),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.danger))),
          GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.close,
                  size: 16, color: AppColors.danger)),
        ]),
      );
}