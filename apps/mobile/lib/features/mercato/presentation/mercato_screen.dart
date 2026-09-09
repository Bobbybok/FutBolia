import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/i18n/fr_labels.dart';
import '../../../core/network/api_client.dart';
import '../../../design_system/components/fb_badge.dart';
import '../../../design_system/tokens/colors.dart';
import '../../auth/application/auth_session.dart';
import '../../auth/domain/staff_label.dart';
import '../../moderation/report_sheet.dart';

class MercatoScreen extends StatefulWidget {
  const MercatoScreen({
    super.key,
    required this.tournamentId,
    required this.canSendOffers,
    this.selectorTeamId,
    this.offerTeams = const [],
  });

  final String tournamentId;
  final bool canSendOffers;
  final String? selectorTeamId;
  /// Équipes pour lesquelles l’utilisateur peut proposer (sélectionneur / orga).
  final List<Map<String, dynamic>> offerTeams;

  @override
  State<MercatoScreen> createState() => _MercatoScreenState();
}

class _MercatoScreenState extends State<MercatoScreen> {
  List<Map<String, dynamic>> _players = [];
  List<Map<String, dynamic>> _myOffers = [];
  bool _loading = true;
  String? _error;
  String? _activeTeamId;

  @override
  void initState() {
    super.initState();
    _activeTeamId = widget.selectorTeamId ??
        (widget.offerTeams.length == 1
            ? widget.offerTeams.first['id']?.toString()
            : null);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthSession>().api;
      final board = await api.getMercato(widget.tournamentId);
      final offers = await api.getMyOffers(tournamentId: widget.tournamentId);
      if (!mounted) return;
      setState(() {
        _players = board;
        _myOffers = offers;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _resolveTeamId() async {
    if (_activeTeamId != null) return _activeTeamId;
    if (widget.offerTeams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aucune équipe avec sélectionneur. Assigne-en un depuis l’équipe.',
          ),
        ),
      );
      return null;
    }
    if (widget.offerTeams.length == 1) {
      return widget.offerTeams.first['id']?.toString();
    }
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            children: [
              const ListTile(title: Text('Recruter pour quelle équipe ?')),
              ...widget.offerTeams.map(
                (t) => ListTile(
                  title: Text(t['name']?.toString() ?? 'Équipe'),
                  onTap: () => Navigator.pop(context, t),
                ),
              ),
            ],
          ),
        );
      },
    );
    final id = selected?['id']?.toString();
    if (id != null && mounted) {
      setState(() => _activeTeamId = id);
    }
    return id;
  }

  Future<void> _sendOffer(String playerId) async {
    final teamId = await _resolveTeamId();
    if (teamId == null || !mounted) return;
    try {
      await context.read<AuthSession>().api.createOffer({
        'teamId': teamId,
        'playerId': playerId,
      });
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proposition envoyée')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _respond(String offerId, {required bool accept}) async {
    try {
      final api = context.read<AuthSession>().api;
      if (accept) {
        await api.acceptOffer(offerId);
      } else {
        await api.rejectOffer(offerId);
      }
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  String? get _activeTeamName {
    final id = _activeTeamId;
    if (id == null) return null;
    for (final t in widget.offerTeams) {
      if (t['id']?.toString() == id) return t['name']?.toString();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mercato MatchArena'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      if (widget.canSendOffers) ...[
                        Text(
                          _activeTeamName == null
                              ? 'Équipe de recrutement : à choisir'
                              : 'Recrute pour : $_activeTeamName',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (widget.offerTeams.length > 1)
                          TextButton(
                            onPressed: () async {
                              setState(() => _activeTeamId = null);
                              await _resolveTeamId();
                            },
                            child: const Text('Changer d’équipe'),
                          ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        'Joueurs du mercato',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (_players.isEmpty)
                        Text(
                          'Aucun joueur libre pour le moment.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: FutBoliaColors.inkMuted,
                              ),
                        )
                      else
                        ..._players.map((p) {
                          final status = p['status']?.toString();
                          final playerId = p['userId']?.toString() ??
                              p['id']?.toString() ??
                              '';
                          final canOffer = widget.canSendOffers &&
                              status == 'available';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              staffPseudoOf(p),
                            ),
                            subtitle: Text(
                              FrLabels.mercatoStatus(status),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Signaler',
                                  onPressed: playerId.isEmpty
                                      ? null
                                      : () => showReportSheet(
                                            context,
                                            type: 'user',
                                            targetId: playerId,
                                            title: 'Signaler ${staffPseudoOf(p)}',
                                          ),
                                  icon: const Icon(Icons.flag_outlined),
                                ),
                                if (canOffer)
                                  TextButton(
                                    onPressed: () => _sendOffer(playerId),
                                    child: const Text('Proposer'),
                                  )
                                else
                                  FbBadge(
                                    label: FrLabels.mercatoStatus(status),
                                  ),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 28),
                      Text(
                        'Mes offres',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (_myOffers.isEmpty)
                        Text(
                          'Aucune offre.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: FutBoliaColors.inkMuted,
                              ),
                        )
                      else
                        ..._myOffers.map((o) {
                          final offerId = o['id']?.toString() ?? '';
                          final status = o['status']?.toString();
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              o['teamName']?.toString() ?? 'Offre reçue',
                            ),
                            subtitle: Text(FrLabels.mercatoStatus(status)),
                            trailing: status == 'pending'
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Accepter',
                                        onPressed: () =>
                                            _respond(offerId, accept: true),
                                        icon: const Icon(Icons.check),
                                      ),
                                      IconButton(
                                        tooltip: 'Refuser',
                                        onPressed: () =>
                                            _respond(offerId, accept: false),
                                        icon: const Icon(Icons.close),
                                      ),
                                    ],
                                  )
                                : FbBadge(
                                    label: FrLabels.mercatoStatus(status),
                                  ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}
