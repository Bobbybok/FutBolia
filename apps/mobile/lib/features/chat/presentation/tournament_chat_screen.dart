import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../design_system/tokens/colors.dart';
import '../../auth/application/auth_session.dart';

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
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _messages.isEmpty
                        ? Center(
                            child: Text(
                              'Aucun message. Lance la conversation.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: FutBoliaColors.inkMuted),
                            ),
                          )
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final m = _messages[index];
                              final mine = m['isMine'] == true;
                              final canDelete =
                                  mine || widget.isOrganizer;
                              return Align(
                                alignment: mine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width * 0.78,
                                  ),
                                  child: InkWell(
                                    onLongPress: canDelete
                                        ? () => _delete(m)
                                        : null,
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
                                            : FutBoliaColors.surfaceRaised,
                                        borderRadius: BorderRadius.circular(14),
                                        border: mine
                                            ? null
                                            : Border.all(
                                                color: FutBoliaColors.line,
                                              ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (!mine)
                                            Text(
                                              m['authorPseudo']?.toString() ??
                                                  'Joueur',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelMedium
                                                  ?.copyWith(
                                                    color: FutBoliaColors.pitch,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          if (!mine) const SizedBox(height: 4),
                                          Text(
                                            m['body']?.toString() ?? '',
                                            style: TextStyle(
                                              color: mine
                                                  ? Colors.white
                                                  : FutBoliaColors.ink,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Écrire un message…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: FutBoliaColors.pitch,
                      foregroundColor: Colors.white,
                    ),
                    icon: _sending
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
          ),
        ],
      ),
    );
  }
}
