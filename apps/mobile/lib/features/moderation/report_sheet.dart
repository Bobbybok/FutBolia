import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../design_system/components/fb_button.dart';
import '../../design_system/tokens/colors.dart';
import '../auth/application/auth_session.dart';

const _fallbackMessageReasons = [
  ('spam', 'Spam / publicité'),
  ('harassment', 'Harcèlement'),
  ('hate', 'Insultes / propos haineux'),
  ('inappropriate', 'Contenu inapproprié'),
  ('impersonation', 'Usurpation d’identité'),
  ('other', 'Autre'),
];

const _fallbackUserReasons = [
  ('harassment', 'Harcèlement'),
  ('hate', 'Insultes / propos haineux'),
  ('fake_profile', 'Faux profil'),
  ('impersonation', 'Usurpation d’identité'),
  ('inappropriate', 'Pseudo, photo ou bio inapproprié(e)'),
  ('spam', 'Spam / publicité'),
  ('other', 'Autre'),
];

Future<bool> showReportSheet(
  BuildContext context, {
  required String type,
  required String targetId,
  String? title,
}) async {
  if (targetId.isEmpty) return false;
  final me = context.read<AuthSession>().user?.id;
  if (type == 'user' && me != null && me == targetId) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tu ne peux pas signaler ton propre profil.')),
    );
    return false;
  }
  final sent = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 640),
            child: ReportSheet(
              type: type,
              targetId: targetId,
              title: title,
            ),
          ),
        ),
      );
    },
  );
  if (sent == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Signalement envoyé. L’équipe de modération va l’examiner.',
        ),
      ),
    );
  }
  return sent == true;
}

class ReportSheet extends StatefulWidget {
  const ReportSheet({
    super.key,
    required this.type,
    required this.targetId,
    this.title,
  });

  final String type;
  final String targetId;
  final String? title;

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  final _comment = TextEditingController();
  String? _code;
  bool _sending = false;
  List<(String, String)> _reasons = [];

  @override
  void initState() {
    super.initState();
    _reasons = widget.type == 'user'
        ? List.of(_fallbackUserReasons)
        : List.of(_fallbackMessageReasons);
    _loadReasons();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _loadReasons() async {
    try {
      final data = await context.read<AuthSession>().api.listReportReasons();
      final raw = data[widget.type] ?? data['message'];
      if (raw is! List || raw.isEmpty || !mounted) return;
      final parsed = <(String, String)>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final code = item['code']?.toString() ?? '';
        final label = item['label']?.toString() ?? '';
        if (code.isEmpty || label.isEmpty) continue;
        parsed.add((code, label));
      }
      if (parsed.isEmpty) return;
      setState(() => _reasons = parsed);
    } catch (_) {
      // Keep the built-in reasons if the API is unreachable.
    }
  }

  String get _headline {
    if (widget.title != null && widget.title!.trim().isNotEmpty) {
      return widget.title!;
    }
    switch (widget.type) {
      case 'user':
        return 'Signaler ce profil';
      case 'direct_message':
        return 'Signaler ce message privé';
      default:
        return 'Signaler ce message';
    }
  }

  Future<void> _submit() async {
    final code = _code;
    if (code == null || _sending) return;
    final comment = _comment.text.trim();
    if (code == 'other' && comment.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Décris le problème (au moins 3 caractères).'),
        ),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await context.read<AuthSession>().api.createReport(
            type: widget.type,
            targetId: widget.targetId,
            reasonCode: code,
            comment: comment.isEmpty ? null : comment,
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _headline,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Fermer',
                  onPressed:
                      _sending ? null : () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Choisis un motif. Tu peux ajouter un commentaire.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: FutBoliaColors.inkMuted,
                  ),
            ),
            const SizedBox(height: 12),
            ..._reasons.map(
              (reason) => ListTile(
                onTap: _sending
                    ? null
                    : () => setState(() => _code = reason.$1),
                leading: Icon(
                  _code == reason.$1
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: FutBoliaColors.pitch,
                ),
                title: Text(reason.$2),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _comment,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              enabled: !_sending,
              decoration: InputDecoration(
                labelText: _code == 'other'
                    ? 'Commentaire (obligatoire)'
                    : 'Commentaire (optionnel)',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FbButton(
              label: 'Envoyer le signalement',
              loading: _sending,
              onPressed: _code == null || _sending ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
