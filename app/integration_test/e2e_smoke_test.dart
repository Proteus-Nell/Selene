// The end-to-end smoke flow, run on a real device (AND-19).
//
// The same sequence as `test/e2e_smoke_test.dart`, which runs headless in CI.
// Neither replaces the other. This one is the only thing that proves the app
// installs, starts, and can write a file through Android's storage access
// framework on a real filesystem; the headless one is the only one that runs on
// every push. The flow itself lives in one place so the two cannot drift.
//
//   flutter test integration_test/e2e_smoke_test.dart -d <device>

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/e2e/smoke_flow.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onboard, log, predict, export, wipe, import, predict again', (
    tester,
  ) async {
    await runSmokeFlow(tester);
  });
}
