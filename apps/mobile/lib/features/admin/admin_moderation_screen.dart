import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/i18n/fr_labels.dart';
import '../../core/network/api_client.dart';
import '../../design_system/tokens/colors.dart';
import '../auth/application/auth_session.dart';
import '../auth/domain/staff_label.dart';
import '../private_chat/conversation_screen.dart';

class AdminModerationScreen extends StatefulWidget {
  const AdminModerationScreen({super.key});

  @override
  State<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends State<AdminModerationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _messages = [];

  ApiClient get _api => context.read<AuthSession>().api;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _openReports =>
      _reports.where((r) => r['status'] == 'open').toList();

  List<Map<String, dynamic>> get _treatedReports =>
      _reports.where((r) => r['status'] == 'reviewed').toList();

  List<Map<String, dynamic>> get _closedReports => _reports
      .where((r) => r['status'] == 'closed' || r['status'] == 'dismissed')
      .toList();

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reports = await _api.adminListReports();
      final messages = await _api.adminListDeletedMessages();
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _messages = messages;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Chargement impossible';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openTreat(Map<String, dynamic> report) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => TreatReportDialog(report: report, api: _api),
    );
    if (result == null || result.isEmpty) return;
    await _reload();
    if (!mounted) return;
    if (result == 'reviewed') {
      _tabs.animateTo(1);
    } else if (result == 'closed' || result == 'dismissed') {
      _tabs.animateTo(2);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _close(Map<String, dynamic> report) async {
    await _run(
      () => _api.adminResolveReport(
        id: report['id'] as String,
        status: 'closed',
      ),
    );
    if (mounted) _tabs.animateTo(2);
  }

  Future<void> _unclose(Map<String, dynamic> report) async {
    await _run(
      () => _api.adminResolveReport(
        id: report['id'] as String,
        status: 'reviewed',
      ),
    );
    if (mounted) _tabs.animateTo(1);
  }

  Future<void> _reopen(Map<String, dynamic> report) async {
    await _run(
      () => _api.adminResolveReport(
        id: report['id'] as String,
        status: 'open',
      ),
    );
    if (mounted) _tabs.animateTo(0);
  }

  Future<void> _delete(Map<String, dynamic> report) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce signalement ?'),
        content: const Text('Il disparaîtra définitivement de la modération.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: FutBoliaColors.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => _api.adminDeleteReport(report['id'] as String));
  }

  @override
  Widget build(BuildContext context) {
    final openCount = _openReports.length;
    final treatedCount = _treatedReports.length;
    final closedCount = _closedReports.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modération'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: openCount == 0 ? 'À traiter' : 'À traiter ($openCount)'),
            Tab(text: treatedCount == 0 ? 'Traité' : 'Traité ($treatedCount)'),
            Tab(text: closedCount == 0 ? 'Clôturé' : 'Clôturé ($closedCount)'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                _error!,
                style: const TextStyle(color: FutBoliaColors.danger),
              ),
            ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _reportsList(
                  items: _openReports,
                  empty: 'Aucun signalement à traiter.',
                  stage: 'open',
                ),
                _reportsList(
                  items: _treatedReports,
                  empty: 'Aucun signalement traité en cours.',
                  stage: 'reviewed',
                ),
                _reportsList(
                  items: _closedReports,
                  empty: 'Aucun signalement clôturé.',
                  stage: 'closed',
                  extra: _deletedMessages(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportsList({
    required List<Map<String, dynamic>> items,
    required String empty,
    required String stage,
    List<Widget> extra = const [],
  }) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_loading && items.isEmpty) Text(empty),
          ...items.map((r) => _reportCard(r, stage: stage)),
          ...extra,
        ],
      ),
    );
  }

  Widget _reportCard(Map<String, dynamic> r, {required String stage}) {
    final target = r['target'] is Map
        ? Map<String, dynamic>.from(r['target'] as Map)
        : <String, dynamic>{};
    final typeLabel = r['typeLabel']?.toString() ??
        FrLabels.reportType(r['type']?.toString());
    final status = FrLabels.reportStatus(r['status']?.toString());
    final targetName = staffPseudoOf(target);
    final body = target['body']?.toString();
    final comment = r['comment']?.toString();
    final details = [
      'Par ${staffPseudoOf(r['reporter'])}'
          '${targetName.isNotEmpty && targetName != 'Joueur' ? ' · $targetName' : ''}',
      r['reason']?.toString() ?? '',
      if (body != null && body.isNotEmpty) '« $body »',
      if (comment != null && comment.isNotEmpty) 'Commentaire : $comment',
    ].where((line) => line.trim().isNotEmpty).join('\n');

    return Card(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text('$typeLabel · $status'),
              subtitle: Text(details),
              isThreeLine: true,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: switch (stage) {
                  'open' => [
                      TextButton(
                        onPressed: () => _delete(r),
                        style: TextButton.styleFrom(
                          foregroundColor: FutBoliaColors.danger,
                        ),
                        child: const Text('Supprimer'),
                      ),
                      TextButton(
                        onPressed: () => _close(r),
                        child: const Text('Clôturer'),
                      ),
                      FilledButton(
                        onPressed: () => _openTreat(r),
                        child: const Text('Traiter'),
                      ),
                    ],
                  'reviewed' => [
                      TextButton(
                        onPressed: () => _delete(r),
                        style: TextButton.styleFrom(
                          foregroundColor: FutBoliaColors.danger,
                        ),
                        child: const Text('Supprimer'),
                      ),
                      TextButton(
                        onPressed: () => _reopen(r),
                        child: const Text('Remettre à traiter'),
                      ),
                      FilledButton(
                        onPressed: () => _close(r),
                        child: const Text('Clôturer'),
                      ),
                    ],
                  _ => [
                      TextButton(
                        onPressed: () => _delete(r),
                        style: TextButton.styleFrom(
                          foregroundColor: FutBoliaColors.danger,
                        ),
                        child: const Text('Supprimer'),
                      ),
                      FilledButton.tonal(
                        onPressed: () => _unclose(r),
                        child: const Text('Déclôturer'),
                      ),
                    ],
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _deletedMessages() {
    return [
      const SizedBox(height: 24),
      Text('Messages supprimés', style: Theme.of(context).textTheme.titleMedium),
      if (!_loading && _messages.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('Aucun message supprimé récemment.'),
        ),
      ..._messages.map(
        (m) => ListTile(
          title: Text(staffPseudoOf(m['author'])),
          subtitle: Text(m['body']?.toString() ?? ''),
        ),
      ),
    ];
  }
}

const _timeoutPresets = [
  (60, '1 heure'),
  (360, '6 heures'),
  (1440, '24 heures'),
  (4320, '3 jours'),
  (10080, '7 jours'),
  (43200, '30 jours'),
];

class TreatReportDialog extends StatefulWidget {
  const TreatReportDialog({
    super.key,
    required this.report,
    required this.api,
  });

  final Map<String, dynamic> report;
  final ApiClient api;

  @override
  State<TreatReportDialog> createState() => _TreatReportDialogState();
}

class _TreatReportDialogState extends State<TreatReportDialog> {
  int _timeoutMinutes = 1440;
  bool _custom = false;
  final _customValue = TextEditingController(text: '2');
  String _customUnit = 'hours';
  bool _deleteMessage = false;
  bool _busy = false;

  Map<String, dynamic> get _target {
    final raw = widget.report['target'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  String? get _targetUserId {
    final id = _target['userId']?.toString() ??
        (widget.report['type'] == 'user'
            ? widget.report['targetId']?.toString()
            : null);
    if (id == null || id.isEmpty) return null;
    return id;
  }

  bool get _isMessage {
    final type = widget.report['type']?.toString();
    return type == 'message' || type == 'direct_message';
  }

  int get _resolvedMinutes {
    if (!_custom) return _timeoutMinutes;
    final n = int.tryParse(_customValue.text.trim()) ?? 0;
    if (n < 1) return 0;
    return _customUnit == 'days' ? n * 24 * 60 : n * 60;
  }

  @override
  void dispose() {
    _customValue.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _contact() async {
    final id = _targetUserId;
    if (id == null) return;
    await _run(() async {
      final conv = await widget.api.openConversation(id);
      if (!mounted) return;
      await openDirectChat(
        context,
        conversationId: conv['id'] as String,
        friendName: staffPseudoOf(_target),
        friendId: id,
        canSend: conv['canSend'] != false,
      );
    });
  }

  Future<void> _resolve({
    required String status,
    String? action,
    int? timeoutMinutes,
  }) async {
    await _run(() async {
      await widget.api.adminResolveReport(
        id: widget.report['id'] as String,
        status: status,
        action: action,
        timeoutMinutes: timeoutMinutes,
        deleteMessage: _deleteMessage,
      );
      if (!mounted) return;
      Navigator.pop(context, status);
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = staffPseudoOf(_target);
    return AlertDialog(
      title: const Text('Traiter le signalement'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '« Traiter » met le dossier dans Traité (pas encore clôturé). '
                'Tu peux contacter le joueur, le mettre en time-out, puis clôturer plus tard.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: FutBoliaColors.inkMuted,
                    ),
              ),
              const SizedBox(height: 12),
              Text(name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(widget.report['reason']?.toString() ?? ''),
              if (_target['body'] != null) ...[
                const SizedBox(height: 6),
                Text('« ${_target['body']} »'),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _busy || _targetUserId == null ? null : _contact,
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Contacter le joueur'),
              ),
              const SizedBox(height: 16),
              Text('Time-out', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._timeoutPresets.map(
                    (preset) => ChoiceChip(
                      label: Text(preset.$2),
                      selected: !_custom && _timeoutMinutes == preset.$1,
                      onSelected: _busy
                          ? null
                          : (_) => setState(() {
                                _custom = false;
                                _timeoutMinutes = preset.$1;
                              }),
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('Autre durée'),
                    selected: _custom,
                    onSelected: _busy
                        ? null
                        : (_) => setState(() => _custom = true),
                  ),
                ],
              ),
              if (_custom) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customValue,
                        keyboardType: TextInputType.number,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: 'Durée',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _customUnit,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _customUnit = v ?? 'hours'),
                      items: const [
                        DropdownMenuItem(value: 'hours', child: Text('heures')),
                        DropdownMenuItem(value: 'days', child: Text('jours')),
                      ],
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () {
                        final minutes = _resolvedMinutes;
                        if (minutes < 1) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Choisis une durée valide.'),
                            ),
                          );
                          return;
                        }
                        _resolve(
                          status: 'reviewed',
                          action: 'timeout',
                          timeoutMinutes: minutes,
                        );
                      },
                child: const Text('Time-out et traiter'),
              ),
              if (_isMessage)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _deleteMessage,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _deleteMessage = v ?? false),
                  title: const Text('Supprimer aussi le message'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () => _resolve(status: 'dismissed'),
          child: const Text('Rejeter'),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () => _resolve(status: 'closed'),
          child: const Text('Clôturer'),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () => _resolve(status: 'reviewed', action: 'none'),
          child: const Text('Marquer comme traité'),
        ),
      ],
    );
  }
}
