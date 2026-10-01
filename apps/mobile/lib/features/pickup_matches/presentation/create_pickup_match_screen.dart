import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../design_system/components/fb_button.dart';
import '../../auth/application/auth_session.dart';
import '../../geo/nearby_filters.dart';
import '../../geo/place_picker.dart';

class CreatePickupMatchScreen extends StatefulWidget {
  const CreatePickupMatchScreen({super.key});

  @override
  State<CreatePickupMatchScreen> createState() =>
      _CreatePickupMatchScreenState();
}

class _CreatePickupMatchScreenState extends State<CreatePickupMatchScreen> {
  final _playersPerTeam = TextEditingController(text: '5');
  DateTime _scheduledAt = DateTime.now().add(const Duration(days: 1));
  String _visibility = 'public';
  GeoPoint? _place;
  bool _loading = false;

  @override
  void dispose() {
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
    if (_place == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis un lieu sur la carte.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await session.api.createPickupMatch({
        'location': (_place!.label ?? 'Match').trim(),
        'latitude': _place!.latitude,
        'longitude': _place!.longitude,
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
          PlacePickerField(onChanged: (p) => setState(() => _place = p)),
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
            label: _loading ? 'Création…' : 'Créer le match',
            loading: _loading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
