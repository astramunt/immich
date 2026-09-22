import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/services/album_deletion.service.dart';
import 'package:mocktail/mocktail.dart';

import '../../service.mocks.dart';
import '../factories/remote_album_factory.dart';
import '../factories/remote_asset_factory.dart';

void main() {
  late MockRemoteAlbumService albumService;
  late MockAssetService assetService;
  late AlbumDeletionService sut;

  setUp(() {
    albumService = MockRemoteAlbumService();
    assetService = MockAssetService();
    sut = AlbumDeletionService(albumService, assetService);
  });

  test('trashes unique assets owned by the current user across selected albums', () async {
    const ownerId = '11111111-1111-4111-8111-111111111111';
    final firstAlbum = RemoteAlbumFactory.create(id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
    final secondAlbum = RemoteAlbumFactory.create(id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
    final firstAsset = RemoteAssetFactory.create(id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', ownerId: ownerId);
    final duplicateAsset = RemoteAssetFactory.create(id: firstAsset.id, ownerId: ownerId);
    final secondAsset = RemoteAssetFactory.create(id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd', ownerId: ownerId);
    final contributedAsset = RemoteAssetFactory.create(
      id: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
      ownerId: 'ffffffff-ffff-4fff-8fff-ffffffffffff',
    );

    when(() => albumService.getAssets(firstAlbum.id)).thenAnswer((_) async => [firstAsset, contributedAsset]);
    when(() => albumService.getAssets(secondAlbum.id)).thenAnswer((_) async => [duplicateAsset, secondAsset]);
    when(() => assetService.trash(any())).thenAnswer((_) async {});

    final count = await sut.trashOwnedContents([firstAlbum, secondAlbum], ownerId);

    expect(count, 2);
    final ids = verify(() => assetService.trash(captureAny())).captured.single as List<String>;
    expect(ids.toSet(), {firstAsset.id, secondAsset.id});
    verify(() => albumService.getAssets(firstAlbum.id)).called(1);
    verify(() => albumService.getAssets(secondAlbum.id)).called(1);
  });
}
