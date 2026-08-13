import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_exception.dart';
import '../../../core/token_storage.dart';
import '../data/chat_api.dart';
import '../data/chat_models.dart';

/// État de l'écran de chat.
class ChatState {
  final List<ChatMessage> messages;
  final bool enAttente;
  final Specialite specialite;

  const ChatState({
    this.messages = const [],
    this.enAttente = false,
    this.specialite = Specialite.chasseur,
  });

  bool get estVide => messages.isEmpty;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? enAttente,
    Specialite? specialite,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        enAttente: enAttente ?? this.enAttente,
        specialite: specialite ?? this.specialite,
      );
}

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier(this._api) : super(const ChatState()) {
    _chargerSpecialite();
  }

  final ChatApi _api;

  /// Nombre de tours renvoyés au serveur. Au-delà, l'ancien devient du bruit
  /// et consomme du contexte inutilement. À garder cohérent avec
  /// MAX_TOURS_HISTORIQUE côté chatbot_ms.
  static const int _maxTours = 6;

  Future<void> _chargerSpecialite() async {
    try {
      final s = await TokenStorage.readSpecialite();
      if (s != null) {
        state = state.copyWith(specialite: Specialite.fromCode(s));
      }
    } catch (_) {
      // Le coffre sécurisé peut échouer au premier lancement : on garde
      // simplement la spécialité par défaut.
    }
  }

  Future<void> changerSpecialite(Specialite s) async {
    try {
      await TokenStorage.saveSpecialite(s.code);
    } catch (_) {}
    // On repart d'une conversation vide : le domaine interrogé change,
    // l'historique précédent n'a plus de sens.
    state = ChatState(specialite: s);
  }

  Future<void> envoyer(String question) async {
    final texte = question.trim();
    if (texte.isEmpty || state.enAttente) return;

    // L'historique exclut le message courant : le serveur le reçoit
    // séparément dans le champ "question".
    final valides = state.messages.where((m) => !m.enErreur).toList();
    final historique = valides.length <= _maxTours
        ? valides
        : valides.sublist(valides.length - _maxTours);

    state = state.copyWith(
      messages: [...state.messages, ChatMessage.user(texte)],
      enAttente: true,
    );

    // NOTE : on n'utilise PAS `mounted` ici.
    // Sur un StateNotifier, cette propriété peut valoir false de façon
    // inattendue selon la version de Riverpod, et un `if (!mounted) return`
    // ferait sortir la méthode AVANT l'affectation du state : la réponse
    // serait perdue et la bulle resterait vide.
    try {
      final r = await _api.envoyer(
        question: texte,
        specialite: state.specialite,
        historique: historique,
      );

      // ignore: avoid_print
      print('[CHAT] reponse=${r.reponse.length} car. | '
          'sources=${r.sources.length} | verdict=${r.verdict?.etat} | '
          'cache=${r.depuisCache} | ${r.dureeMs}ms');

      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(
            role: Role.assistant,
            texte: r.reponse.isEmpty
                ? '(Le serveur a répondu sans texte.)'
                : r.reponse,
            verdict: r.verdict,
            sources: r.sources,
          ),
        ],
        enAttente: false,
      );
    } on ApiException catch (e) {
      // ignore: avoid_print
      print('[CHAT] ApiException: ${e.message} (${e.statusCode})');
      state = state.copyWith(
        messages: [...state.messages, ChatMessage.erreur(e.message)],
        enAttente: false,
      );
    } catch (e, pile) {
      // On affiche l'exception réelle plutôt qu'un message générique :
      // sans elle, une erreur de parsing JSON reste invisible.
      // ignore: avoid_print
      print('[CHAT] Erreur inattendue: $e\n$pile');
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage.erreur('Erreur : $e'),
        ],
        enAttente: false,
      );
    }
  }

  void reinitialiser() => state = ChatState(specialite: state.specialite);
}

final chatApiProvider = Provider<ChatApi>((ref) => const ChatApi());

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>(
  (ref) => ChatNotifier(ref.watch(chatApiProvider)),
);