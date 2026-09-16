import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/config/app_config.dart';
import 'package:immich_mobile/domain/models/config/viewer_config.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/video_hold_gesture.widget.dart';
import 'package:immich_mobile/providers/asset_viewer/video_player_provider.dart';
import 'package:immich_mobile/providers/cast.provider.dart';
import 'package:immich_mobile/providers/infrastructure/settings.provider.dart';
import 'package:immich_mobile/services/gcast.service.dart';
import 'package:immich_mobile/widgets/photo_view/photo_view.dart';
import 'package:mocktail/mocktail.dart';

class MockCastService extends Mock implements GCastService {}

class TestVideoPlayer extends VideoPlayerNotifier {
  final starts = <({bool reverse, int speed})>[];
  final stops = <bool>[];

  @override
  Future<void> startHoldPlayback({required bool reverse, required int speed}) async {
    starts.add((reverse: reverse, speed: speed));
    state = state.copyWith(holdSpeed: reverse ? -speed : speed);
  }

  @override
  Future<void> stopHoldPlayback({bool resume = true}) async {
    stops.add(resume);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      (_) async => const StandardMessageCodec().encodeMessage([null]),
    );
  });

  Future<void> mount(WidgetTester tester, TestVideoPlayer player, {bool enabled = true, VoidCallback? onTap}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoPlayerProvider('video').overrideWith((_) => player),
          castProvider.overrideWith((_) => CastNotifier(MockCastService())),
          appConfigProvider.overrideWithValue(const AppConfig(viewer: ViewerConfig(holdSpeed: 5))),
        ],
        child: MaterialApp(
          home: VideoHoldGesture(
            assetId: 'video',
            enabled: enabled,
            child: PhotoView.customChild(
              childSize: const Size(200, 100),
              onTapUp: (_, _, _) => onTap?.call(),
              child: const ColoredBox(color: Colors.blue),
            ),
          ),
        ),
      ),
    );
  }

  for (final reverse in [true, false]) {
    testWidgets('holding the ${reverse ? 'left' : 'right'} letterbox uses the saved speed and releases', (
      tester,
    ) async {
      final player = TestVideoPlayer();
      await mount(tester, player);
      final gesture = await tester.startGesture(Offset(reverse ? 20 : 780, 40));
      await tester.pump(const Duration(milliseconds: 600));
      expect(player.starts, [(reverse: reverse, speed: 5)]);
      expect(find.text('×5'), findsOneWidget);
      await gesture.up();
      await tester.pump();
      expect(player.stops, contains(true));
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('short taps still reach the photo viewer', (tester) async {
    final player = TestVideoPlayer();
    var taps = 0;
    await mount(tester, player, onTap: () => taps++);
    await tester.tapAt(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 600));
    expect(taps, 1);
    expect(player.starts, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('disabled videos and motion photos do not start a hold', (tester) async {
    final player = TestVideoPlayer();
    await mount(tester, player, enabled: false);
    await tester.longPressAt(const Offset(780, 300));
    expect(player.starts, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pointer cancellation releases temporary playback', (tester) async {
    final player = TestVideoPlayer();
    await mount(tester, player);
    final gesture = await tester.startGesture(const Offset(20, 300));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.cancel();
    await tester.pump();
    expect(player.stops, contains(true));
    await tester.pumpWidget(const SizedBox());
  });
}
