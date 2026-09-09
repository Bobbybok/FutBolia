import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/realtime/socket_service.dart';
import '../../design_system/tokens/colors.dart';
import '../auth/application/auth_session.dart';
import '../auth/domain/staff_label.dart';
import '../chat/chat_actions.dart';
import '../chat/widgets/chat_thread.dart';
import '../moderation/report_sheet.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.conversationId,
    required this.friendName,
    this.friendId,
    this.canSend = true,
  });

  final String conversationId;
  final String friendName;
  final String? friendId;
  final bool canSend;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _canSend = true;
  String? _error;
  final _subs = <StreamSubscription>[];

  ApiClient get _api => context.read<AuthSession>().api;

  @override
  void initState() {
    super.initState();
    _canSend = widget.canSend;
    _load(initial: true);
    final socket = SocketService.instance;
    _subs.add(socket.onPrivateMessage.listen(_onSocketMessage));
    _subs.add(socket.onPrivateMessageDeleted.listen(_onSocketDeleted));
  }

  @override
  void dispose() {
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
      final data = await _api.listDirectMessages(widget.conversationId);
      await _api.markConversationRead(widget.conversationId);
      if (!mounted) return;
      final raw = data['messages'];
      final messages = raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
      final changed = messages.length != _messages.length ||
          (messages.isNotEmpty &&
              _messages.isNotEmpty &&
              messages.last['id'] != _messages.last['id']);
      setState(() {
        _messages = messages;
        _canSend = data['canSend'] == true;
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
    if (raw['conversationId']?.toString() != widget.conversationId) return;
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
    if (message['isMine'] != true) {
      unawaited(_markRead());
    }
  }

  Future<void> _markRead() async {
    try {
      await _api.markConversationRead(widget.conversationId);
    } catch (_) {}
  }

  void _onSocketDeleted(Map<String, dynamic> raw) {
    if (!mounted) return;
    if (raw['conversationId']?.toString() != widget.conversationId) return;
    final id = raw['id']?.toString();
    if (id == null) return;
    setState(() {
      _messages = _messages.where((m) => m['id']?.toString() != id).toList();
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending || !_canSend) return;
    setState(() => _sending = true);
    try {
      final created = await _api.postDirectMessage(widget.conversationId, text);
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
      await _api.deleteDirectMessage(
        widget.conversationId,
        message['id'].toString(),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _clearChat() async {
    final ok = await confirmChatAction(
      context,
      title: 'Vider le chat ?',
      body: 'L’historique disparaît pour toi. ${widget.friendName} le garde.',
      confirmLabel: 'Vider',
    );
    if (!ok || !mounted) return;
    try {
      await _api.clearConversation(widget.conversationId);
      await _load(initial: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deleteConversation() async {
    final ok = await confirmChatAction(
      context,
      title: 'Supprimer la conversation ?',
      body:
          'Elle disparaît de ta liste. Un nouveau message ou un nouvel envoi depuis Amis la fera réapparaître, sans l’ancien historique.',
      confirmLabel: 'Supprimer',
    );
    if (!ok || !mounted) return;
    try {
      await _api.hideConversation(widget.conversationId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStaff = context.watch<AuthSession>().user?.isStaff ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.friendName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') _clearChat();
              if (value == 'delete') _deleteConversation();
              if (value == 'report' && widget.friendId != null) {
                showReportSheet(
                  context,
                  type: 'user',
                  targetId: widget.friendId!,
                  title: 'Signaler ${widget.friendName}',
                );
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'clear',
                child: Text('Vider le chat'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Supprimer la conversation'),
              ),
              if (widget.friendId != null)
                const PopupMenuItem(
                  value: 'report',
                  child: Text('Signaler le joueur'),
                ),
            ],
          ),
        ],
      ),
      body: ChatThread(
        messages: _messages,
        loading: _loading,
        error: _error,
        scroll: _scroll,
        input: _input,
        onSend: _send,
        sending: _sending,
        canSend: _canSend,
        cannotSendHint:
            'Vous n’êtes plus amis. Tu peux relire l’historique, plus envoyer.',
        canDelete: (m) => m['isMine'] == true || isStaff,
        onDelete: _delete,
        onReportMessage: (m) => showReportSheet(
          context,
          type: 'direct_message',
          targetId: m['id']?.toString() ?? '',
          title: 'Signaler le message',
        ),
        onReportUser: (m) => showReportSheet(
          context,
          type: 'user',
          targetId: m['authorId']?.toString() ?? widget.friendId ?? '',
          title: 'Signaler ${m['authorPseudo'] ?? widget.friendName}',
        ),
      ),
    );
  }
}

String conversationFriendName(Map<String, dynamic> conversation) {
  return staffPseudoOf(conversation['friend']);
}
