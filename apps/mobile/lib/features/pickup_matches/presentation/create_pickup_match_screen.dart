import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../design_system/components/fb_button.dart';
import '../../../design_system/tokens/colors.dart';
import '../../auth/application/auth_session.dart';

class CreatePickupMatchScreen extends StatefulWidget {
  const CreatePickupMatchScreen({super.key});

  @override
  State<CreatePickupMatchScreen> createState() =>
      _CreatePickupMatchScreenState();
}

class _CreatePickupMatchScreenState extends State<CreatePickupMatchScreen> {
  final _location = TextEditingController();
  final _playersPerTeam = TextEditingController(text: '5');
  DateTime _scheduledAt = DateTime.now().add(const Duration(days: 1));
  String _visibility = 'public';
  bool _loading = false;

  @override
  void dispose() {
    _location.dispose();
    _playersPerTeam.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      initialDate: _scheduledAt,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null) return;
    setState(() {
      _scheduledAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    final session = context.read<AuthSession>();
    if (!session.user!.emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vérifie ton e-mail avant de créer un match.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await session.api.createPickupMatch({
        'location': _location.text.trim(),
        'scheduledAt': _scheduledAt.toUtc().toIso8601String(),
        'playersPerTeam': int.tryParse(_playersPerTeam.text.trim()) ?? 5,
        'visibility': _visibility,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un match')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _location,
            decoration: const InputDecoration(labelText: 'Lieu'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _playersPerTeam,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Joueurs par équipe',
              helperText: 'Capacité totale = 2 × ce nombre',
            ),
          ),
          const SizedBox(height: 14),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date et heure'),
            subtitle: Text(_scheduledAt.toLocal().toString().substring(0, 16)),
            trailing: const Icon(Icons.event),
            onTap: _pickDate,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _visibility,
            decoration: const InputDecoration(labelText: 'Visibilité'),
            items: const [
              DropdownMenuItem(value: 'public', child: Text('Public')),
              DropdownMenuItem(value: 'private', child: Text('Privé (code)')),
            ],
            onChanged: (v) => setState(() => _visibility = v ?? 'public'),
          ),
          const SizedBox(height: 24),
          FbButton(
            label: 'Créer le match',
            loading: _loading,
            onPressed: _submit,
          ),
          const SizedBox(height: 12),
          Text(
            'L’e-mail doit être vérifié. Tu es automatiquement inscrit côté A (hôte).',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: FutBoliaColors.inkMuted,
                ),
          ),
        ],
      ),
    );
  }
}
