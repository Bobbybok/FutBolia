import 'package:flutter/material.dart';
import '../../../design_system/tokens/colors.dart';
import '../../auth/domain/staff_label.dart';

class ChatThread extends StatelessWidget {
  const ChatThread({
    super.key,
    required this.messages,
    required this.loading,
    required this.scroll,
    required this.input,
    required this.onSend,
    required this.sending,
    this.error,
    this.emptyLabel = 'Aucun message. Lance la conversation.',
    this.canSend = true,
    this.cannotSendHint,
    this.canDelete,
    this.onDelete,
  });

  final List<Map<String, dynamic>> messages;
  final bool loading;
  final String? error;
  final String emptyLabel;
  final ScrollController scroll;
  final TextEditingController input;
  final VoidCallback onSend;
  final bool sending;
  final bool canSend;
  final String? cannotSendHint;
  final bool Function(Map<String, dynamic> message)? canDelete;
  final ValueChanged<Map<String, dynamic>>? onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _body(context)),
        if (!canSend && cannotSendHint != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              cannotSendHint!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: FutBoliaColors.inkMuted,
                  ),
            ),
          ),
        if (canSend) _composer(context),
      ],
    );
  }

  Widget _body(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(child: Text(error!));
    }
    if (messages.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: FutBoliaColors.inkMuted,
              ),
        ),
      );
    }
    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final m = messages[index];
        final mine = m['isMine'] == true;
        final deletable = canDelete?.call(m) ?? mine;
        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: InkWell(
              onLongPress: deletable && onDelete != null
                  ? () => onDelete!(m)
                  : null,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: mine ? FutBoliaColors.pitch : FutBoliaColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(14),
                  border: mine ? null : Border.all(color: FutBoliaColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!mine)
                      Text(
                        staffDisplayPseudo(
                          m['authorPseudo']?.toString(),
                          m['authorRole']?.toString(),
                        ),
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: FutBoliaColors.pitch,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    if (!mine) const SizedBox(height: 4),
                    Text(
                      m['body']?.toString() ?? '',
                      style: TextStyle(
                        color: mine ? Colors.white : FutBoliaColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _composer(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: input,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Écrire un message…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: sending ? null : onSend,
              style: IconButton.styleFrom(
                backgroundColor: FutBoliaColors.pitch,
                foregroundColor: Colors.white,
              ),
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
