import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../data/chat_models.dart';
import '../providers/chat_provider.dart';
import 'widgets/chat_header.dart';
import 'widgets/chat_input.dart';
import 'widgets/empty_state.dart';
import 'widgets/message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _versLeBas() {
    // Après la frame : la liste doit être reconstruite avant qu'on connaisse
    // sa nouvelle hauteur.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _envoyer(String texte) {
    ref.read(chatProvider.notifier).envoyer(texte);
    _versLeBas();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);
    ref.listen(chatProvider, (_, __) => _versLeBas());

    return Scaffold(
      backgroundColor: AppColors.surface0,
      body: Column(
        children: [
          ChatHeader(specialite: state.specialite),
          _barreMode(state.specialite),
          Expanded(
            child: state.estVide
                ? EmptyState(
                    specialite: state.specialite,
                    onSuggestion: _envoyer,
                  )
                : _fil(state),
          ),
          ChatInput(onEnvoyer: _envoyer, enAttente: state.enAttente),
        ],
      ),
    );
  }

  /// Rappel du domaine interrogé.
  ///
  /// Indispensable : sans lui, un apiculteur qui reçoit un refus sur une
  /// question de chasse ne comprend pas pourquoi. Le sélecteur restera
  /// jusqu'à l'authentification citoyenne, où la spécialité viendra du JWT.
  Widget _barreMode(Specialite s) {
    return Container(
      color: AppColors.surface0,
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 3),
      child: Row(
        children: [
          const Icon(Icons.gps_fixed, size: 14,
              color: AppColors.accentBlueDark),
          const SizedBox(width: 6),
          Text(
            s.libelle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          PopupMenuButton<Specialite>(
            tooltip: 'Changer de spécialité',
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.tune, size: 15,
                color: AppColors.textMuted),
            onSelected: (v) =>
                ref.read(chatProvider.notifier).changerSpecialite(v),
            itemBuilder: (_) => Specialite.values
                .map((v) => PopupMenuItem(
                      value: v,
                      child: Text(v.libelle,
                          style: const TextStyle(fontSize: 13)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _fil(ChatState state) {
    // Un élément supplémentaire à la fin quand l'assistant rédige.
    final total = state.messages.length + (state.enAttente ? 1 : 0);

    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      itemCount: total,
      separatorBuilder: (_, __) => const SizedBox(height: 11),
      itemBuilder: (_, i) {
        if (i >= state.messages.length) return const TypingIndicator();
        final m = state.messages[i];

        // Une erreur n'est jamais affichée comme une réponse de Ghabetna :
        // elle passe par le bandeau ambre centré, hors du style bulle.
        if (m.enErreur) return const ErrorBanner();

        return m.role == Role.user
            ? UserBubble(texte: m.texte)
            : AssistantBubble(message: m);
      },
    );
  }
}