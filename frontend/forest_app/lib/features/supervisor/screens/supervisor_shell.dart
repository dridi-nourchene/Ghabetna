// features/supervisor/screens/supervisor_shell.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:forest_app/core/theme/app_colors.dart';
import 'package:forest_app/features/auth/providers/auth_provider.dart';

class SupervisorShell extends ConsumerStatefulWidget {
  final Widget child;
  const SupervisorShell({super.key, required this.child});

  @override
  ConsumerState<SupervisorShell> createState() => _SupervisorShellState();
}

class _SupervisorShellState extends ConsumerState<SupervisorShell> {
  bool _expanded = false;

  void _toggleSidebar() => setState(() => _expanded = !_expanded);

  Future<void> _handleLogout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      // ← FIX : utiliser Scaffold avec appBar + body séparés
      // pour que flutter_map et les autres screens aient
      // une hauteur définie correctement
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(58),
        child: _TopBar(onMenuTap: _toggleSidebar, auth: auth),
      ),
      body: Row(
        children: [
          _Sidebar(
            expanded:    _expanded,
            auth:        auth,
            onLogoutTap: _handleLogout,
          ),
          // ← FIX : Expanded + SizedBox.expand pour que le child
          // ait une contrainte de taille explicite (width + height)
          // sans ça flutter_map ne peut pas calculer sa hauteur
          Expanded(
            child: SizedBox.expand(
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top Bar ────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onMenuTap;
  final AuthState    auth;
  const _TopBar({required this.onMenuTap, required this.auth});

  @override
  Widget build(BuildContext context) => Container(
        height: 58,
        decoration: const BoxDecoration(
          color:  Colors.white,
          border: Border(
              bottom: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Row(children: [
          SizedBox(
            width: 68,
            child: Center(child: _HamburgerButton(onTap: onMenuTap)),
          ),
          const _LogoArea(),
          const SizedBox(width: 4),
          const _SearchBar(),
          const Spacer(),
          // Badge rôle superviseur
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:        const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF1565C0).withOpacity(0.3), width: 0.5),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.supervisor_account_outlined,
                  size: 13, color: Color(0xFF1565C0)),
              SizedBox(width: 5),
              Text('Superviseur',
                  style: TextStyle(
                      fontSize:   11,
                      fontWeight: FontWeight.w600,
                      color:      Color(0xFF1565C0))),
            ]),
          ),
          const SizedBox(width: 12),
          _UserZone(auth: auth),
          const SizedBox(width: 16),
        ]),
      );
}

class _HamburgerButton extends StatelessWidget {
  final VoidCallback onTap;
  const _HamburgerButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color:        AppColors.bgInput,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (_) => Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                width: 16, height: 1.8,
                decoration: BoxDecoration(
                  color:        AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      );
}

class _LogoArea extends StatelessWidget {
  const _LogoArea();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(right: 14, left: 4),
        margin:  const EdgeInsets.only(right: 4),
        decoration: const BoxDecoration(
          border: Border(
              right: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color:        AppColors.primaryDark,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Center(
              child: Icon(Icons.park,
                  color: AppColors.primaryAccent, size: 18),
            ),
          ),
          const SizedBox(width: 9),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:  MainAxisAlignment.center,
            children: [
              Text('Ghabetna',
                  style: TextStyle(
                      fontSize:      15,
                      fontWeight:    FontWeight.w700,
                      color:         AppColors.textPrimary,
                      letterSpacing: -0.3)),
              Text('DGF · Superviseur',
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textMuted)),
            ],
          ),
        ]),
      );
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) => Container(
        width: 220, height: 34,
        decoration: BoxDecoration(
          color:        AppColors.bgInput,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          const Icon(Icons.search, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Rechercher...',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color:        const Color(0xFFEFF1EC),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('⌘F',
                style: TextStyle(fontSize: 10, color: Color(0xFFC0C8B8))),
          ),
        ]),
      );
}

class _UserZone extends StatelessWidget {
  final AuthState auth;
  const _UserZone({required this.auth});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:        AppColors.bgInput,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius:          15,
            backgroundColor: AppColors.primaryDark,
            child: const Text('SV',
                style: TextStyle(
                    fontSize:   11,
                    fontWeight: FontWeight.w600,
                    color:      Color(0xFFC8E6D8))),
          ),
          const SizedBox(width: 9),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize:       MainAxisSize.min,
            children: [
              Text('Superviseur DGF',
                  style: TextStyle(
                      fontSize:   12,
                      fontWeight: FontWeight.w600,
                      color:      AppColors.textPrimary)),
              Text('supervisor',
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(width: 6),
          const Icon(Icons.keyboard_arrow_down,
              size: 16, color: AppColors.textMuted),
        ]),
      );
}

// ── Sidebar ────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final bool         expanded;
  final AuthState    auth;
  final VoidCallback onLogoutTap;

  const _Sidebar({
    required this.expanded,
    required this.auth,
    required this.onLogoutTap,
  });

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve:    Curves.easeInOut,
      width:    expanded ? 200 : 68,
      color:    AppColors.primaryDark,
      child: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(children: [
              const SizedBox(height: 12),

              _SidebarItem(
                icon:            Icons.map_outlined,
                label:           'Carte & Alertes',
                route:           '/supervisor/map',
                currentLocation: location,
                expanded:        expanded,
              ),
              _SidebarItem(
                icon:            Icons.history,
                label:           'Historique',
                route:           '/supervisor/alerts',
                currentLocation: location,
                expanded:        expanded,
              ),
            ]),
          ),
        ),

        // ── Footer ────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            border: Border(
                top: BorderSide(
                    color: AppColors.sidebarDivider, width: 0.5)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(children: [
            _SidebarItem(
              icon:            Icons.logout,
              label:           'Déconnexion',
              route:           '',
              currentLocation: location,
              expanded:        expanded,
              isDanger:        true,
              onTapOverride:   onLogoutTap,
            ),
            const SizedBox(height: 8),
            const CircleAvatar(
              radius:          17,
              backgroundColor: AppColors.sidebarActive,
              child: Text('SV',
                  style: TextStyle(
                      fontSize:   11,
                      fontWeight: FontWeight.w600,
                      color:      Colors.white)),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData      icon;
  final String        label;
  final String        route;
  final String        currentLocation;
  final bool          expanded;
  final bool          isDanger;
  final VoidCallback? onTapOverride;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentLocation,
    required this.expanded,
    this.isDanger     = false,
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
        onTap: onTapOverride ?? () => context.go(route),
        child: AnimatedContainer(
          duration:    const Duration(milliseconds: 150),
          width:       double.infinity,
          height:      44,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.sidebarActive
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: expanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              if (expanded) const SizedBox(width: 12),
              Icon(icon, size: 20, color: iconColor),
              if (expanded) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize:   13,
                          color:      iconColor,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400)),
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