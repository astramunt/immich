import 'package:flutter/material.dart';
import 'package:immich_mobile/domain/models/album/album.model.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/generated/translations.g.dart';

enum AlbumDeleteAction { albumOnly, albumAndContents }

Future<AlbumDeleteAction?> showAlbumDeleteDialog(BuildContext context, List<RemoteAlbum> albums) {
  return showDialog<AlbumDeleteAction>(
    context: context,
    builder: (_) => AlbumDeleteDialog(albums: albums),
  );
}

class AlbumDeleteDialog extends StatelessWidget {
  final List<RemoteAlbum> albums;

  const AlbumDeleteDialog({super.key, required this.albums});

  @override
  Widget build(BuildContext context) {
    final count = albums.length;
    final confirmation = count == 1
        ? context.t.album_delete_confirmation(album: albums.single.name)
        : context.t.albums_delete_confirmation(count: count);

    return AlertDialog(
      title: Text(context.t.delete_albums(count: count)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(confirmation),
          const SizedBox(height: 8),
          Text(context.t.album_delete_confirmation_description),
          const SizedBox(height: 8),
          Text(context.t.album_delete_contents_description),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => context.pop<AlbumDeleteAction>(), child: Text(context.t.cancel)),
                  TextButton(
                    onPressed: () => context.pop(AlbumDeleteAction.albumOnly),
                    style: TextButton.styleFrom(foregroundColor: context.colorScheme.error),
                    child: Text(context.t.delete_albums(count: count)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () => context.pop(AlbumDeleteAction.albumAndContents),
                style: TextButton.styleFrom(
                  foregroundColor: context.colorScheme.onError,
                  backgroundColor: context.colorScheme.error,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: const Icon(Icons.delete_sweep_rounded),
                label: Text(context.t.delete_album_and_contents(count: count), textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
