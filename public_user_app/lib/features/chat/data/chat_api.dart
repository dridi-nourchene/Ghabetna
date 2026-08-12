import '../../../core/api_client.dart';
import '../../../core/api_config.dart';
import 'chat_models.dart';

/// Accès à POST /api/chat/ via le gateway.
class ChatApi {
  const ChatApi({this.client = const ApiClient()});
  final ApiClient client;

  /// [historique] est renvoyé à chaque appel : chatbot_ms est sans état,
  /// c'est le client qui conserve la conversation.
  ///
  /// [specialite] passe dans le corps tant que l'authentification citoyenne
  /// n'existe pas. Quand elle existera, le gateway l'injectera dans l'entête
  /// X-User-Specialite depuis le JWT — et ce fichier ne changera pas, le
  /// serveur donnant la priorité à l'entête.
  Future<ChatResponse> envoyer({
    required String question,
    required Specialite specialite,
    List<ChatMessage> historique = const [],
  }) async {
    final data = await client.post(
      ApiConfig.chat,
      body: {
        'question': question,
        'specialite': specialite.code,
        'historique': historique.map((m) => m.toApi()).toList(),
      },
      timeout: ApiConfig.chatTimeout,
    );
    return ChatResponse.fromJson(data);
  }
}
