import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

// ═══════════════════════════════════════════════════════════════
//  AdminShell — layout racine pour toutes les pages Admin
//  Structure :
//    Column
//      └─ _TopBar          (blanc, full width, height 58)
//      └─ Row (Expanded)
//           ├─ _Sidebar    (vert #1A4731, width 68, icônes)
//           └─ child       (contenu de la page)
// ═══════════════════════════════════════════════════════════════

// FIX: was StatefulWidget — now ConsumerStatefulWidget so we can access ref
// for logout and to pass auth data down to child widgets.
class AdminShell extends ConsumerStatefulWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  bool _expanded = false;

  void _toggleSidebar() => setState(() => _expanded = !_expanded);

  // FIX: real logout — clears tokens from storage AND navigates
  Future<void> _handleLogout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    // Read auth state once to pass down to TopBar/Sidebar
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Column(
        children: [
          _TopBar(onMenuTap: _toggleSidebar, auth: auth),
          Expanded(
            child: Row(
              children: [
                _Sidebar(
                  expanded:     _expanded,
                  auth:         auth,
                  onLogoutTap:  _handleLogout,
                ),
                Expanded(
                  child: ClipRect(child: widget.child),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
//  TOP BAR
// ───────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onMenuTap;
  final AuthState    auth;         // FIX: receives real auth state

  const _TopBar({required this.onMenuTap, required this.auth});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            child: Center(
              child: _HamburgerButton(onTap: onMenuTap),
            ),
          ),
          const _LogoArea(),
          const SizedBox(width: 4),
          const _SearchBar(),
          const Spacer(),
          const _NotifButton(),
          const SizedBox(width: 10),
          // FIX: pass real auth data
          _UserZone(auth: auth),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

class _HamburgerButton extends StatelessWidget {
  final VoidCallback onTap;
  const _HamburgerButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: AppColors.bgInput,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (_) => Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            width: 16, height: 1.8,
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(2),
            ),
          )),
        ),
      ),
    );
  }
}

class _LogoArea extends StatelessWidget {
  const _LogoArea();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(right: 14, left: 4),
      margin: const EdgeInsets.only(right: 4),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Center(
              child: Icon(Icons.park, color: AppColors.primaryAccent, size: 18),
            ),
          ),
          const SizedBox(width: 9),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Ghabetna',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3)),
              Text('DGF · Forêts',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220, height: 34,
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.search, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Rechercher...',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF1EC),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('⌘F',
                style: TextStyle(fontSize: 10, color: Color(0xFFC0C8B8))),
          ),
        ],
      ),
    );
  }
}

class _NotifButton extends StatelessWidget {
  const _NotifButton();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppColors.bgInput,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: const Icon(Icons.notifications_none,
              size: 16, color: AppColors.textSecondary),
        ),
        Positioned(
          top: 6, right: 6,
          child: Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              color: AppColors.danger,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ── User Zone ─────────────────────────────────────────────────
// FIX: was StatelessWidget with hardcoded const strings.
// Now receives AuthState and derives display name/initials from real role.
class _UserZone extends StatelessWidget {
  final AuthState auth;
  const _UserZone({required this.auth});

  // Derive a display label from the role stored in the JWT
  String get _roleLabel => switch (auth.role) {
        'admin'      => 'Administrateur DGF',
        'supervisor' => 'Superviseur',
        'agent'      => 'Agent de terrain',
        _            => auth.role ?? 'Utilisateur',
      };

  // Until you store the full name in the token, show role-based initials
  String get _initials => switch (auth.role) {
        'admin'      => 'AD',
        'supervisor' => 'SV',
        'agent'      => 'AG',
        _            => '?',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: AppColors.primaryDark,
            child: Text(_initials,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFC8E6D8))),
          ),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_roleLabel,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              Text(auth.role ?? '',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(width: 6),
          const Icon(Icons.keyboard_arrow_down,
              size: 16, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
//  SIDEBAR
// ───────────────────────────────────────────────────────────────

// FIX: was StatelessWidget with no access to ref or logout callback.
// Now receives onLogoutTap from the parent ConsumerStatefulWidget.
class _Sidebar extends StatelessWidget {
  final bool          expanded;
  final AuthState     auth;
  final VoidCallback  onLogoutTap;

  const _Sidebar({
    required this.expanded,
    required this.auth,
    required this.onLogoutTap,
  });

  String get _initials => switch (auth.role) {
        'admin'      => 'AD',
        'supervisor' => 'SV',
        'agent'      => 'AG',
        _            => '?',
      };

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: expanded ? 200 : 68,
      color: AppColors.primaryDark,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  _SidebarItem(
                    icon: Icons.grid_view_rounded,
                    label: 'Dashboard',
                    route: '/admin/dashboard',
                    currentLocation: location,
                    expanded: expanded,
                  ),
                  _SidebarItem(
                    icon: Icons.people_outline,
                    label: 'Utilisateurs',
                    route: '/admin/users',
                    currentLocation: location,
                    expanded: expanded,
                    badgeCount: 8,
                  ),
                  _SidebarItem(
                    icon: Icons.park_outlined,
                    label: 'Forêts',
                    route: '/admin/forests',
                    currentLocation: location,
                    expanded: expanded,
                  ),
                  const _SidebarDivider(),
                  _SidebarItem(
                    icon: Icons.notifications_none,
                    label: 'Alertes',
                    route: '/admin/alerts',
                    currentLocation: location,
                    expanded: expanded,
                    badgeCount: 5,
                  ),
                  _SidebarItem(
                    icon: Icons.bar_chart_rounded,
                    label: 'Rapports',
                    route: '/admin/reports',
                    currentLocation: location,
                    expanded: expanded,
                  ),
                  const _SidebarDivider(),
                  _SidebarItem(
                    icon: Icons.settings_outlined,
                    label: 'Paramètres',
                    route: '/admin/settings',
                    currentLocation: location,
                    expanded: expanded,
                  ),
                ],
              ),
            ),
          ),
          // ── Déconnexion + avatar en bas ──────────────────────
          Container(
            decoration: const BoxDecoration(
              border: Border(
                  top: BorderSide(color: AppColors.sidebarDivider, width: 0.5)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                // FIX: no longer navigates via route — calls onLogoutTap
                // which runs authProvider.logout() THEN context.go('/login')
                _SidebarItem(
                  icon: Icons.logout,
                  label: 'Déconnexion',
                  route: '',                  // unused for logout
                  currentLocation: location,
                  expanded: expanded,
                  isDanger: true,
                  onTapOverride: onLogoutTap, // FIX: real logout handler
                ),
                const SizedBox(height: 8),
                CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.sidebarActive,
                  child: Text(_initials,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData      icon;
  final String        label;
  final String        route;
  final String        currentLocation;
  final bool          expanded;
  final int?          badgeCount;
  final bool          isDanger;
  // FIX: optional override tap handler (used for logout)
  final VoidCallback? onTapOverride;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentLocation,
    required this.expanded,
    this.badgeCount,
    this.isDanger    = false,
    this.onTapOverride,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = route.isNotEmpty &&
        currentLocation.startsWith(route) &&
        !isDanger;
    final iconColor = isDanger
        ? AppColors.danger
        : isActive
            ? Colors.white
            : Colors.white.withOpacity(0.6);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: GestureDetector(
        // FIX: use override if provided, otherwise normal route navigation
        onTap: onTapOverride ?? () => context.go(route),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          height: 44,
          decoration: BoxDecoration(
            color: isActive ? AppColors.sidebarActive : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: expanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              if (expanded) const SizedBox(width: 12),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 20, color: iconColor),
                  if (badgeCount != null && badgeCount! > 0)
                    Positioned(
                      top: -3, right: -4,
                      child: Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.primaryDark, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 13,
                          color: iconColor,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400)),
                ),
                if (badgeCount != null && badgeCount! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.sidebarActive
                          : AppColors.sidebarHover,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$badgeCount',
                        style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarDivider extends StatelessWidget {
  const _SidebarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      height: 0.5,
      color: AppColors.sidebarDivider,
    );
  }
}