// features/admin/screens/admin_assign_superviseurs_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../features/assignment/models/assignment_model.dart';
import '../../../features/assignment/providers/assignment_provider.dart';
import '../../../features/forest/models/forest_model.dart';
import '../../../features/forest/providers/forest_provider.dart';

class AdminAssignSuperveursScreen extends ConsumerStatefulWidget {
  const AdminAssignSuperveursScreen({super.key});

  @override
  ConsumerState<AdminAssignSuperveursScreen> createState() =>
      _AdminAssignSuperveursScreenState();
}

class _AdminAssignSuperveursScreenState
    extends ConsumerState<AdminAssignSuperveursScreen> {
  SuperviseurStatus? _selectedSup;
  Forest?            _selectedForest;
  String             _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(superviseurAssignmentProvider.notifier).loadSuperviseurs();
      ref.read(forestListProvider.notifier).loadForests();
    });
  }

  Future<void> _handleAssign() async {
    if (_selectedSup == null || _selectedForest == null) return;

    final ok = await ref
        .read(superviseurAssignmentProvider.notifier)
        .assignSuperviseur(
          forestId:      _selectedForest!.id,
          forestName:    _selectedForest!.name,
          superviseurId: _selectedSup!.userId,
        );

    if (ok && mounted) {
      setState(() {
        _selectedSup    = null;
        _selectedForest = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state       = ref.watch(superviseurAssignmentProvider);
    final forestState = ref.watch(forestListProvider);

    ref.listen<SuperviseurAssignmentState>(superviseurAssignmentProvider,
        (_, next) {
      if (next.successMessage != null) {
        _showSnack(next.successMessage!, AppColors.success);
        ref.read(superviseurAssignmentProvider.notifier).clearMessages();
      }
      if (next.error != null) {
        _showSnack(next.error!, AppColors.danger);
        ref.read(superviseurAssignmentProvider.notifier).clearMessages();
      }
    });

    // Filtrage liste droite
    final recents = state.recentAssigned.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return s.nom.toLowerCase().contains(q) ||
          s.email.toLowerCase().contains(q) ||
          s.currentForests.any(
              (f) => f.forestName.toLowerCase().contains(q));
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────
          const Text(
            'Affecter les superviseurs',
            style: TextStyle(
              fontSize:   20,
              fontWeight: FontWeight.w700,
              color:      AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Associez un superviseur à une forêt.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Gauche — Formulaire ──────────────────────
              Expanded(
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.infoBg,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(Icons.link,
                              size: 15, color: AppColors.info),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nouvelle affectation',
                                style: TextStyle(
                                    fontSize:   13,
                                    fontWeight: FontWeight.w600,
                                    color:      AppColors.textPrimary)),
                            Text('Choisissez un superviseur puis une forêt',
                                style: TextStyle(
                                    fontSize: 10,
                                    color:    AppColors.textMuted)),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 20),

                      // Dropdown superviseur
                      const _FieldLabel('Superviseur *'),
                      const SizedBox(height: 6),
                      _SuperviseurDropdown(
                        superviseurs: state.superviseurs,
                        selected:     _selectedSup,
                        onSelect:     (s) => setState(() => _selectedSup = s),
                      ),
                      const SizedBox(height: 14),

                      // Dropdown forêt
                      const _FieldLabel('Forêt *'),
                      const SizedBox(height: 6),
                      _ForestDropdown(
                        forests:  forestState.forests,
                        selected: _selectedForest,
                        onSelect: (f) => setState(() => _selectedForest = f),
                      ),
                      const SizedBox(height: 20),

                      // Info si superviseur déjà affecté
                      if (_selectedSup != null &&
                          _selectedSup!.isAssigned &&
                          _selectedSup!.currentForests.isNotEmpty)
                        _InfoBanner(
                          message:
                              '${_selectedSup!.nom} supervise déjà : '
                              '${_selectedSup!.currentForests.map((f) => f.forestName).join(', ')}. '
                              'Une nouvelle affectation sera ajoutée.',
                        ),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: (_selectedSup != null &&
                                  _selectedForest != null &&
                                  !state.isLoading)
                              ? _handleAssign
                              : null,
                          icon: state.isLoading
                              ? const SizedBox(
                                  width: 14, height: 14,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check, size: 16),
                          label: Text(state.isLoading
                              ? 'Affectation...'
                              : 'Confirmer l\'affectation'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.info,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                AppColors.info.withOpacity(0.4),
                            elevation: 0,
                            padding:
                                const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // ── Droite — Récents ─────────────────────────
              Expanded(
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.infoBg,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(Icons.history,
                              size: 15, color: AppColors.info),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Affectations récentes',
                                style: TextStyle(
                                    fontSize:   13,
                                    fontWeight: FontWeight.w600,
                                    color:      AppColors.textPrimary)),
                            Text(
                              state.recentAssigned.isEmpty
                                  ? 'Aucune affectation pour l\'instant'
                                  : '${state.recentAssigned.length} superviseur${state.recentAssigned.length != 1 ? 's' : ''} affecté${state.recentAssigned.length != 1 ? 's' : ''}',
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 14),

                      _SearchBar(
                        hint: 'Rechercher par nom, email, forêt...',
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                      const SizedBox(height: 12),

                      if (state.isLoading && state.superviseurs.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 30),
                            child: CircularProgressIndicator(
                                color: AppColors.info, strokeWidth: 2),
                          ),
                        )
                      else if (recents.isEmpty)
                        const _EmptyRecents(
                            message:
                                'Aucun superviseur affecté pour l\'instant')
                      else
                        ...recents
                            .map((s) => _SuperviseurRecentCard(sup: s)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }
}

// ══════════════════════════════════════════════════════════════
//  WIDGETS
// ══════════════════════════════════════════════════════════════

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize:   11,
          fontWeight: FontWeight.w600,
          color:      AppColors.textSecondary));
}

// ── Dropdown Superviseurs ──────────────────────────────────────
class _SuperviseurDropdown extends StatefulWidget {
  final List<SuperviseurStatus>       superviseurs;
  final SuperviseurStatus?            selected;
  final void Function(SuperviseurStatus) onSelect;

  const _SuperviseurDropdown({
    required this.superviseurs,
    required this.selected,
    required this.onSelect,
  });

  @override
  State<_SuperviseurDropdown> createState() => _SuperviseurDropdownState();
}

class _SuperviseurDropdownState extends State<_SuperviseurDropdown> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      GestureDetector(
        onTap: () => setState(() => _open = !_open),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.bgInput,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _open ? AppColors.info : AppColors.border,
              width: _open ? 1.2 : 0.5,
            ),
          ),
          child: Row(children: [
            const Icon(Icons.manage_accounts_outlined,
                size: 16, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.selected?.nom ?? 'Choisir un superviseur...',
                style: TextStyle(
                  fontSize: 13,
                  color: widget.selected != null
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                ),
              ),
            ),
            if (widget.selected != null)
              _StatusBadge(
                  isAssigned: widget.selected!.isAssigned,
                  assignedColor: AppColors.info),
            const SizedBox(width: 6),
            Icon(
              _open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 16, color: AppColors.textMuted,
            ),
          ]),
        ),
      ),
      if (_open)
        Container(
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(
            color:        AppColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border:       Border.all(color: AppColors.border, width: 0.5),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset:     const Offset(0, 4),
              ),
            ],
          ),
          child: widget.superviseurs.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Aucun superviseur disponible.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textMuted),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding:    EdgeInsets.zero,
                  itemCount:  widget.superviseurs.length,
                  itemBuilder: (_, i) {
                    final s          = widget.superviseurs[i];
                    final isSelected =
                        widget.selected?.userId == s.userId;
                    return GestureDetector(
                      onTap: () {
                        widget.onSelect(s);
                        setState(() => _open = false);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.infoBg
                              : s.isAssigned
                                  ? AppColors.bgInput
                                  : AppColors.bgCard,
                          border: Border(
                            bottom: BorderSide(
                                color: AppColors.borderLight, width: 0.5),
                          ),
                        ),
                        child: Row(children: [
                          _Avatar(initials: s.initials, color: AppColors.info),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.nom,
                                    style: const TextStyle(
                                        fontSize:   12,
                                        fontWeight: FontWeight.w500,
                                        color:      AppColors.textPrimary)),
                                if (s.isAssigned &&
                                    s.currentForests.isNotEmpty)
                                  Text(
                                    s.currentForests
                                        .map((f) => f.forestName)
                                        .join(', '),
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color:    AppColors.textMuted),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          _StatusBadge(
                              isAssigned:    s.isAssigned,
                              assignedColor: AppColors.info),
                        ]),
                      ),
                    );
                  },
                ),
        ),
    ]);
  }
}

// ── Dropdown Forêts ────────────────────────────────────────────
class _ForestDropdown extends StatefulWidget {
  final List<Forest>       forests;
  final Forest?            selected;
  final void Function(Forest) onSelect;

  const _ForestDropdown({
    required this.forests,
    required this.selected,
    required this.onSelect,
  });

  @override
  State<_ForestDropdown> createState() => _ForestDropdownState();
}

class _ForestDropdownState extends State<_ForestDropdown> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      GestureDetector(
        onTap: () => setState(() => _open = !_open),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.bgInput,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _open ? AppColors.info : AppColors.border,
              width: _open ? 1.2 : 0.5,
            ),
          ),
          child: Row(children: [
            const Icon(Icons.park_outlined,
                size: 16, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.selected?.name ?? 'Choisir une forêt...',
                style: TextStyle(
                  fontSize: 13,
                  color: widget.selected != null
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                ),
              ),
            ),
            if (widget.selected?.areaHectares != null)
              Text(
                widget.selected!.areaLabel,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textMuted),
              ),
            const SizedBox(width: 6),
            Icon(
              _open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 16, color: AppColors.textMuted,
            ),
          ]),
        ),
      ),
      if (_open)
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color:        AppColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border:       Border.all(color: AppColors.border, width: 0.5),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset:     const Offset(0, 4),
              ),
            ],
          ),
          child: widget.forests.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Aucune forêt disponible.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textMuted),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding:    EdgeInsets.zero,
                  itemCount:  widget.forests.length,
                  itemBuilder: (_, i) {
                    final f          = widget.forests[i];
                    final isSelected = widget.selected?.id == f.id;
                    return GestureDetector(
                      onTap: () {
                        widget.onSelect(f);
                        setState(() => _open = false);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.infoBg
                              : AppColors.bgCard,
                          border: Border(
                            bottom: BorderSide(
                                color: AppColors.borderLight, width: 0.5),
                          ),
                        ),
                        child: Row(children: [
                          const Icon(Icons.park_outlined,
                              size: 14, color: AppColors.info),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(f.name,
                                style: const TextStyle(
                                    fontSize:   12,
                                    fontWeight: FontWeight.w500,
                                    color:      AppColors.textPrimary)),
                          ),
                          Text(f.areaLabel,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textMuted)),
                        ]),
                      ),
                    );
                  },
                ),
        ),
    ]);
  }
}

// ── Info banner (superviseur déjà affecté) ─────────────────────
class _InfoBanner extends StatelessWidget {
  final String message;
  const _InfoBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.infoBg,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: AppColors.info.withOpacity(0.3), width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline,
                size: 14, color: AppColors.info),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message,
                  style: const TextStyle(
                      fontSize: 11,
                      color:    AppColors.info,
                      height:   1.4)),
            ),
          ],
        ),
      );
}

// ── Card récent superviseur ────────────────────────────────────
class _SuperviseurRecentCard extends StatelessWidget {
  final SuperviseurStatus sup;
  const _SuperviseurRecentCard({required this.sup});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border:       Border.all(color: AppColors.border, width: 0.5),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(children: [
          _Avatar(initials: sup.initials, color: AppColors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sup.nom,
                    style: const TextStyle(
                        fontSize:   12,
                        fontWeight: FontWeight.w600,
                        color:      AppColors.textPrimary)),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.mail_outline,
                      size: 11, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(sup.email,
                        style: const TextStyle(
                            fontSize: 10,
                            color:    AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
                if (sup.phone.isNotEmpty)
                  Row(children: [
                    const Icon(Icons.phone_outlined,
                        size: 11, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(sup.phone,
                        style: const TextStyle(
                            fontSize: 10,
                            color:    AppColors.textSecondary)),
                  ]),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Forêts assignées
          if (sup.currentForests.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: sup.currentForests
                  .take(2)
                  .map((f) => Container(
                        margin: const EdgeInsets.only(bottom: 3),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color:        AppColors.infoBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          f.forestName,
                          style: const TextStyle(
                              fontSize:   10,
                              color:      AppColors.info,
                              fontWeight: FontWeight.w600),
                        ),
                      ))
                  .toList(),
            ),
        ]),
      );
}

// ── Widgets utilitaires ────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String initials;
  final Color  color;
  const _Avatar({required this.initials, required this.color});

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: 16,
        backgroundColor: color.withOpacity(0.12),
        child: Text(initials,
            style: TextStyle(
                fontSize:   10,
                fontWeight: FontWeight.w600,
                color:      color)),
      );
}

class _StatusBadge extends StatelessWidget {
  final bool  isAssigned;
  final Color assignedColor;
  const _StatusBadge(
      {required this.isAssigned, required this.assignedColor});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isAssigned
              ? assignedColor.withOpacity(0.12)
              : AppColors.successBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          isAssigned ? 'Affecté' : 'Disponible',
          style: TextStyle(
            fontSize:   10,
            fontWeight: FontWeight.w600,
            color:      isAssigned ? assignedColor : AppColors.success,
          ),
        ),
      );
}

class _SearchBar extends StatelessWidget {
  final String hint;
  final void Function(String) onChanged;
  const _SearchBar({required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 36,
        child: TextField(
          onChanged: onChanged,
          style: const TextStyle(
              fontSize: 12, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText:   hint,
            hintStyle:  const TextStyle(
                fontSize: 11, color: AppColors.textMuted),
            prefixIcon: const Icon(Icons.search,
                size: 15, color: AppColors.textMuted),
            filled:     true,
            fillColor:  AppColors.bgInput,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: AppColors.border, width: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: AppColors.border, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: AppColors.info, width: 1.2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            isDense: true,
          ),
        ),
      );
}

class _EmptyRecents extends StatelessWidget {
  final String message;
  const _EmptyRecents({required this.message});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Column(children: [
            const Icon(Icons.supervisor_account_outlined,
                size: 36, color: AppColors.textMuted),
            const SizedBox(height: 10),
            Text(message,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ]),
        ),
      );
}