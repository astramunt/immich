import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/models/album/album.model.dart';
import 'package:immich_mobile/models/albums/album_search.model.dart';
import 'package:immich_mobile/presentation/pages/album.page.dart';
import 'package:immich_mobile/providers/album/album_sort_by_options.provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../unit/factories/remote_album_factory.dart';
import '../../unit/factories/remote_asset_factory.dart';
import '../../unit/presentation/presentation_context.dart';

void main() {
  late PresentationContext context;

  setUpAll(() {
    registerFallbackValue(<RemoteAlbum>[]);
    registerFallbackValue(AlbumSortMode.lastModified);
    registerFallbackValue(QuickFilterMode.all);
  });
  setUp(() async => context = await PresentationContext.create());
  tearDown(() async => context.dispose());

  void stubAlbumList(List<RemoteAlbum> albums) {
    when(() => context.service.album.service.getAll()).thenAnswer((_) async => albums);
    when(
      () => context.service.album.service.sortAlbums(any(), any(), isReverse: any(named: 'isReverse')),
    ).thenAnswer((invocation) async => invocation.positionalArguments.first as List<RemoteAlbum>);
    when(
      () => context.service.album.service.searchAlbums(any(), any(), any(), any()),
    ).thenAnswer((invocation) => invocation.positionalArguments.first as List<RemoteAlbum>);
    when(() => context.service.asset.service.getRemoteAsset(any())).thenAnswer((_) async => null);
  }

  testWidgets('long press starts album selection and taps add more albums', (tester) async {
    final albums = [
      RemoteAlbumFactory.create(
        id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        name: 'First album',
        ownerId: context.currentUser.id,
      ),
      RemoteAlbumFactory.create(
        id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        name: 'Second album',
        ownerId: context.currentUser.id,
      ),
    ];
    stubAlbumList(albums);

    await tester.pumpTestWidget(context, const AlbumsPage(), expectSettle: false);
    await tester.pumpUntilFound(find.text('First album'));

    await tester.longPress(find.text('First album'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

    await tester.tap(find.text('Second album'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Are you sure you want to delete these 2 albums?'), findsOneWidget);
    expect(find.text('Delete albums and trash contents'), findsOneWidget);
  });

  testWidgets('long-press drag selects the album range', (tester) async {
    final albums = [
      RemoteAlbumFactory.create(
        id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        name: 'First album',
        ownerId: context.currentUser.id,
      ),
      RemoteAlbumFactory.create(
        id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        name: 'Second album',
        ownerId: context.currentUser.id,
      ),
    ];
    stubAlbumList(albums);

    await tester.pumpTestWidget(context, const AlbumsPage(), expectSettle: false);
    await tester.pumpUntilFound(find.text('First album'));

    final gesture = await tester.startGesture(tester.getCenter(find.text('First album')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveTo(tester.getCenter(find.text('Second album')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('2 selected'), findsOneWidget);
  });

  testWidgets('trashes album contents before deleting the selected album', (tester) async {
    final album = RemoteAlbumFactory.create(
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      name: 'First album',
      ownerId: context.currentUser.id,
    );
    final asset = RemoteAssetFactory.create(
      id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      ownerId: context.currentUser.id,
    );
    stubAlbumList([album]);
    when(() => context.service.album.service.getAssets(album.id)).thenAnswer((_) async => [asset]);
    when(() => context.service.album.service.deleteAlbum(album.id)).thenAnswer((_) async {});

    await tester.pumpTestWidget(context, const AlbumsPage(), expectSettle: false);
    await tester.pumpUntilFound(find.text('First album'));
    await tester.longPress(find.text('First album'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete album and trash contents'));
    await tester.pumpAndSettle();

    verifyInOrder([
      () => context.service.album.service.getAssets(album.id),
      () => context.service.asset.service.trash([asset.id]),
      () => context.service.album.service.deleteAlbum(album.id),
    ]);
    expect(find.text('Album deleted'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
