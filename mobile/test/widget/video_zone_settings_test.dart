import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/models/config/app_config.dart';
import 'package:immich_mobile/domain/models/config/viewer_config.dart';
import 'package:immich_mobile/domain/models/settings_key.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/video_zone_frames.widget.dart';
import 'package:immich_mobile/providers/infrastructure/settings.provider.dart';
import 'package:immich_mobile/widgets/settings/asset_viewer_settings/video_viewer_settings.dart';
import 'package:mocktail/mocktail.dart';

import '../infrastructure/repository.mock.dart';
import '../widget_tester_extensions.dart';

void main() {
  testWidgets('edit mode previews decimal dp input and saves only valid sizes', (tester) async {
    final repository = MockSettingsRepository();
    when(() => repository.write(SettingsKey.viewerPauseBoxSize, 245.5)).thenAnswer((_) async {});
    await tester.pumpConsumerWidget(
      const SingleChildScrollView(child: VideoViewerSettings()),
      overrides: [
        settingsProvider.overrideWithValue(repository),
        appConfigProvider.overrideWithValue(const AppConfig(viewer: ViewerConfig(showVideoZoneFrames: true))),
      ],
    );
    final pause = find.text('96 dp');
    await tester.ensureVisible(pause);
    await tester.tap(pause);
    await tester.pumpAndSettle();
    final preview = find.byType(VideoZoneFrames);
    expect(tester.widget<VideoZoneFrames>(preview).zones.pause.width, 96);
    final input = find.byType(TextField);
    await tester.enterText(input, '-10');
    await tester.pump();
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Save')).onPressed, isNull);
    await tester.enterText(input, '245,5');
    await tester.pump();
    expect(tester.widget<VideoZoneFrames>(preview).zones.pause.width, 245.5);
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
    verify(() => repository.write(SettingsKey.viewerPauseBoxSize, 245.5)).called(1);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
