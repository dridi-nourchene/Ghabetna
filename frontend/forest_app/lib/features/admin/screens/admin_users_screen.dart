// features/admin/screens/admin_users_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../features/user/models/user_model.dart';
import '../../../features/user/providers/user_provider.dart';

// ═══════════════════════════════════════════════════════════════
//  AdminUsersScreen — Liste de tous les utilisateurs (non-admin)
//  Accessible via /admin/users
// ═══════════════════════════════════════════════════════════════

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  String _search      = '';
  String _roleFilter  = 'all';    // 'all' | 'supervisor' | 'agent'
  String _statusFilter= 'all';    // 'all' | 'active' | 'inactive' | 'banned'

  @override
  void initState() {
    super.initState();
    // Load users on first render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userListProvider.notifier).loadUsers();
    });
  }

  // ── Filtered list ─────────────────────────────────────
  List<AppUser> _filtered(List<AppUser> users) {
    return users.where((u) {
      final matchSearch = _search.isEmpty ||
          u.fullName.toLowerCase().contains(_search.toLowerCase()) ||
          u.email.toLowerCase().contains(_search.toLowerCase()) ||
          u.cin.contains(_search);
      final matchRole   = _roleFilter  == 'all' || u.role   == _roleFilter;
      final matchStatus = _statusFilter == 'all' || u.status == _statusFilter;
      return matchSearch && matchRole && matchStatus;
    }).toList();
  }

  // ── Delete confirmation dialog ────────────────────────
  Future<void> _confirmDelete(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 22),
            SizedBox(width: 8),
            Text('Confirmer la suppression',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary,
                height: 1.5),
            children: [
              const TextSpan(text: 'Voulez-vous supprimer '),
              TextSpan(
                text: user.fullName,
                style: const TextStyle(fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              const TextSpan(
                  text: ' ? Cette action est irréversible.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(userListProvider.notifier).deleteUser(user.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state   = ref.watch(userListProvider);
    final users   = _filtered(state.allUsers);

    // Show error snackbar
    ref.listen<UserListState>(userListProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.error!),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
        ref.read(userListProvider.notifier).clearError();
      }
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête ──────────────────────────────────
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Utilisateurs',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3)),
                  SizedBox(height: 3),
                  Text('Gérez les superviseurs et agents.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
              const Spacer(),
              // Bouton créer utilisateur
              ElevatedButton.icon(
                onPressed: () => context.go('/admin/users/new'),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Créer un utilisateur',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Filters + Search ──────────────────────────
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    // Search
                    Expanded(
                      flex: 3,
                      child: _SearchField(
                        onChanged: (v) => setState(() => _search = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Role filter
                    _FilterDropdown(
                      value: _roleFilter,
                      label: 'Rôle',
                      items: const {
                        'all':        'Tous les rôles',
                        'supervisor': 'Superviseur',
                        'agent':      'Agent',
                      },
                      onChanged: (v) => setState(() => _roleFilter = v),
                    ),
                    const SizedBox(width: 10),
                    // Status filter
                    _FilterDropdown(
                      value: _statusFilter,
                      label: 'Statut',
                      items: const {
                        'all':      'Tous les statuts',
                        'active':   'Actif',
                        'inactive': 'Inactif',
                        'banned':   'Banni',
                      },
                      onChanged: (v) => setState(() => _statusFilter = v),
                    ),
                    const SizedBox(width: 10),
                    // Refresh button
                    IconButton(
                      tooltip: 'Rafraîchir',
                      onPressed: () =>
                          ref.read(userListProvider.notifier).loadUsers(),
                      icon: const Icon(Icons.refresh,
                          size: 18, color: AppColors.textSecondary),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.bgInput,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Counter ──────────────────────────────
                Row(
                  children: [
                    Text(
                      '${users.length} utilisateur${users.length != 1 ? 's' : ''}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                    ),
                    const SizedBox(width: 8),
                    if (state.activeUsers.isNotEmpty)
                      _CountBadge(
                          label: '${state.activeUsers.length} actifs',
                          color: AppColors.success),
                    const SizedBox(width: 6),
                    if (state.inactiveUsers.isNotEmpty)
                      _CountBadge(
                          label: '${state.inactiveUsers.length} en attente',
                          color: AppColors.warning),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Table ─────────────────────────────────────
          AppCard(
            padding: EdgeInsets.zero,
            child: state.isLoading
                ? const _LoadingState()
                : users.isEmpty
                    ? const _EmptyState()
                    : _UsersTable(
                        users:      users,
                        deletingIds: state.deletingIds,
                        onDelete:   _confirmDelete,
                        onEdit:     (user) =>
                            context.go('/admin/users/${user.userId}'),
                      ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TABLE
// ═══════════════════════════════════════════════════════════════

class _UsersTable extends StatelessWidget {
  final List<AppUser> users;
  final Set<String>   deletingIds;
  final void Function(AppUser) onDelete;
  final void Function(AppUser) onEdit;

  const _UsersTable({
    required this.users,
    required this.deletingIds,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header row
        _TableHeader(),
        // Data rows
        ...users.map((user) => _UserTableRow(
              user:       user,
              isDeleting: deletingIds.contains(user.userId),
              onDelete:   () => onDelete(user),
              onEdit:     () => onEdit(user),
            )),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.bgInput,
        border: Border(
            bottom: BorderSide(color: AppColors.borderLight, width: 0.5)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: const Row(
        children: [
          SizedBox(width: 36),   // avatar placeholder
          SizedBox(width: 12),
          Expanded(flex: 4, child: _HeaderCell('Nom complet')),
          Expanded(flex: 3, child: _HeaderCell('Email')),
          Expanded(flex: 2, child: _HeaderCell('CIN')),
          Expanded(flex: 2, child: _HeaderCell('Rôle')),
          Expanded(flex: 2, child: _HeaderCell('Statut')),
          SizedBox(width: 90),   // actions
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  const _HeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.3));
  }
}

class _UserTableRow extends StatelessWidget {
  final AppUser     user;
  final bool        isDeleting;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _UserTableRow({
    required this.user,
    required this.isDeleting,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isDeleting ? 0.4 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(color: AppColors.borderLight, width: 0.5)),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: _avatarBg(user.role),
              child: Text(user.initials,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _avatarFg(user.role))),
            ),
            const SizedBox(width: 12),
            // Name
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary)),
                  if (user.phone != null)
                    Text(user.phone!,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textMuted)),
                ],
              ),
            ),
            // Email
            Expanded(
              flex: 3,
              child: Text(user.email,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis),
            ),
            // CIN
            Expanded(
              flex: 2,
              child: Text(user.cin,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontFamily: 'monospace')),
            ),
            // Role badge
            Expanded(
              flex: 2,
              child: _RoleBadge(role: user.role),
            ),
            // Status badge
            Expanded(
              flex: 2,
              child: _StatusBadge(status: user.status),
            ),
            // Actions
            SizedBox(
              width: 90,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Edit
                  _ActionButton(
                    icon: Icons.edit_outlined,
                    color: AppColors.primaryMid,
                    tooltip: 'Modifier',
                    onTap: isDeleting ? null : onEdit,
                  ),
                  const SizedBox(width: 6),
                  // Delete
                  _ActionButton(
                    icon: isDeleting
                        ? Icons.hourglass_empty
                        : Icons.delete_outline,
                    color: AppColors.danger,
                    tooltip: 'Supprimer',
                    onTap: isDeleting ? null : onDelete,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _avatarBg(String role) => switch (role) {
        'supervisor' => AppColors.infoBg,
        'agent'      => AppColors.successBg,
        _            => AppColors.warningBg,
      };

  Color _avatarFg(String role) => switch (role) {
        'supervisor' => AppColors.info,
        'agent'      => AppColors.primaryMid,
        _            => const Color(0xFF92400E),
      };
}

// ═══════════════════════════════════════════════════════════════
//  SMALL WIDGETS
// ═══════════════════════════════════════════════════════════════

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (role) {
      'supervisor' => ('Superviseur', AppColors.infoBg,     AppColors.info),
      'agent'      => ('Agent',       AppColors.successBg,  AppColors.primaryMid),
      'admin'      => ('Admin',       AppColors.warningBg,  const Color(0xFF92400E)),
      _            => (role,          AppColors.bgInput,    AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'active'   => ('Actif',    AppColors.success),
      'inactive' => ('Inactif',  AppColors.warning),
      'banned'   => ('Banni',    AppColors.danger),
      _          => (status,     AppColors.textMuted),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7, height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData      icon;
  final Color         color;
  final String        tooltip;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: color.withOpacity(0.2), width: 0.5),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final void Function(String) onChanged;
  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Rechercher par nom, email, CIN...',
          hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          prefixIcon: const Icon(Icons.search, size: 16,
              color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.bgInput,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border, width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
                color: AppColors.primaryMid, width: 1.2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          isDense: true,
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String              value;
  final String              label;
  final Map<String, String> items;
  final void Function(String) onChanged;

  const _FilterDropdown({
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          style: const TextStyle(
              fontSize: 12, color: AppColors.textPrimary),
          icon: const Icon(Icons.keyboard_arrow_down,
              size: 16, color: AppColors.textMuted),
          items: items.entries
              .map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value),
                  ))
              .toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final String label;
  final Color  color;
  const _CountBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }
}

// ── States ────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(
              color: AppColors.primaryMid,
              strokeWidth: 2.5,
            ),
            SizedBox(height: 16),
            Text('Chargement des utilisateurs...',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.people_outline, size: 40, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text('Aucun utilisateur trouvé',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            SizedBox(height: 4),
            Text('Essayez de modifier vos filtres.',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ── StatusPill (réutilisé depuis admin_dashboard) ─────────
// Placé ici pour éviter les imports croisés
class StatusPill extends StatelessWidget {
  final String label;
  final Color  bg;
  final Color  fg;

  const StatusPill._({required this.label, required this.bg, required this.fg});

  factory StatusPill.active()  => const StatusPill._(
      label: 'Actif', bg: Color(0xFFDCFCE7), fg: Color(0xFF166534));
  factory StatusPill.pending() => const StatusPill._(
      label: 'En attente', bg: Color(0xFFFEF9C3), fg: Color(0xFF92400E));
  factory StatusPill.newUser() => const StatusPill._(
      label: 'Nouveau', bg: Color(0xFFDBEAFE), fg: Color(0xFF1E40AF));

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
      );
}