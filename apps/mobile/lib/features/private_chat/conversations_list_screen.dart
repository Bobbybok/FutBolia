import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../design_system/tokens/colors.dart';
import '../auth/application/auth_session.dart';
import '../moderation/report_sheet.dart';
import '../profile/presentation/public_profile_screen.dart';
import 'conversation_screen.dart';
import 'widgets/conversation_tile.dart';

class ConversationsListScreen extends StatefulWidget {
  const ConversationsListScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ConversationsListScreen> createState() => _ConversationsListScreenState();
}

class _ConversationsListScreenState extends State<ConversationsListScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  ApiClient get _api => context.read<AuthSession>().api;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.listConversations();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Chargement impossible';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Map<String, dynamic> conversation) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationScreen(
          conversationId: conversation['id'] as String,
          friendName: conversationFriendName(conversation),
          friendId: userIdOf(conversation),
          canSend: conversation['canSend'] != false,
        ),
      ),
    );
    await _reload();
  }

  Future<void> _conversationActions(Map<String, dynamic> conversation) async {
    final id = userIdOf(conversation);
    final name = conversationFriendName(conversation);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.outlined_flag),
              title: const Text('Signaler le joueur'),
              onTap: () {
                Navigator.pop(ctx);
                if (id == null) return;
                showReportSheet(
                  context,
                  type: 'user',
                  targetId: id,
                  title: 'Signaler $name',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.only(top: 8),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                style: const TextStyle(color: FutBoliaColors.danger),
              ),
            ),
          if (_loading) const LinearProgressIndicator(),
          if (!_loading && _items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Aucun message privé. Ouvre une conversation depuis un ami.',
              ),
            ),
          ..._items.map(
            (c) => ConversationTile(
              conversation: c,
              onTap: () => _open(c),
              onLongPress: () => _conversationActions(c),
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: body,
    );
  }
}

