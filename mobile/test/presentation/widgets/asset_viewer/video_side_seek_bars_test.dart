import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/video_side_seek_bars.widget.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/viewer_bottom_app_bar.widget.dart';
import 'package:immich_mobile/providers/asset_viewer/asset_viewer.provider.dart';
import 'package:immich_mobile/providers/asset_viewer/video_player_provider.dart';
import 'package:immich_mobile/services/gcast.service.dart';
import 'package:immich_mobile/widgets/asset_viewer/video_controls.dart';

import '../../../service.mocks.dart';
import '../../../unit/factories/remote_asset_factory.dart';

final _video = RemoteAssetFactory.create(type: .video);

class _Viewer extends AssetViewerStateNotifier {
  @override
  AssetViewerState build() => AssetViewerState(currentAsset: _video);
}

class _Player extends VideoPlayerNotifier {
  int holds = 0;
  int releases = 0;

  void setLoadedPosition() =>
      state = state.copyWith(duration: const Duration(seconds: 100), position: const Duration(seconds: 25));

  @override
  void seekTo(Duration position) => state = state.copyWith(position: position);

  @override
  void hold() => holds++;

  @override
  void release() => releases++;
}

void main() {
  for (final size in const [Size(390, 844), Size(844, 390)]) {
    testWidgets('both edges track and seek the same timeline at $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
        'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
        (_) async => const StandardMessageCodec().encodeMessage([null]),
      );
      final player = _Player();
      var viewerTaps = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            assetViewerProvider.overrideWith(_Viewer.new),
            videoPlayerProvider(_video.id).overrideWith((_) => player),
            gCastServiceProvider.overrideWithValue(MockGCastService()),
          ],
          child: MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                extendBody: true,
                extendBodyBehindAppBar: true,
                appBar: AppBar(),
                bottomNavigationBar: ViewerControlsVisibility(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [VideoControls(videoPlayerName: _video.id)],
                  ),
                ),
                body: Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => viewerTaps++),
                    const VideoSideSeekBars(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final sliders = find.byType(Slider);
      expect(sliders, findsNWidgets(3));
      expect(tester.widgetList<Slider>(sliders).every((s) => s.onChanged == null), isTrue);
      player.setLoadedPosition();
      await tester.pump();
      expect(tester.widgetList<Slider>(sliders).map((s) => s.value), everyElement(25000000.0));

      final sides = find.descendant(of: find.byType(VideoSideSeekBars), matching: sliders);
      final centers = [tester.getCenter(sides.first), tester.getCenter(sides.last)];
      expect(centers.map((p) => p.dx), unorderedEquals([24.0, size.width - 24]));
      for (final center in centers) {
        final gesture = await tester.startGesture(center + const Offset(0, 80));
        await tester.pump(const Duration(milliseconds: 200));
        final start = player.state.position;
        await gesture.moveBy(const Offset(0, -160));
        await tester.pump();
        expect(player.state.position, greaterThan(start));
        final later = player.state.position;
        await gesture.moveBy(const Offset(0, 60));
        await tester.pump();
        expect(player.state.position, lessThan(later));
        await gesture.up();
        await tester.pump();
        expect(
          tester.widgetList<Slider>(sliders).map((s) => s.value),
          everyElement(player.state.position.inMicroseconds.toDouble()),
        );
      }
      expect(player.holds, 2);
      expect(player.releases, 2);
      expect(viewerTaps, 0);
      await tester.tapAt(size.center(Offset.zero));
      expect(viewerTaps, 1);

      final ref = ProviderScope.containerOf(tester.element(find.byType(VideoSideSeekBars)));
      ref.read(assetViewerProvider.notifier).setControls(false);
      await tester.pumpAndSettle();
      await tester.tapAt(centers.first);
      expect(viewerTaps, 2);
      ref.read(assetViewerProvider.notifier).setShowingDetails(true);
      await tester.pumpAndSettle();
      expect(sides, findsNothing);
      ref.read(assetViewerProvider.notifier).setShowingDetails(false);
      await tester.pumpAndSettle();
      expect(sides.hitTestable(), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
