// features/admin/screens/admin_assign_agents_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../features/assignment/models/assignment_model.dart';
import '../../../features/assignment/providers/assignment_provider.dart';
import '../../../features/forest/models/forest_model.dart';
import '../../../features/forest/providers/forest_provider.dart';

class AdminAssignAgentsScreen extends ConsumerStatefulWidget {
  const AdminAssignAgentsScreen({super.key});

  @override
  ConsumerState<AdminAssignAgentsScreen> createState() =>
      _AdminAssignAgentsScreenState();
}

class _AdminAssignAgentsScreenState
    extends ConsumerState<AdminAssignAgentsScreen> {
  AgentStatus? _selectedAgent;
  Parcelle?    _selectedParcelle;
  String       _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(agentAssignmentProvider.notifier).loadAgents();
      ref.read(forestListProvider.notifier).loadForests();
      // Charger toutes les parcelles
      ref.read(parcelleProvider.notifier);
    });
  }

  // Récupère toutes les parcelles de toutes les forêts
  List<Parcelle> _getAllParcelles() {
    final ps = ref.read(parcelleProvider);
    return ps.byForest.values.expand((list) => list).toList();
  }

  Future<void> _handleAssign() async {
    if (_selectedAgent == null || _selectedParcelle == null) return;

    final ok = await ref.read(agentAssignmentProvider.notifier).assignAgent(
          parcelleId: _selectedParcelle!.id,
          agentId:    _selectedAgent!.userId,
        );

    if (ok && mounted) {
      setState(() {
        _selectedAgent   = null;
        _selectedParcelle = null;
      });
    }
  }

  Future<void> _handleConfirmReassign() async {
    final conflict = ref.read(agentAssignmentProvider).pendingConflict;
    if (conflict == null || _selectedParcelle == null) return;

    final ok = await ref.read(agentAssignmentProvider.notifier).confirmReassign(
          parcelleId: _selectedParcelle!.id,
          agentId:    conflict.agentId,
        );

    if (ok && mounted) {
      setState(() {
        _selectedAgent    = null;
        _selectedParcelle = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state       = ref.watch(agentAssignmentProvider);
    final forestState = ref.watch(forestListProvider);

    // Charger les parcelles dès que les forêts arrivent
    for (final f in forestState.forests) {
      final ps = ref.read(parcelleProvider);
      if (!ps.byForest.containsKey(f.id) && !ps.loadingIds.contains(f.id)) {
        ref.read(parcelleProvider.notifier).loadParcelles(f.id);
      }
    }

    final allParcelles = _getAllParcelles();

    // Snackbars
    ref.listen<AgentAssignmentState>(agentAssignmentProvider, (_, next) {
      if (next.successMessage != null) {
        _showSnack(next.successMessage!, AppColors.success);
        ref.read(agentAssignmentProvider.notifier).clearMessages();
      }
      if (next.error != null) {
        _showSnack(next.error!, AppColors.danger);
        ref.read(agentAssignmentProvider.notifier).clearMessages();
      }
    });

    // Filtrage recherche (liste droite)
    final recents = state.recentAssigned.where((a) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return a.nom.toLowerCase().contains(q) ||
          a.email.toLowerCase().contains(q) ||
          (a.currentParcelle?.parcelleName.toLowerCase().contains(q) ?? false);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────
          const Text(
            'Affecter les agents',
            style: TextStyle(
              fontSize:   20,
              fontWeight: FontWeight.w700,
              color:      AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Associez un agent à une parcelle forestière.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),

          // ── Corps : 2 colonnes ───────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Colonne gauche — Formulaire ───────────────
              Expanded(
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre
                      Row(children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.successBg,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(Icons.link,
                              size: 15, color: AppColors.primaryMid),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nouvelle affectation',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                            Text('Choisissez un agent puis une parcelle',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textMuted)),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 20),

                      // Conflit banner
                      if (state.pendingConflict != null)
                        _ConflictBanner(
                          conflict:  state.pendingConflict!,
                          onConfirm: _handleConfirmReassign,
                          onCancel:  () {
                            ref
                                .read(agentAssignmentProvider.notifier)
                                .clearConflict();
                            setState(() => _selectedAgent = null);
                          },
                        ),

                      // Dropdown agent
                      const _FieldLabel('Agent *'),
                      const SizedBox(height: 6),
                      _AgentDropdown(
                        agents:   state.agents,
                        selected: _selectedAgent,
                        onSelect: (agent) {
                          setState(() => _selectedAgent = agent);
                          // Reset conflit si on change d'agent
                          ref
                              .read(agentAssignmentProvider.notifier)
                              .clearConflict();
                        },
                      ),

                      const SizedBox(height: 14),

                      // Dropdown parcelle
                      const _FieldLabel('Parcelle *'),
                      const SizedBox(height: 6),
                      _ParcelleDropdown(
                        parcelles: allParcelles,
                        forests:   forestState.forests,
                        selected:  _selectedParcelle,
                        onSelect:  (p) => setState(() => _selectedParcelle = p),
                      ),

                      const SizedBox(height: 20),

                      // Bouton confirmer
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: (_selectedAgent != null &&
                                  _selectedParcelle != null &&
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
                            backgroundColor: AppColors.primaryDark,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                AppColors.primaryDark.withOpacity(0.4),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 13),
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

              // ── Colonne droite — Récents ──────────────────
              Expanded(
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.successBg,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(Icons.history,
                              size: 15, color: AppColors.primaryMid),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Affectations récentes',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                            Text(
                              state.recentAssigned.isEmpty
                                  ? 'Aucune affectation pour l\'instant'
                                  : '${state.recentAssigned.length} agent${state.recentAssigned.length != 1 ? 's' : ''} affecté${state.recentAssigned.length != 1 ? 's' : ''}',
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 14),

                      // Barre de recherche
                      _SearchBar(
                        hint: 'Rechercher par nom, email, parcelle...',
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                      const SizedBox(height: 12),

                      // Liste des récents
                      if (state.isLoading && state.agents.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 30),
                            child: CircularProgressIndicator(
                                color: AppColors.primaryMid, strokeWidth: 2),
                          ),
                        )
                      else if (recents.isEmpty)
                        const _EmptyRecents(
                            message: 'Aucun agent affecté pour l\'instant')
                      else
                        ...recents.map((a) => _AgentRecentCard(agent: a)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }
}

// ══════════════════════════════════════════════════════════════
//  WIDGETS INTERNES
// ══════════════════════════════════════════════════════════════

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize:   11,
          fontWeight: FontWeight.w600,
          color:      AppColors.textSecondary,
        ),
      );
}

// ── Dropdown Agents ────────────────────────────────────────────
class _AgentDropdown extends StatefulWidget {
  final List<AgentStatus>       agents;
  final AgentStatus?            selected;
  final void Function(AgentStatus) onSelect;

  const _AgentDropdown({
    required this.agents,
    required this.selected,
    required this.onSelect,
  });

  @override
  State<_AgentDropdown> createState() => _AgentDropdownState();
}

class _AgentDropdownState extends State<_AgentDropdown> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color:  AppColors.bgInput,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _open
                    ? AppColors.primaryMid
                    : AppColors.border,
                width: _open ? 1.2 : 0.5,
              ),
            ),
            child: Row(children: [
              const Icon(Icons.person_outline,
                  size: 16, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.selected?.nom ?? 'Choisir un agent...',
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.selected != null
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
              ),
              if (widget.selected != null)
                _StatusBadge(isAssigned: widget.selected!.isAssigned),
              const SizedBox(width: 6),
              Icon(
                _open
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                size:  16,
                color: AppColors.textMuted,
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
              border: Border.all(color: AppColors.border, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color:      Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset:     const Offset(0, 4),
                ),
              ],
            ),
            child: widget.agents.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Aucun agent disponible — les agents doivent activer leur compte.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding:    EdgeInsets.zero,
                    itemCount:  widget.agents.length,
                    itemBuilder: (_, i) {
                      final a = widget.agents[i];
                      final isSelected =
                          widget.selected?.userId == a.userId;
                      return GestureDetector(
                        onTap: () {
                          widget.onSelect(a);
                          setState(() => _open = false);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryLight
                                : a.isAssigned
                                    ? AppColors.bgInput
                                    : AppColors.bgCard,
                            border: Border(
                              bottom: BorderSide(
                                color: AppColors.borderLight,
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(children: [
                            _Avatar(initials: a.initials),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(a.nom,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textPrimary)),
                                  if (a.isAssigned &&
                                      a.currentParcelle != null)
                                    Text(
                                      a.currentParcelle!.parcelleName,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textMuted),
                                    ),
                                ],
                              ),
                            ),
                            _StatusBadge(isAssigned: a.isAssigned),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
      ],
    );
  }
}

// ── Dropdown Parcelles ─────────────────────────────────────────
class _ParcelleDropdown extends StatefulWidget {
  final List<Parcelle>       parcelles;
  final List<dynamic>        forests;
  final Parcelle?            selected;
  final void Function(Parcelle) onSelect;

  const _ParcelleDropdown({
    required this.parcelles,
    required this.forests,
    required this.selected,
    required this.onSelect,
  });

  @override
  State<_ParcelleDropdown> createState() => _ParcelleDropdownState();
}

class _ParcelleDropdownState extends State<_ParcelleDropdown> {
  bool _open = false;

  String _forestName(String forestId) {
    try {
      final f = widget.forests.firstWhere(
        (f) => f.id == forestId,
      );
      return f.name as String;
    } catch (_) {
      return '';
    }
  }

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
              color: _open ? AppColors.primaryMid : AppColors.border,
              width: _open ? 1.2 : 0.5,
            ),
          ),
          child: Row(children: [
            const Icon(Icons.crop_square_outlined,
                size: 16, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.selected != null
                    ? '${widget.selected!.name} · ${_forestName(widget.selected!.forestId)}'
                    : 'Choisir une parcelle...',
                style: TextStyle(
                  fontSize: 13,
                  color: widget.selected != null
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                ),
              ),
            ),
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
          child: widget.parcelles.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Aucune parcelle disponible.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding:    EdgeInsets.zero,
                  itemCount:  widget.parcelles.length,
                  itemBuilder: (_, i) {
                    final p          = widget.parcelles[i];
                    final isSelected = widget.selected?.id == p.id;
                    final fName      = _forestName(p.forestId);
                    return GestureDetector(
                      onTap: () {
                        widget.onSelect(p);
                        setState(() => _open = false);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryLight
                              : AppColors.bgCard,
                          border: Border(
                            bottom: BorderSide(
                                color: AppColors.borderLight, width: 0.5),
                          ),
                        ),
                        child: Row(children: [
                          const Icon(Icons.crop_square_outlined,
                              size: 14, color: AppColors.primaryMid),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textPrimary)),
                                if (fName.isNotEmpty)
                                  Text(fName,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
        ),
    ]);
  }
}

// ── Bannière conflit ───────────────────────────────────────────
class _ConflictBanner extends StatelessWidget {
  final AssignmentResult conflict;
  final VoidCallback     onConfirm;
  final VoidCallback     onCancel;

  const _ConflictBanner({
    required this.conflict,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warningBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppColors.warning.withOpacity(0.4), width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 16, color: AppColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          height: 1.5),
                      children: [
                        TextSpan(
                          text: conflict.agentNom ?? 'Cet agent',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const TextSpan(text: ' est déjà affecté à '),
                        TextSpan(
                          text: conflict.currentParcelleName ?? 'une parcelle',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const TextSpan(
                            text: '.\nVoulez-vous déplacer son affectation ?'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    ElevatedButton(
                      onPressed: onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7)),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Modifier l\'affectation'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(
                            color: AppColors.border, width: 0.8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7)),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      );
}

// ── Card récent agent ──────────────────────────────────────────
class _AgentRecentCard extends StatelessWidget {
  final AgentStatus agent;
  const _AgentRecentCard({required this.agent});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border, width: 0.5),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(children: [
          _Avatar(initials: agent.initials),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(agent.nom,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.mail_outline,
                      size: 11, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      agent.email,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
                if (agent.phone.isNotEmpty)
                  Row(children: [
                    const Icon(Icons.phone_outlined,
                        size: 11, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(agent.phone,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textSecondary)),
                  ]),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (agent.currentParcelle != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.successBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                agent.currentParcelle!.parcelleName,
                style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.primaryMid,
                    fontWeight: FontWeight.w600),
              ),
            ),
        ]),
      );
}

// ── Widgets utilitaires ────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String initials;
  const _Avatar({required this.initials});

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.successBg,
        child: Text(initials,
            style: const TextStyle(
                fontSize:   10,
                fontWeight: FontWeight.w600,
                color:      AppColors.primaryMid)),
      );
}

class _StatusBadge extends StatelessWidget {
  final bool isAssigned;
  const _StatusBadge({required this.isAssigned});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isAssigned ? AppColors.warningBg : AppColors.successBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          isAssigned ? 'Déjà affecté' : 'Disponible',
          style: TextStyle(
            fontSize:   10,
            fontWeight: FontWeight.w600,
            color:      isAssigned
                ? AppColors.warning
                : AppColors.success,
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
          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText:  hint,
            hintStyle: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            prefixIcon: const Icon(Icons.search,
                size: 15, color: AppColors.textMuted),
            filled:    true,
            fillColor: AppColors.bgInput,
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
              borderSide:
                  const BorderSide(color: AppColors.primaryMid, width: 1.2),
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
            const Icon(Icons.people_outline,
                size: 36, color: AppColors.textMuted),
            const SizedBox(height: 10),
            Text(message,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ]),
        ),
      );
}