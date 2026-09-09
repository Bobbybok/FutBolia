import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../design_system/tokens/colors.dart';
import '../auth/application/auth_session.dart';
import '../auth/domain/staff_label.dart';
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
  Timer? _poll;

  ApiClient get _api => context.read<AuthSession>().api;

  @override
  void initState() {
    super.initState();
    _canSend = widget.canSend;
    _load(initial: true);
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
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

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending || !_canSend) return;
    setState(() => _sending = true);
    try {
      await _api.postDirectMessage(widget.conversationId, text);
      _input.clear();
      await _load();
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
        title: const Text('Supprimer le message ?'),
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
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.friendName),
        actions: [
          if (widget.friendId != null)
            IconButton(
              tooltip: 'Signaler',
              onPressed: () => showReportSheet(
                context,
                type: 'user',
                targetId: widget.friendId!,
                title: 'Signaler ${widget.friendName}',
              ),
              icon: const Icon(Icons.flag_outlined),
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
        canDelete: (m) => m['isMine'] == true,
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
