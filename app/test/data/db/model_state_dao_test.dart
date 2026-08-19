import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/daos/model_state_dao.dart';
import 'package:period_tracker/data/db/database.dart';

ModelStateRow rowWith(String hash) => ModelStateRow(
  id: ModelStateDao.singletonId,
  inputHash: hash,
  stateMean: 3.33,
  stateVariance: 0.002,
  stateObservations: 6,
  obsSd: 0.02,
  driftSd: 0.004,
  personalised: true,
  medianDays: 28,
  lo50: 27,
  hi50: 29,
  lo80: 26,
  hi80: 30,
  confidence: 'high',
);

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('starts empty', () async {
    expect(await db.modelStateDao.current(), isNull);
    expect(await db.modelStateDao.matching('anything'), isNull);
  });

  test('stores and reads back the cached posterior', () async {
    await db.modelStateDao.store(rowWith('abc'));
    final row = await db.modelStateDao.current();
    expect(row!.inputHash, 'abc');
    expect(row.stateMean, 3.33);
    expect(row.personalised, isTrue);
    expect(row.confidence, 'high');
  });

  test('matches only the hash it was computed from', () async {
    await db.modelStateDao.store(rowWith('abc'));
    expect(await db.modelStateDao.matching('abc'), isNotNull);
    expect(await db.modelStateDao.matching('abd'), isNull);
  });

  test('holds one row however many times it is written', () async {
    // The posterior is per user and there is one user per device. A second row
    // would mean two answers to the same question.
    await db.modelStateDao.store(rowWith('abc'));
    await db.modelStateDao.store(rowWith('def'));
    expect(await db.select(db.modelStates).get(), hasLength(1));
    expect((await db.modelStateDao.current())!.inputHash, 'def');
  });

  test('clears', () async {
    await db.modelStateDao.store(rowWith('abc'));
    await db.modelStateDao.clear();
    expect(await db.modelStateDao.current(), isNull);
  });
}
