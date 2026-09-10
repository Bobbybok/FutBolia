import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../design_system/components/fb_button.dart';
import '../../../design_system/tokens/colors.dart';
import '../../auth/application/auth_session.dart';

class CreateTournamentScreen extends StatefulWidget {
  const CreateTournamentScreen({super.key});

  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  final _maxTeams = TextEditingController(text: '8');
  final _starters = TextEditingController(text: '5');
  DateTime _startsAt = DateTime.now().add(const Duration(days: 7));
  String _mode = 'classic';
  String _visibility = 'public';
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _description.dispose();
    _maxTeams.dispose();
    _starters.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      initialDate: _startsAt,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (time == null) return;
    setState(() {
      _startsAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    final session = context.read<AuthSession>();
    if (!session.user!.emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vérifie ton e-mail avant de créer un tournoi.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await session.api.createTournament({
        'name': _name.text.trim(),
        'location': _location.text.trim(),
        'description': _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        'startsAt': _startsAt.toUtc().toIso8601String(),
        'maxTeams': int.tryParse(_maxTeams.text.trim()) ?? 8,
        'startersCount': int.tryParse(_starters.text.trim()) ?? 5,
        'mode': _mode,
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
      appBar: AppBar(title: const Text('Créer un tournoi')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nom du tournoi'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _location,
            decoration: const InputDecoration(labelText: 'Lieu'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _maxTeams,
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: 'Nombre d’équipes max'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _starters,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Titulaires par équipe',
              helperText: 'Même nombre de remplaçants que de titulaires',
            ),
          ),
          const SizedBox(height: 14),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date et heure'),
            subtitle: Text(_startsAt.toLocal().toString().substring(0, 16)),
            trailing: const Icon(Icons.event),
            onTap: _pickDate,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _mode,
            decoration: const InputDecoration(labelText: 'Mode'),
            items: const [
              DropdownMenuItem(value: 'classic', child: Text('Classique')),
              DropdownMenuItem(
                value: 'selection',
                child: Text('Sélection / Mercato'),
              ),
            ],
            onChanged: (v) => setState(() => _mode = v ?? 'classic'),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _visibility,
            decoration: const InputDecoration(labelText: 'Visibilité'),
            items: const [
              DropdownMenuItem(value: 'public', child: Text('Public')),
              DropdownMenuItem(value: 'private', child: Text('Privé (invitation)')),
            ],
            onChanged: (v) => setState(() => _visibility = v ?? 'public'),
          ),
          const SizedBox(height: 24),
          FbButton(
            label: 'Créer le tournoi',
            loading: _loading,
            onPressed: _submit,
          ),
          const SizedBox(height: 12),
          Text(
            'L’e-mail doit être vérifié. Les permissions sont contrôlées par le serveur.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: FutBoliaColors.inkMuted,
                ),
          ),
        ],
      ),
    );
  }
}
