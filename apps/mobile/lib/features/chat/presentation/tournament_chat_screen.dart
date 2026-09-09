import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../design_system/tokens/colors.dart';
import '../../auth/application/auth_session.dart';
import '../../moderation/report_sheet.dart';
import '../widgets/chat_thread.dart';

class TournamentChatScreen extends StatefulWidget {
  const TournamentChatScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
    this.isOrganizer = false,
  });

  final String tournamentId;
  final String tournamentName;
  final bool isOrganizer;

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
  Timer? _poll;

  @override
  void initState() {
    super.initState();
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
      final messages = await context
          .read<AuthSession>()
          .api
          .listChatMessages(widget.tournamentId);
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

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await context.read<AuthSession>().api.postChatMessage(
            widget.tournamentId,
            text,
          );
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
      await context
          .read<AuthSession>()
          .api
          .deleteChatMessage(message['id'].toString());
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
        title: Text('Chat · ${widget.tournamentName}'),
      ),
      body: ChatThread(
        messages: _messages,
        loading: _loading,
        error: _error,
        scroll: _scroll,
        input: _input,
        onSend: _send,
        sending: _sending,
        canDelete: (m) => m['isMine'] == true || widget.isOrganizer,
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
    );
  }
}
