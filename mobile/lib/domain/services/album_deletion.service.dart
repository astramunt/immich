import 'package:immich_mobile/domain/models/album/album.model.dart';
import 'package:immich_mobile/domain/services/asset.service.dart';
import 'package:immich_mobile/domain/services/remote_album.service.dart';

class AlbumDeletionService {
  final RemoteAlbumService _albumService;
  final AssetService _assetService;

  const AlbumDeletionService(this._albumService, this._assetService);

  /// Moves unique assets owned by [ownerId] from [albums] to the trash.
  ///
  /// Albums may contain assets contributed by other users. Those assets are
  /// intentionally excluded because the server only grants delete access to
  /// the asset owner.
  Future<int> trashOwnedContents(Iterable<RemoteAlbum> albums, String ownerId) async {
    final contents = await Future.wait(albums.map((album) => _albumService.getAssets(album.id)));
    final assetIds = contents
        .expand((assets) => assets)
        .where((asset) => asset.ownerId == ownerId)
        .map((asset) => asset.id)
        .toSet()
        .toList(growable: false);

    await _assetService.trash(assetIds);
    return assetIds.length;
  }
}
