import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/data/db/main/database.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/config/app_config.dart';
import 'package:immich_mobile/domain/models/config/backup_config.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/domain/services/store.service.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/infrastructure/repositories/store.repository.dart';
import 'package:immich_mobile/repositories/asset_api.repository.dart';
import 'package:immich_mobile/services/manual_photo_cleanup.service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openapi/api.dart' as api;

import '../fixtures/asset.stub.dart';
import '../fixtures/user.stub.dart';
import '../infrastructure/repository.mock.dart';
import '../repository.mocks.dart';
import '../service.mocks.dart';

class _AssetsApi extends Mock implements api.AssetsApi {}

class _StacksApi extends Mock implements api.StacksApi {}

class _TrashApi extends Mock implements api.TrashApi {}

class _AssetResponse extends Mock implements api.AssetResponseDto {}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final native = MockNativeSyncApi();
  final remote = MockAssetApiRepository();
  final cleanup = MockCleanupService();
  final settings = MockSettingsRepository();
  final service = ManualPhotoCleanupService(settings, remote, native, cleanup);
  final photo = LocalAssetStub.image1;
  final second = LocalAssetStub.image2;
  final user = UserStub.admin;
  late Drift db;

  setUpAll(() async {
    registerFallbackValue(() => true);
    db = Drift(NativeDatabase.memory());
    await StoreService.init(storeRepository: StoreRepository(db));
    await Store.put(StoreKey.currentUser, user);
    await Store.put(StoreKey.serverEndpoint, 'test');
  });

  tearDownAll(() async {
    await Store.dispose();
    await db.close();
  });

  setUp(() {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    reset(cleanup);
    reset(remote);
    reset(native);
    when(() => settings.appConfig).thenReturn(const AppConfig(backup: BackupConfig(trashAfterManualPhotoUpload: true)));
    when(() => cleanup.deleteLocalAssets(any(), canContinue: any(named: 'canContinue'))).thenAnswer((_) async => 1);
  });

  test('remote verification accepts standalone video only when active, owned and of the expected type', () async {
    final assetsApi = _AssetsApi();
    final repository = AssetApiRepository(assetsApi, _StacksApi(), _TrashApi());
    final video = _AssetResponse();
    when(() => assetsApi.getAssetInfo('id')).thenAnswer((_) async => video);
    when(() => video.id).thenReturn('id');
    when(() => video.ownerId).thenReturn(user.id);
    when(() => video.isOffline).thenReturn(false);
    when(() => video.isTrashed).thenReturn(false);
    when(() => video.type).thenReturn(api.AssetTypeEnum.VIDEO);
    when(() => video.checksum).thenReturn('video-content');
    when(() => video.livePhotoVideoId).thenReturn(const api.Optional.absent());
    expect(await repository.getUploadedMediaChecksums('id', user.id, isVideo: true), (
      original: 'video-content',
      motion: null,
    ));
    expect(await repository.getUploadedMediaChecksums('id', user.id, isVideo: false), isNull);
    expect(await repository.getUploadedMediaChecksums('id', 'another-user', isVideo: true), isNull);
    when(() => video.isTrashed).thenReturn(true);
    expect(await repository.getUploadedMediaChecksums('id', user.id, isVideo: true), isNull);
  });

  test('requests only verified local IDs and retains unverified and failed items in a mixed batch', () async {
    final video = photo.copyWith(id: 'video-id', type: AssetType.video);
    when(
      () => remote.getUploadedMediaChecksums('ok', user.id, isVideo: false),
    ).thenAnswer((_) async => (original: 'photo', motion: 'video'));
    when(() => native.matchesUploadedMedia(photo.id, false, 'photo', 'video')).thenAnswer((_) async => true);
    when(
      () => remote.getUploadedMediaChecksums('partial', user.id, isVideo: false),
    ).thenAnswer((_) async => (original: 'partial', motion: null));
    when(() => native.matchesUploadedMedia(second.id, false, 'partial', null)).thenAnswer((_) async => false);
    when(
      () => remote.getUploadedMediaChecksums('remote-video', user.id, isVideo: true),
    ).thenAnswer((_) async => (original: 'movie', motion: null));
    when(() => native.matchesUploadedMedia(video.id, true, 'movie', null)).thenAnswer((_) async => true);
    await service.removeVerified(
      service.activeSession!,
      [photo, video, second, photo.copyWith(id: 'failed')],
      {photo.id: 'ok', video.id: 'remote-video', second.id: 'partial'},
      null,
    );
    verify(() => cleanup.deleteLocalAssets([photo.id, video.id], canContinue: any(named: 'canContinue'))).called(1);
  });

  test('skips removal when cancelled or the setting is switched off during verification', () async {
    final session = service.activeSession!;
    await service.removeVerified(session, [photo], {photo.id: 'ok'}, Completer<void>()..complete());
    verifyNever(() => remote.getUploadedMediaChecksums(any(), any(), isVideo: any(named: 'isVideo')));
    when(
      () => remote.getUploadedMediaChecksums('ok', user.id, isVideo: false),
    ).thenAnswer((_) async => (original: 'photo', motion: null));
    when(() => native.matchesUploadedMedia(photo.id, false, 'photo', null)).thenAnswer((_) async {
      when(() => settings.appConfig).thenReturn(const AppConfig());
      return true;
    });
    await service.removeVerified(session, [photo], {photo.id: 'ok'}, null);
    verifyNever(() => cleanup.deleteLocalAssets(any(), canContinue: any(named: 'canContinue')));
  });
}
