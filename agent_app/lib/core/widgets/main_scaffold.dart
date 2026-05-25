// lib/core/widgets/main_scaffold.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_app/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:agent_app/core/theme/app_colors.dart';
import 'package:agent_app/core/widgets/lang_toggle.dart';
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
    final l10n          = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AgentColors.bgPage,

      // ── AppBar global avec le toggle ─────────────────
      appBar: AppBar(
        backgroundColor:   Colors.white,
        elevation:         0,
        automaticallyImplyLeading: false,
        centerTitle:       false,
        title: Row(children: [
          Image.asset(
            'assets/images/logo.png',
            width: 52, height: 52,
            errorBuilder: (_, __, ___) => Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color:        AgentColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.park, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          Text(l10n.appTitle,
              style: const TextStyle(
                  fontSize:   17,
                  fontWeight: FontWeight.w700,
                  color:      AgentColors.textPrimary)),
        ]),
        actions: const [
          LangToggle(),
          SizedBox(width: 12),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: const Color(0xFFE8EDE8)),
        ),
      ),

      body: child,

      bottomNavigationBar: _GhabetnaBottomNav(
        selectedIndex: selectedIndex,
        l10n: l10n,
        onTap: (index) async {
          switch (index) {
            case 0: context.go('/home');         break;
            case 1: context.go('/create-alert'); break;
            case 2: context.go('/my-alerts');    break;
            case 3:
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
  final AppLocalizations l10n;
  final void Function(int) onTap;

  const _GhabetnaBottomNav({
    required this.selectedIndex,
    required this.l10n,
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
                label:    l10n.navHome,
                selected: selectedIndex == 0,
                onTap:    () => onTap(0),
              ),
              _NavItem(
                icon:     Icons.warning_amber_rounded,
                label:    l10n.navAlert,
                selected: selectedIndex == 1,
                onTap:    () => onTap(1),
              ),
              _NavItem(
                icon:     Icons.list_alt_rounded,
                label:    l10n.navHistory,
                selected: selectedIndex == 2,
                onTap:    () => onTap(2),
              ),
              _NavItem(
                icon:     Icons.logout_rounded,
                label:    l10n.navLogout,
                selected: false,
                onTap:    () => _confirmLogout(context, l10n, () => onTap(3)),
                isLogout: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout(
      BuildContext context, AppLocalizations l10n, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.logoutTitle,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700,
                color: Color(0xFF1A2E1A))),
        content: Text(l10n.logoutMessage,
            style: const TextStyle(fontSize: 14, color: Color(0xFF4A6454))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.logoutCancel,
                style: const TextStyle(color: Color(0xFF8FA896))),
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
            child: Text(l10n.logoutConfirm),
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
    final activeColor   = const Color(0xFF1A4731);
    final inactiveColor = const Color(0xFF8FA896);
    final logoutColor   = const Color(0xFFE05C2A);

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