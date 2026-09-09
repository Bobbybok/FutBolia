import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/realtime/socket_service.dart';
import '../../../design_system/tokens/colors.dart';
import '../../auth/application/auth_session.dart';
import '../../moderation/report_sheet.dart';
import '../chat_actions.dart';
import '../chat_overlay_controller.dart';
import '../widgets/chat_thread.dart';

Future<void> openTournamentChat(
  BuildContext context, {
  required String tournamentId,
  required String tournamentName,
  bool isOrganizer = false,
  bool canClearForEveryone = false,
  bool canSend = true,
  bool restoreInInbox = false,
}) async {
  context.read<ChatOverlayController>().openTournament(
        tournamentId: tournamentId,
        tournamentName: tournamentName,
        isOrganizer: isOrganizer,
        canClearForEveryone: canClearForEveryone,
        canSend: canSend,
        restoreInInbox: restoreInInbox,
      );
}

class TournamentChatScreen extends StatefulWidget {
  const TournamentChatScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
    this.isOrganizer = false,
    this.canClearForEveryone = false,
    this.canSend = true,
    this.restoreInInbox = false,
    this.onLeave,
  });

  final String tournamentId;
  final String tournamentName;
  final bool isOrganizer;
  final bool canClearForEveryone;
  final bool canSend;
  final bool restoreInInbox;
  final VoidCallback? onLeave;

  @override
  State<TournamentChatScreen> createState() => _TournamentChatScreenState();
}

class _TournamentChatScreenState extends State<TournamentChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  final _subs = <StreamSubscription>[];

  @override
  void initState() {
    super.initState();
    _load(initial: true);
    final socket = SocketService.instance;
    socket.joinTournament(widget.tournamentId);
    _subs.add(socket.onTournamentMessage.listen(_onSocketMessage));
    _subs.add(socket.onTournamentMessageDeleted.listen(_onSocketDeleted));
    _subs.add(socket.onTournamentChatCleared.listen(_onSocketCleared));
  }

  @override
  void dispose() {
    SocketService.instance.leaveTournament(widget.tournamentId);
    for (final sub in _subs) {
      sub.cancel();
    }
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    if (initial) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final messages = await context
          .read<AuthSession>()
          .api
          .listChatMessages(
            widget.tournamentId,
            restoreInbox: widget.restoreInInbox && initial,
          );
      if (!mounted) return;
      final changed = messages.length != _messages.length ||
          (messages.isNotEmpty &&
              _messages.isNotEmpty &&
              messages.last['id'] != _messages.last['id']);
      setState(() {
        _messages = messages;
        _loading = false;
        _error = null;
      });
      if (initial || changed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          }
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (initial) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  Map<String, dynamic> _withMine(Map<String, dynamic> raw) {
    final uid = context.read<AuthSession>().user?.id;
    return {...raw, 'isMine': raw['authorId']?.toString() == uid};
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _onSocketMessage(Map<String, dynamic> raw) {
    if (!mounted) return;
    if (raw['tournamentId']?.toString() != widget.tournamentId) return;
    final message = _withMine(raw);
    final id = message['id']?.toString();
    if (id == null) return;
    final index = _messages.indexWhere((m) => m['id']?.toString() == id);
    setState(() {
      if (index >= 0) {
        _messages[index] = message;
      } else {
        _messages = [..._messages, message];
      }
    });
    _scrollToEnd();
  }

  void _onSocketDeleted(Map<String, dynamic> raw) {
    if (!mounted) return;
    if (raw['tournamentId']?.toString() != widget.tournamentId) return;
    final id = raw['id']?.toString();
    if (id == null) return;
    setState(() {
      _messages = _messages.where((m) => m['id']?.toString() != id).toList();
    });
  }

  void _onSocketCleared(Map<String, dynamic> raw) {
    if (!mounted) return;
    if (raw['tournamentId']?.toString() != widget.tournamentId) return;
    setState(() => _messages = []);
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending || !widget.canSend) return;
    setState(() => _sending = true);
    try {
      final created = await context.read<AuthSession>().api.postChatMessage(
            widget.tournamentId,
            text,
          );
      _input.clear();
      _onSocketMessage(created);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce message pour tout le monde ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: FutBoliaColors.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context
          .read<AuthSession>()
          .api
          .deleteChatMessage(message['id'].toString());
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _clearMine() async {
    final ok = await confirmChatAction(
      context,
      title: 'Vider le chat ?',
      body: 'L’historique disparaît pour toi. Les autres participants le gardent.',
      confirmLabel: 'Vider',
    );
    if (!ok || !mounted) return;
    try {
      await context.read<AuthSession>().api.clearTournamentChat(
            widget.tournamentId,
          );
      await _load(initial: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _hideChat() async {
    final ok = await confirmChatAction(
      context,
      title: 'Supprimer la conversation ?',
      body:
          'Elle disparaît de tes chats. Pour la retrouver, ouvre le chat une fois depuis le tournoi.',
      confirmLabel: 'Supprimer',
    );
    if (!ok || !mounted) return;
    try {
      await context.read<AuthSession>().api.hideTournamentChat(
            widget.tournamentId,
          );
      if (!mounted) return;
      widget.onLeave?.call();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _clearEveryone() async {
    final ok = await confirmChatAction(
      context,
      title: 'Vider le chat pour tout le monde ?',
      body:
          'Tous les messages seront supprimés pour tous les participants. Cette action est définitive.',
      confirmLabel: 'Vider pour tous',
    );
    if (!ok || !mounted) return;
    try {
      await context
          .read<AuthSession>()
          .api
          .clearTournamentChatForEveryone(widget.tournamentId);
      await _load(initial: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStaff = context.watch<AuthSession>().user?.isStaff ?? false;
    final canRemoveConversation = widget.canSend && !widget.restoreInInbox;
    return Column(
      children: [
        if (widget.canSend ||
            widget.canClearForEveryone ||
            canRemoveConversation)
          Align(
            alignment: Alignment.centerRight,
            child: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'clear') _clearMine();
                if (value == 'hide') _hideChat();
                if (value == 'clear_all') _clearEveryone();
              },
              itemBuilder: (ctx) => [
                if (widget.canSend)
                  const PopupMenuItem(
                    value: 'clear',
                    child: Text('Vider le chat'),
                  ),
                if (canRemoveConversation)
                  const PopupMenuItem(
                    value: 'hide',
                    child: Text('Supprimer la conversation'),
                  ),
                if (widget.canClearForEveryone)
                  const PopupMenuItem(
                    value: 'clear_all',
                    child: Text('Vider pour tout le monde'),
                  ),
              ],
            ),
          ),
        Expanded(
          child: ChatThread(
        messages: _messages,
        loading: _loading,
        error: _error,
        scroll: _scroll,
        input: _input,
        onSend: _send,
        sending: _sending,
        canSend: widget.canSend,
        cannotSendHint: 'Tu dois être inscrit au tournoi pour écrire ici.',
        canDelete: (m) =>
            m['isMine'] == true || widget.isOrganizer || isStaff,
        onDelete: _delete,
        onReportMessage: (m) => showReportSheet(
          context,
          type: 'message',
          targetId: m['id']?.toString() ?? '',
          title: 'Signaler le message',
        ),
        onReportUser: (m) => showReportSheet(
          context,
          type: 'user',
          targetId: m['authorId']?.toString() ?? '',
          title: 'Signaler ${m['authorPseudo'] ?? 'ce joueur'}',
        ),
          ),
        ),
      ],
    );
  }
}
