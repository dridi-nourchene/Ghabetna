import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:agent_app/core/theme/app_colors.dart';
import 'package:agent_app/features/auth/providers/auth_provider.dart';

class MainScaffold extends ConsumerWidget {
  final Widget child;
  final String location;

  const MainScaffold({
    super.key,
    required this.child,
    required this.location,
  });

  int _selectedIndex(String location) {
    if (location.startsWith('/home'))         return 0;
    if (location.startsWith('/create-alert')) return 1;
    if (location.startsWith('/my-alerts'))    return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _selectedIndex(location);

    return Scaffold(
      backgroundColor: AgentColors.bgPage,
      body: child,
      bottomNavigationBar: _GhabetnaBottomNav(
        selectedIndex: selectedIndex,
        onTap: (index) async {
          switch (index) {
            case 0:
              context.go('/home');
              break;
            case 1:
              context.go('/create-alert');
              break;
            case 2:
              context.go('/my-alerts');
              break;
            case 3:
              // Logout
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
              break;
          }
        },
      ),
    );
  }
}

class _GhabetnaBottomNav extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onTap;

  const _GhabetnaBottomNav({
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset:     const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon:     Icons.home_rounded,
                label:    'Accueil',
                selected: selectedIndex == 0,
                onTap:    () => onTap(0),
              ),
              _NavItem(
                icon:     Icons.warning_amber_rounded,
                label:    'Alerte',
                selected: selectedIndex == 1,
                onTap:    () => onTap(1),
              ),
              _NavItem(
                icon:     Icons.list_alt_rounded,
                label:    'Historique',
                selected: selectedIndex == 2,
                onTap:    () => onTap(2),
              ),
              _NavItem(
                icon:     Icons.logout_rounded,
                label:    'Déconnexion',
                selected: false,
                onTap:    () => _confirmLogout(context, () => onTap(3)),
                isLogout: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Déconnexion',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700,
                color: Color(0xFF1A2E1A))),
        content: const Text('Voulez-vous vraiment vous déconnecter ?',
            style: TextStyle(fontSize: 14, color: Color(0xFF4A6454))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler',
                style: TextStyle(color: Color(0xFF8FA896))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A4731),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     selected;
  final bool     isLogout;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.isLogout = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor  = const Color(0xFF1A4731);
    final inactiveColor = const Color(0xFF8FA896);
    final logoutColor  = const Color(0xFFE05C2A);

    final color = isLogout
        ? logoutColor
        : selected
            ? activeColor
            : inactiveColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1A4731).withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale:    selected ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize:   10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color:      color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}