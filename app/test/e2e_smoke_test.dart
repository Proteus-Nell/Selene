// The end-to-end smoke flow, run headless (AND-19).
//
// The same flow as `integration_test/e2e_smoke_test.dart`, which runs on a real
// device. This copy runs in `flutter test` on every push, so the sequence is
// guarded continuously rather than only when someone remembers to plug a phone
// in. Neither replaces the other: this one cannot prove the app installs and
// starts, and the device one does not run in CI.

import 'package:flutter_test/flutter_test.dart';

import 'e2e/smoke_flow.dart';

void main() {
  testWidgets('onboard, log, predict, export, wipe, import, predict again', (
    tester,
  ) async {
    await runSmokeFlow(tester);
  });
}
