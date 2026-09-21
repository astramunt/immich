import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/services/video_hold_playback.dart';
import 'package:mocktail/mocktail.dart';
import 'package:native_video_player/native_video_player.dart';

class MockVideoController extends Mock implements NativeVideoPlayerController {}

class MockPlaybackInfo extends Mock implements PlaybackInfo {}

void main() {
  late MockVideoController controller;
  late MockPlaybackInfo playback;
  late List<int> speeds;

  setUp(() {
    controller = MockVideoController();
    playback = MockPlaybackInfo();
    speeds = [];
    when(() => controller.playbackInfo).thenReturn(playback);
    when(() => playback.status).thenReturn(PlaybackStatus.playing);
    when(() => controller.setPlaybackSpeed(any())).thenAnswer((_) async {});
  });

  for (final speed in VideoHoldPlayback.speeds) {
    test('holding at ×$speed restores normal speed on release', () async {
      final hold = VideoHoldPlayback(controller, onSpeedChanged: speeds.add);
      await hold.start(speed: speed);
      await hold.stop();

      verifyInOrder([() => controller.setPlaybackSpeed(speed.toDouble()), () => controller.setPlaybackSpeed(1)]);
      expect(speeds, [speed, 0]);
      hold.dispose();
    });
  }

  test('does not activate before playback starts', () async {
    when(() => playback.status).thenReturn(PlaybackStatus.paused);
    final hold = VideoHoldPlayback(controller, onSpeedChanged: speeds.add);
    await hold.start(speed: 2);

    expect(speeds, isEmpty);
    verifyNever(() => controller.setPlaybackSpeed(any()));
    hold.dispose();
  });

  test('release during activation restores speed after the pending change', () async {
    final pending = Completer<void>();
    when(() => controller.setPlaybackSpeed(10)).thenAnswer((_) => pending.future);
    final hold = VideoHoldPlayback(controller, onSpeedChanged: speeds.add);
    final start = hold.start(speed: 10);
    await Future<void>.delayed(Duration.zero);
    final stop = hold.stop();
    pending.complete();
    await Future.wait([start, stop]);

    verifyInOrder([() => controller.setPlaybackSpeed(10), () => controller.setPlaybackSpeed(1)]);
    expect(hold.isActive, isFalse);
    hold.dispose();
  });

  test('invalid saved speed falls back to ×2', () async {
    final hold = VideoHoldPlayback(controller, onSpeedChanged: speeds.add);
    await hold.start(speed: -5);

    verify(() => controller.setPlaybackSpeed(2)).called(1);
    await hold.stop();
    hold.dispose();
  });

  test('failed speed change clears the indicator and restores normal speed', () async {
    when(() => controller.setPlaybackSpeed(5)).thenThrow(StateError('Playback unavailable'));
    final hold = VideoHoldPlayback(controller, onSpeedChanged: speeds.add);
    await hold.start(speed: 5);
    await hold.stop();

    expect(speeds, [5, 0]);
    verify(() => controller.setPlaybackSpeed(1)).called(1);
    hold.dispose();
  });
}
