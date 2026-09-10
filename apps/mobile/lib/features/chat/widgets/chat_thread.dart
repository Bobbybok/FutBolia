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
    this.onReportMessage,
    this.onReportUser,
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
  final ValueChanged<Map<String, dynamic>>? onReportMessage;
  final ValueChanged<Map<String, dynamic>>? onReportUser;

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
                    color: Theme.of(context).colorScheme.onSurface.withValues(
                      alpha: 0.65,
                    ),
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
                color: Theme.of(context).colorScheme.onSurface.withValues(
                  alpha: 0.65,
                ),
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
              onLongPress: () => _showActions(
                context,
                message: m,
                mine: mine,
                deletable: deletable,
              ),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: mine
                      ? FutBoliaColors.pitch
                      : FutBoliaColors.cardDark,
                  borderRadius: BorderRadius.circular(14),
                  border: mine
                      ? null
                      : Border.all(color: FutBoliaColors.lineDark),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!mine)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              staffDisplayPseudo(
                                m['authorPseudo']?.toString(),
                                m['authorRole']?.toString(),
                              ),
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: FutBoliaColors.pitch,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          if (onReportMessage != null || onReportUser != null)
                            IconButton(
                              tooltip: 'Signaler',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              onPressed: () => _showActions(
                                context,
                                message: m,
                                mine: mine,
                                deletable: false,
                              ),
                              icon: const Icon(Icons.flag_outlined, size: 18),
                            ),
                        ],
                      ),
                    if (!mine) const SizedBox(height: 4),
                    Text(
                      m['body']?.toString() ?? '',
                      style: TextStyle(
                        color: mine
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
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

  void _showActions(
    BuildContext context, {
    required Map<String, dynamic> message,
    required bool mine,
    required bool deletable,
  }) {
    final authorId = message['authorId']?.toString();
    final canReportMessage = !mine && onReportMessage != null;
    final canReportUser =
        !mine && onReportUser != null && authorId != null && authorId.isNotEmpty;
    final canRemove = deletable && onDelete != null;
    if (!canReportMessage && !canReportUser && !canRemove) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Actions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canReportMessage)
              ListTile(
                leading: const Icon(Icons.outlined_flag),
                title: const Text('Signaler le message'),
                onTap: () {
                  Navigator.pop(ctx);
                  onReportMessage!(message);
                },
              ),
            if (canReportUser)
              ListTile(
                leading: const Icon(Icons.person_off_outlined),
                title: const Text('Signaler le joueur'),
                onTap: () {
                  Navigator.pop(ctx);
                  onReportUser!(message);
                },
              ),
            if (canRemove)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: FutBoliaColors.danger,
                ),
                title: const Text('Supprimer'),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete!(message);
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  Widget _composer(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
