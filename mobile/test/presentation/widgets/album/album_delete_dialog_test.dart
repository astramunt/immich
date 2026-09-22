import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/presentation/widgets/album/album_delete_dialog.widget.dart';

import '../../../unit/factories/remote_album_factory.dart';
import '../../../unit/presentation/presentation_context.dart';

void main() {
  late PresentationContext context;

  setUp(() async => context = await PresentationContext.create());
  tearDown(() async => context.dispose());

  testWidgets('places delete album and contents below the existing action row', (tester) async {
    final album = RemoteAlbumFactory.create(name: 'Vacation');
    final openDialogKey = UniqueKey();

    await tester.pumpTestWidget(
      context,
      Builder(
        builder: (context) => TextButton(
          key: openDialogKey,
          onPressed: () => showAlbumDeleteDialog(context, [album]),
          child: const Text('Open'),
        ),
      ),
    );

    await tester.tap(find.byKey(openDialogKey));
    await tester.pumpAndSettle();

    final cancel = find.widgetWithText(TextButton, 'Cancel');
    final deleteAlbum = find.widgetWithText(TextButton, 'Delete album');
    final deleteWithContents = find.text('Delete album and trash contents');
    expect(cancel, findsOneWidget);
    expect(deleteAlbum, findsOneWidget);
    expect(deleteWithContents, findsOneWidget);
    expect(tester.getCenter(deleteWithContents).dy, greaterThan(tester.getCenter(deleteAlbum).dy));
    expect(find.byIcon(Icons.delete_sweep_rounded), findsOneWidget);
  });

  testWidgets('returns the album and contents action from the lower button', (tester) async {
    final album = RemoteAlbumFactory.create(name: 'Vacation');
    final openDialogKey = UniqueKey();
    AlbumDeleteAction? result;

    await tester.pumpTestWidget(
      context,
      Builder(
        builder: (context) => TextButton(
          key: openDialogKey,
          onPressed: () async => result = await showAlbumDeleteDialog(context, [album]),
          child: const Text('Open'),
        ),
      ),
    );

    await tester.tap(find.byKey(openDialogKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete album and trash contents'));
    await tester.pumpAndSettle();

    expect(result, AlbumDeleteAction.albumAndContents);
  });
}
