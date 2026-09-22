import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/presentation/widgets/album/album_drag_selection.widget.dart';

void main() {
  testWidgets('reports the anchor and albums entered during a long-press drag', (tester) async {
    int? anchor;
    final entered = <int>[];
    var ended = false;

    await tester.pumpWidget(
      MaterialApp(
        home: AlbumDragSelectionRegion(
          onStart: (index) => anchor = index,
          onAlbumEnter: entered.add,
          onEnd: () => ended = true,
          onScroll: (_) {},
          child: Column(
            children: List.generate(
              3,
              (index) => AlbumIndexWrapper(
                index: index,
                child: SizedBox(
                  key: ValueKey(index),
                  width: 300,
                  height: 100,
                  child: const ColoredBox(color: Colors.blue),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey(0))));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey(2))));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(anchor, 0);
    expect(entered, contains(2));
    expect(ended, isTrue);
  });
}
