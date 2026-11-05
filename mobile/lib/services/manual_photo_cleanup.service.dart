import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/infrastructure/repositories/settings.repository.dart';
import 'package:immich_mobile/platform/native_sync_api.g.dart' as platform;
import 'package:immich_mobile/repositories/asset_api.repository.dart';
import 'package:immich_mobile/services/cleanup.service.dart';
import 'package:logging/logging.dart';

typedef ManualUploadSession = ({String userId, String endpoint});

class ManualPhotoCleanupService {
  final SettingsRepository _settings;
  final AssetApiRepository _assets;
  final platform.NativeSyncApi _native;
  final CleanupService _cleanup;
  static final _log = Logger('ManualPhotoCleanupService');

  ManualPhotoCleanupService(this._settings, this._assets, this._native, this._cleanup);

  ManualUploadSession? get activeSession {
    if (!_settings.appConfig.backup.trashAfterManualPhotoUpload) {
      return null;
    }
    final user = Store.tryGet(StoreKey.currentUser);
    final endpoint = Store.tryGet(StoreKey.serverEndpoint);
    return user == null || endpoint == null ? null : (userId: user.id, endpoint: endpoint);
  }

  Future<void> removeVerified(
    ManualUploadSession session,
    List<LocalAsset> selected,
    Map<String, String> successful,
    Completer<void>? cancellation,
  ) async {
    bool allowed() =>
        session == activeSession &&
        cancellation?.isCompleted != true &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    final ids = <String>{};
    for (final asset in selected) {
      if (!allowed()) {
        return;
      }
      final remoteId = successful[asset.id];
      if ((!asset.isImage && !asset.isVideo) || remoteId == null) {
        continue;
      }
      try {
        final copy = await _assets.getUploadedMediaChecksums(remoteId, session.userId, isVideo: asset.isVideo);
        if (copy != null && await _native.matchesUploadedMedia(asset.id, asset.isVideo, copy.original, copy.motion)) {
          ids.add(asset.id);
        }
      } catch (error, stack) {
        _log.warning('Keeping local media ${asset.id}: could not verify its backup', error, stack);
      }
    }
    if (ids.isNotEmpty && allowed()) {
      // Free Up Space reconciles only IDs that the system actually removed.
      await _cleanup.deleteLocalAssets(ids.toList(), canContinue: allowed);
    }
  }
}
