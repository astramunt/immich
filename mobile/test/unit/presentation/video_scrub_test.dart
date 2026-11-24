import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/providers/asset_viewer/video_player_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:native_video_player/native_video_player.dart';

class _VideoController extends Mock implements NativeVideoPlayerController {}

class _PlaybackInfo extends Mock implements PlaybackInfo {}

Duration _at(int milliseconds) => Duration(milliseconds: milliseconds);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late VideoPlayerNotifier player;
  late _VideoController controller;
  late _PlaybackInfo playback;
  final provider = videoPlayerProvider('scrubbing-video');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      (_) async => const StandardMessageCodec().encodeMessage([null]),
    );
    controller = _VideoController();
    playback = _PlaybackInfo();
    when(() => controller.playbackInfo).thenReturn(playback);
    when(() => playback.status).thenReturn(PlaybackStatus.paused);
    when(() => playback.position).thenReturn(0);
    when(() => controller.videoInfo).thenReturn(VideoInfo.fromJson({'height': 2160, 'width': 3840, 'duration': 12000}));
    when(() => controller.pause()).thenAnswer((_) async {});
    when(() => controller.play()).thenAnswer((_) async {});
    when(() => controller.seekTo(any())).thenAnswer((call) async {
      final position = call.positionalArguments.single as int;
      when(() => playback.position).thenReturn(position);
    });
    container = ProviderContainer();
    container.listen(provider, (_, _) {});
    player = container.read(provider.notifier)..attachController(controller);
    player.onNativePlaybackReady();
  });

  tearDown(() => container.dispose());

  test('uses only the newest scrub position and prevents preview callbacks from moving the thumb', () async {
    final first = Completer<void>();
    when(() => controller.seekPreview(1000)).thenAnswer((_) => first.future);
    when(() => controller.seekPreview(3300)).thenAnswer((_) async {});

    player.beginScrub();
    player.previewScrub(_at(1000));
    await _settle();
    player.previewScrub(_at(2400));
    player.previewScrub(_at(3300));
    when(() => playback.position).thenReturn(990);
    player.onNativePositionChanged();
    expect(container.read(provider).position, _at(3300));
    verify(() => controller.seekPreview(1000)).called(1);
    verifyNever(() => controller.seekPreview(2400));
    verifyNever(() => controller.seekPreview(3300));

    first.complete();
    await _settle();
    verify(() => controller.seekPreview(3300)).called(1);
    await player.finishScrub(_at(3275));
    verify(() => controller.seekTo(3275)).called(1);
    verifyNever(() => controller.play());
    expect(container.read(provider).position, _at(3275));
  });

  test('release cancels an active preview and resumes only after the precise seek completes', () async {
    final preview = Completer<void>();
    final precise = Completer<void>();
    when(() => controller.seekPreview(1000)).thenAnswer((_) => preview.future);
    when(() => controller.cancelPendingPreview()).thenAnswer((_) async => preview.complete());
    when(() => controller.seekTo(4000)).thenAnswer((_) => precise.future);
    when(() => playback.status).thenReturn(PlaybackStatus.playing);
    player.onNativePlaybackReady();

    player.beginScrub();
    player.previewScrub(_at(1000));
    await _settle();
    player.previewScrub(_at(2000));
    final finishing = player.finishScrub(_at(4000));
    await _settle();
    verifyInOrder([
      () => controller.pause(),
      () => controller.seekPreview(1000),
      () => controller.cancelPendingPreview(),
      () => controller.seekTo(4000),
    ]);
    verifyNever(() => controller.seekPreview(2000));
    verifyNever(() => controller.play());

    precise.complete();
    await finishing;
    verify(() => controller.play()).called(1);
  });

  test('a tap settles precisely as soon as the player pauses', () async {
    player.beginScrub();
    player.previewScrub(_at(4000));
    await player.finishScrub(_at(4000));
    verifyInOrder([() => controller.pause(), () => controller.seekTo(4000)]);
    verifyNever(() => controller.seekPreview(any()));
    verifyNever(() => controller.cancelPendingPreview());
    verifyNever(() => controller.play());
  });
}
