import 'package:capstone_project/data/cemetery_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('feedback is saved and available to the admin report', () async {
    SharedPreferences.setMockInitialValues({});
    final store = CemeteryStore.instance;
    await store.initialize();
    await store.addFeedback(userId: 'preview-visitor', rating: 4,
      message: 'The search was helpful.');
    await store.initialize();
    expect(store.feedback, hasLength(1));
    expect(store.feedback.single['rating'], 4);
    expect(store.feedback.single['message'], 'The search was helpful.');
  });
}
