import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../design_system/tokens/colors.dart';
import '../private_chat/conversation_screen.dart';
import '../private_chat/conversations_list_screen.dart';
import 'chat_overlay_controller.dart';
import 'presentation/tournament_chat_screen.dart';

const _panelW = 360.0;
const _panelH = 480.0;

class ChatOverlayLayer extends StatelessWidget {
  const ChatOverlayLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatOverlayController>();
    if (!chat.visible) return const SizedBox.shrink();
    return Stack(
      children: [
        if (!chat.pinned)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: chat.close,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.28),
              ),
            ),
          ),
        const FloatingChatPanel(),
      ],
    );
  }
}

class FloatingChatPanel extends StatefulWidget {
  const FloatingChatPanel({super.key});

  @override
  State<FloatingChatPanel> createState() => _FloatingChatPanelState();
}

class _FloatingChatPanelState extends State<FloatingChatPanel> {
  Offset? _offset;

  Size _panelSize(MediaQueryData media) {
    final maxW = math.min(_panelW, media.size.width - 16);
    final maxH = math.min(
      _panelH,
      media.size.height - media.viewInsets.bottom - 24,
    );
    return Size(maxW, maxH.clamp(280.0, _panelH));
  }

  Offset _defaultOffset(MediaQueryData media, Size panel) {
    final nav = kBottomNavigationBarHeight + media.padding.bottom;
    return Offset(
      media.size.width - panel.width - 10,
      media.size.height - panel.height - nav - 10 - media.viewInsets.bottom,
    );
  }

  Offset _clamp(Offset offset, MediaQueryData media, Size panel) {
    final maxX = math.max(8.0, media.size.width - panel.width - 8);
    final maxY = math.max(
      8.0,
      media.size.height - panel.height - media.viewInsets.bottom - 8,
    );
    return Offset(
      offset.dx.clamp(8.0, maxX),
      offset.dy.clamp(8.0, maxY),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatOverlayController>();
    final media = MediaQuery.of(context);
    final size = _panelSize(media);
    var offset = _offset ?? chat.offset ?? _defaultOffset(media, size);
    offset = _clamp(offset, media, size);

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: Material(
        color: Theme.of(context).brightness == Brightness.dark
            ? FutBoliaColors.surfaceRaisedDark
            : FutBoliaColors.surfaceRaised,
        elevation: 18,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? FutBoliaColors.lineDark
                : FutBoliaColors.line,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Column(
            children: [
              _header(context, chat, media, size),
              Divider(
                height: 1,
                color: Theme.of(context).brightness == Brightness.dark
                    ? FutBoliaColors.lineDark
                    : FutBoliaColors.line,
              ),
              Expanded(child: _body(chat)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    ChatOverlayController chat,
    MediaQueryData media,
    Size size,
  ) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onPanUpdate: (details) {
        final next = _clamp(
          (_offset ?? chat.offset ?? _defaultOffset(media, size)) + details.delta,
          media,
          size,
        );
        setState(() => _offset = next);
      },
      onPanEnd: (_) {
        if (_offset != null) chat.setOffset(_offset!);
      },
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            if (chat.canGoBack)
              IconButton(
                tooltip: 'Conversations',
                onPressed: chat.goBack,
                icon: Icon(Icons.arrow_back, color: onSurface),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.drag_indicator, color: onSurface.withValues(alpha: 0.45)),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  chat.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
            IconButton(
              tooltip: chat.pinned
                  ? 'Désépingler'
                  : 'Épingler — continuer à utiliser l’app derrière',
              onPressed: chat.togglePin,
              icon: Icon(
                chat.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: chat.pinned ? FutBoliaColors.pitch : onSurface,
              ),
            ),
            IconButton(
              tooltip: 'Fermer',
              onPressed: chat.close,
              icon: Icon(Icons.close, color: onSurface),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(ChatOverlayController chat) {
    switch (chat.page) {
      case ChatOverlayPage.inbox:
        return const ConversationsListScreen(embedded: true);
      case ChatOverlayPage.dm:
        return ConversationScreen(
          key: ValueKey('dm-${chat.conversationId}'),
          conversationId: chat.conversationId!,
          friendName: chat.friendName ?? 'Conversation',
          friendId: chat.friendId,
          canSend: chat.canSend,
          onLeave: chat.goBack,
        );
      case ChatOverlayPage.tournament:
        return TournamentChatScreen(
          key: ValueKey('tn-${chat.tournamentId}'),
          tournamentId: chat.tournamentId!,
          tournamentName: chat.tournamentName ?? 'Tournoi',
          isOrganizer: chat.isOrganizer,
          canClearForEveryone: chat.canClearForEveryone,
          canSend: chat.canSend,
          restoreInInbox: chat.restoreInInbox,
          onLeave: chat.goBack,
        );
    }
  }
}
