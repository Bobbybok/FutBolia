import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../design_system/components/fb_button.dart';
import '../../auth/application/auth_session.dart';
import '../../geo/nearby_filters.dart';
import '../../geo/place_picker.dart';

class CreateTournamentScreen extends StatefulWidget {
  const CreateTournamentScreen({super.key});

  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _maxTeams = TextEditingController(text: '8');
  final _starters = TextEditingController(text: '5');
  DateTime _startsAt = DateTime.now().add(const Duration(days: 7));
  String _mode = 'classic';
  String _visibility = 'public';
  GeoPoint? _place;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
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
    if (_place == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis un lieu sur la carte.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await session.api.createTournament({
        'name': _name.text.trim(),
        'location': (_place!.label ?? _name.text).trim(),
        'latitude': _place!.latitude,
        'longitude': _place!.longitude,
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
          PlacePickerField(onChanged: (p) => setState(() => _place = p)),
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
          const SizedBox(height: 28),
          FbButton(
            label: _loading ? 'Création…' : 'Créer le tournoi',
            loading: _loading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
