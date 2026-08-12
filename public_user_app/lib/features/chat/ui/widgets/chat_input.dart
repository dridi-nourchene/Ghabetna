import 'package:flutter/material.dart';

import '../../../../core/theme.dart';

/// Barre de saisie : champ en pilule et bouton d'envoi vert translucide.
///
/// Le bouton change d'opacité selon que le champ est vide ou non : c'est ce
/// qui indique s'il est actif, sans changer de couleur.
class ChatInput extends StatefulWidget {
  const ChatInput({
    super.key,
    required this.onEnvoyer,
    required this.enAttente,
  });

  final void Function(String) onEnvoyer;
  final bool enAttente;

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _actif = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final actif = _controller.text.trim().isNotEmpty;
      if (actif != _actif) setState(() => _actif = actif);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _envoyer() {
    if (!_actif || widget.enAttente) return;
    widget.onEnvoyer(_controller.text);
    _controller.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final utilisable = _actif && !widget.enAttente;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surface2,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: BorderRadius.circular(AppDims.pill),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _envoyer(),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                    hintText: 'Posez votre question…',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            GestureDetector(
              onTap: _envoyer,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: AppDims.sendButton,
                height: AppDims.sendButton,
                decoration: BoxDecoration(
                  color: utilisable
                      ? AppColors.sendActiveBg
                      : AppColors.sendIdleBg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: utilisable
                        ? AppColors.sendActiveBorder
                        : AppColors.sendIdleBorder,
                    width: 0.5,
                  ),
                ),
                child: Icon(
                  Icons.send_rounded,
                  size: 17,
                  color: utilisable
                      ? AppColors.sendActiveIcon
                      : AppColors.sendIdleIcon,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
