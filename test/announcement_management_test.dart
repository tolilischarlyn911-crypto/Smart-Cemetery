import 'package:capstone_project/data/cemetery_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'edited and withdrawn announcements persist for visitor reads',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = CemeteryStore.instance;
      await store.initialize();
      final original = store.announcements.firstWhere(
        (item) => item['id'] == 'welcome',
      );

      await store.saveAnnouncement({
        ...original,
        'title': 'Updated visiting hours',
        'body': 'The office is open today.',
      });
      await store.initialize();
      expect(
        store.announcements,
        contains(
          isA<Map>().having(
            (item) => item['body'],
            'body',
            'The office is open today.',
          ),
        ),
      );

      await store.deleteAnnouncement('welcome');
      await store.initialize();
      expect(
        store.announcements.any((item) => item['id'] == 'welcome'),
        isFalse,
      );
    },
  );

  test(
    'announcements are shown newest first even when records arrive unordered',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = CemeteryStore.instance;
      await store.initialize();
      store.announcements
        ..clear()
        ..addAll([
          {'id': 'old', 'date': '2026-01-01T10:00:00'},
          {'id': 'undated'},
          {'id': 'new', 'date': '2026-09-01T10:00:00'},
        ]);

      expect(store.recentAnnouncements.map((item) => item['id']), [
        'new',
        'old',
        'undated',
      ]);
    },
  );
}
