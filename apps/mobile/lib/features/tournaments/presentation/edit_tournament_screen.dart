import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/i18n/fr_labels.dart';
import '../../../core/network/api_client.dart';
import '../../../design_system/components/fb_button.dart';
import '../../auth/application/auth_session.dart';

class EditTournamentScreen extends StatefulWidget {
  const EditTournamentScreen({super.key, required this.tournament});

  final Map<String, dynamic> tournament;

  @override
  State<EditTournamentScreen> createState() => _EditTournamentScreenState();
}

class _EditTournamentScreenState extends State<EditTournamentScreen> {
  late final TextEditingController _name;
  late final TextEditingController _location;
  late final TextEditingController _description;
  late final TextEditingController _maxTeams;
  late final TextEditingController _starters;
  late DateTime _startsAt;
  late String _mode;
  late String _visibility;
  late String _status;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final t = widget.tournament;
    _name = TextEditingController(text: t['name']?.toString() ?? '');
    _location = TextEditingController(text: t['location']?.toString() ?? '');
    _description =
        TextEditingController(text: t['description']?.toString() ?? '');
    _maxTeams = TextEditingController(text: '${t['maxTeams'] ?? 8}');
    _starters = TextEditingController(text: '${t['startersCount'] ?? 5}');
    _startsAt = DateTime.tryParse(t['startsAt']?.toString() ?? '')?.toLocal() ??
        DateTime.now();
    _mode = t['mode']?.toString() ?? 'classic';
    _visibility = t['visibility']?.toString() ?? 'public';
    _status = t['status']?.toString() ?? 'registration_open';
  }

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
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
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
    setState(() => _loading = true);
    try {
      await context.read<AuthSession>().api.updateTournament(
        widget.tournament['id'].toString(),
        {
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
          'status': _status,
        },
      );
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
      appBar: AppBar(title: const Text('Modifier le tournoi')),
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
          DropdownMenu<String>(
            initialSelection: _mode,
            label: const Text('Mode'),
            expandedInsets: EdgeInsets.zero,
            dropdownMenuEntries: const [
              DropdownMenuEntry(value: 'classic', label: 'Classique'),
              DropdownMenuEntry(
                value: 'selection',
                label: 'Sélection / Mercato',
              ),
            ],
            onSelected: (v) => setState(() => _mode = v ?? 'classic'),
          ),
          const SizedBox(height: 14),
          DropdownMenu<String>(
            initialSelection: _visibility,
            label: const Text('Visibilité'),
            expandedInsets: EdgeInsets.zero,
            dropdownMenuEntries: const [
              DropdownMenuEntry(value: 'public', label: 'Public'),
              DropdownMenuEntry(value: 'private', label: 'Privé'),
            ],
            onSelected: (v) => setState(() => _visibility = v ?? 'public'),
          ),
          const SizedBox(height: 14),
          DropdownMenu<String>(
            initialSelection: _status,
            label: const Text('Statut'),
            expandedInsets: EdgeInsets.zero,
            dropdownMenuEntries: [
              for (final status in const [
                'draft',
                'registration_open',
                'registration_closed',
                'in_progress',
                'finished',
                'cancelled',
              ])
                DropdownMenuEntry(
                  value: status,
                  label: FrLabels.tournamentStatus(status),
                ),
            ],
            onSelected: (v) =>
                setState(() => _status = v ?? 'registration_open'),
          ),
          const SizedBox(height: 24),
          FbButton(
            label: 'Enregistrer',
            loading: _loading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
