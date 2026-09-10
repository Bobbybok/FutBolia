import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/media/pick_compressed_image.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/media_url.dart';
import '../../../core/realtime/live_bindings.dart';
import '../../../design_system/components/fb_button.dart';
import '../../../design_system/tokens/colors.dart';
import '../../auth/application/auth_session.dart';

class TournamentCoverBanner extends StatelessWidget {
  const TournamentCoverBanner({
    super.key,
    required this.tournamentId,
    this.imageUrl,
    this.canEdit = false,
    this.onChanged,
  });

  final String tournamentId;
  final String? imageUrl;
  final bool canEdit;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final url = apiMediaUrl(imageUrl);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: FutBoliaColors.surfaceRaisedDark,
              child: url == null
                  ? const Icon(
                      Icons.emoji_events_outlined,
                      size: 56,
                      color: Colors.white54,
                    )
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.emoji_events_outlined,
                        size: 56,
                        color: Colors.white54,
                      ),
                    ),
            ),
            if (canEdit)
              Positioned(
                right: 10,
                bottom: 10,
                child: Row(
                  children: [
                    _CoverAction(
                      icon: Icons.photo_camera_outlined,
                      label: imageUrl == null || imageUrl!.isEmpty
                          ? 'Photo'
                          : 'Changer',
                      onTap: () => _upload(context),
                    ),
                    if (imageUrl != null && imageUrl!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _CoverAction(
                        icon: Icons.delete_outline,
                        label: 'Retirer',
                        danger: true,
                        onTap: () => _remove(context),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _upload(BuildContext context) async {
    try {
      final picked = await pickCompressedImage();
      if (picked == null || !context.mounted) return;
      await context.read<AuthSession>().api.uploadTournamentCover(
            tournamentId: tournamentId,
            bytes: picked.bytes,
            filename: picked.filename,
            contentType: picked.contentType,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo du tournoi mise à jour')),
      );
      onChanged?.call();
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ajouter la photo')),
      );
    }
  }

  Future<void> _remove(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirer la photo du tournoi ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: FutBoliaColors.danger),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await context
          .read<AuthSession>()
          .api
          .deleteTournamentCover(tournamentId);
      if (!context.mounted) return;
      onChanged?.call();
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _CoverAction extends StatelessWidget {
  const _CoverAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: danger
          ? FutBoliaColors.danger.withValues(alpha: 0.92)
          : FutBoliaColors.lime,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: danger ? Colors.white : FutBoliaColors.ink,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: danger ? Colors.white : FutBoliaColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TournamentAlbumSection extends StatefulWidget {
  const TournamentAlbumSection({
    super.key,
    required this.tournamentId,
    this.canManage = false,
  });

  final String tournamentId;
  final bool canManage;

  @override
  State<TournamentAlbumSection> createState() => _TournamentAlbumSectionState();
}

class _TournamentAlbumSectionState extends State<TournamentAlbumSection> {
  List<Map<String, dynamic>> _photos = [];
  bool _busy = false;
  final _live = LiveBindings();

  @override
  void initState() {
    super.initState();
    _load();
    _live.listenTournament(widget.tournamentId, (_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _live.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final photos = await context
          .read<AuthSession>()
          .api
          .listTournamentPhotos(widget.tournamentId);
      if (!mounted) return;
      setState(() => _photos = photos);
    } on ApiException {
      // Keep last known list.
    }
  }

  Future<void> _add() async {
    try {
      final picked = await pickCompressedImage();
      if (picked == null || !mounted) return;
      setState(() => _busy = true);
      await context.read<AuthSession>().api.uploadTournamentPhoto(
            tournamentId: widget.tournamentId,
            bytes: picked.bytes,
            filename: picked.filename,
            contentType: picked.contentType,
          );
      if (!mounted) return;
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo ajoutée à l’album')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ajouter la photo')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openAlbum() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FutBoliaColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _AlbumPopup(
          tournamentId: widget.tournamentId,
          photos: _photos,
          canAdd: widget.canManage,
          onAdd: () async {
            Navigator.pop(ctx);
            await _add();
          },
          onChanged: _load,
        );
      },
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final count = _photos.length;
    final albumLabel = count == 0 ? 'Album' : 'Album ($count)';
    return FbButton(
      label: albumLabel,
      variant: FbButtonVariant.secondary,
      onPressed: _openAlbum,
    );
  }
}

class _AlbumPopup extends StatelessWidget {
  const _AlbumPopup({
    required this.tournamentId,
    required this.photos,
    required this.canAdd,
    required this.onAdd,
    required this.onChanged,
  });

  final String tournamentId;
  final List<Map<String, dynamic>> photos;
  final bool canAdd;
  final VoidCallback onAdd;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.94;
    return SafeArea(
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: FutBoliaColors.lineDark,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Album',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: FutBoliaColors.inkDark,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  if (canAdd)
                    TextButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Ajouter'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: photos.isEmpty
                    ? Center(
                        child: Text(
                          'Aucune photo pour le moment.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: FutBoliaColors.inkMuted,
                                  ),
                        ),
                      )
                    : GridView.builder(
                        itemCount: photos.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemBuilder: (context, index) {
                          final photo = photos[index];
                          final url = apiMediaUrl(photo['url']?.toString());
                          return InkWell(
                            onTap: () => _openPhoto(context, photo),
                            onLongPress: photo['canDelete'] == true
                                ? () => _delete(context, photo)
                                : null,
                            borderRadius: BorderRadius.circular(10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: url == null
                                  ? const ColoredBox(
                                      color: FutBoliaColors.surfaceRaisedDark,
                                      child: Icon(
                                        Icons.image_outlined,
                                        color: Colors.white54,
                                      ),
                                    )
                                  : Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          const ColoredBox(
                                        color: FutBoliaColors.surfaceRaisedDark,
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPhoto(BuildContext context, Map<String, dynamic> photo) {
    final url = apiMediaUrl(photo['url']?.toString());
    if (url == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PhotoViewer(
          url: url,
          canDelete: photo['canDelete'] == true,
          onDelete: () {
            Navigator.of(context).pop();
            _delete(context, photo);
          },
        ),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    Map<String, dynamic> photo,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette photo ?'),
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
    if (ok != true || !context.mounted) return;
    try {
      await context.read<AuthSession>().api.deleteTournamentPhoto(
            tournamentId: tournamentId,
            photoId: photo['id'].toString(),
          );
      if (!context.mounted) return;
      Navigator.of(context).pop();
      onChanged();
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({
    required this.url,
    required this.canDelete,
    required this.onDelete,
  });

  final String url;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        actions: [
          if (canDelete)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class TournamentListThumb extends StatelessWidget {
  const TournamentListThumb({super.key, this.imageUrl, this.size = 56});

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = apiMediaUrl(imageUrl);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: url == null
            ? const ColoredBox(
                color: FutBoliaColors.surfaceRaisedDark,
                child: Icon(Icons.emoji_events_outlined, color: Colors.white54),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: FutBoliaColors.surfaceRaisedDark,
                  child: Icon(
                    Icons.emoji_events_outlined,
                    color: Colors.white54,
                  ),
                ),
              ),
      ),
    );
  }
}
