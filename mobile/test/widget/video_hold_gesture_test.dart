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
  final starts = <int>[];
  final stops = <bool>[];
  final seeks = <Duration>[];
  int toggles = 0;

  @override
  Future<void> startHoldPlayback({required int speed}) async {
    starts.add(speed);
    state = state.copyWith(holdSpeed: speed);
  }

  @override
  Future<void> stopHoldPlayback() async {
    stops.add(true);
  }

  @override
  void seekBy(Duration offset) => seeks.add(offset);

  @override
  void toggle() => toggles++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      (_) async => const StandardMessageCodec().encodeMessage([null]),
    );
  });

  Future<void> mount(
    WidgetTester tester,
    TestVideoPlayer player, {
    bool enabled = true,
    VoidCallback? onSideTap,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoPlayerProvider('video').overrideWith((_) => player),
          castProvider.overrideWith((_) => CastNotifier(MockCastService())),
          appConfigProvider.overrideWithValue(
            const AppConfig(viewer: ViewerConfig(holdSpeed: 5, doubleTapSeekSeconds: 10)),
          ),
        ],
        child: MaterialApp(
          home: VideoHoldGesture(
            assetId: 'video',
            enabled: enabled,
            onSingleTap: (_) => onSideTap?.call(),
            child: const PhotoView.customChild(
              childSize: Size(200, 100),
              child: ColoredBox(color: Colors.blue),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> doubleTapAt(WidgetTester tester, Offset position) async {
    await tester.tapAt(position);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(position);
    await tester.pump(const Duration(milliseconds: 100));
  }

  for (final x in [20.0, 780.0]) {
    testWidgets('holding either side uses the saved forward speed and releases', (tester) async {
      final player = TestVideoPlayer();
      await mount(tester, player);
      final gesture = await tester.startGesture(Offset(x, 300));
      await tester.pump(const Duration(milliseconds: 600));
      expect(player.starts, [5]);
      expect(find.text('×5'), findsOneWidget);
      await gesture.up();
      await tester.pump();
      expect(player.stops, isNotEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('double tapping the edges seeks by the saved duration in each direction', (tester) async {
    final player = TestVideoPlayer();
    await mount(tester, player);
    await doubleTapAt(tester, const Offset(20, 300));
    await tester.pump();
    await doubleTapAt(tester, const Offset(780, 300));
    await tester.pump();

    expect(player.seeks, [const Duration(seconds: -10), const Duration(seconds: 10)]);
    expect(find.text('+10 s'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tapping the center toggles playback and shows transient feedback', (tester) async {
    final player = TestVideoPlayer();
    await mount(tester, player);
    await tester.tapAt(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 400));

    expect(player.toggles, 1);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byIcon(Icons.play_arrow), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a single side tap keeps the existing viewer behavior', (tester) async {
    final player = TestVideoPlayer();
    var taps = 0;
    await mount(tester, player, onSideTap: () => taps++);
    await tester.tapAt(const Offset(20, 300));
    await tester.pump(const Duration(milliseconds: 700));

    expect(taps, 1);
    expect(player.toggles, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('disabled videos do not react to hold, double tap, or center tap', (tester) async {
    final player = TestVideoPlayer();
    await mount(tester, player, enabled: false);
    await tester.longPressAt(const Offset(780, 300));
    await doubleTapAt(tester, const Offset(780, 300));
    await tester.tapAt(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 400));

    expect(player.starts, isEmpty);
    expect(player.seeks, isEmpty);
    expect(player.toggles, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
