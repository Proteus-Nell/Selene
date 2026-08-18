import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/domain/models/day_log.dart';

void main() {
  group('FlowIntensity.isBleeding', () {
    test('light, medium and heavy count as bleeding', () {
      expect(FlowIntensity.light.isBleeding, isTrue);
      expect(FlowIntensity.medium.isBleeding, isTrue);
      expect(FlowIntensity.heavy.isBleeding, isTrue);
    });

    test('spotting deliberately does NOT count as bleeding', () {
      // This is a real domain decision, not an oversight. If spotting opened a
      // cycle, a single spotting day mid-cycle would create a spurious short
      // cycle that the prediction filter then has to reject as an outlier.
      expect(FlowIntensity.spotting.isBleeding, isFalse);
    });

    test('none does not count as bleeding', () {
      expect(FlowIntensity.none.isBleeding, isFalse);
    });
  });

  group('DayLog defaults', () {
    test('a bare entry has no flow and no symptoms', () {
      final log = DayLog(date: CivilDate(2026, 8, 17));
      expect(log.flow, FlowIntensity.none);
      expect(log.symptoms, isEmpty);
      expect(log.isBleedingDay, isFalse);
      expect(log.isEmpty, isTrue);
    });

    test('severityOf returns none for an unrecorded symptom', () {
      final log = DayLog(date: CivilDate(2026, 8, 17));
      for (final symptom in Symptom.values) {
        expect(log.severityOf(symptom), SymptomSeverity.none);
      }
    });

    test('severityOf returns the recorded value', () {
      final log = DayLog(
        date: CivilDate(2026, 8, 17),
        symptoms: const {Symptom.cramps: SymptomSeverity.severe},
      );
      expect(log.severityOf(Symptom.cramps), SymptomSeverity.severe);
      expect(log.severityOf(Symptom.headache), SymptomSeverity.none);
    });
  });

  group('DayLog.isEmpty', () {
    test('is false once flow is recorded', () {
      final log = DayLog(
        date: CivilDate(2026, 8, 17),
        flow: FlowIntensity.spotting,
      );
      expect(log.isEmpty, isFalse);
    });

    test('is false once a symptom is recorded', () {
      final log = DayLog(
        date: CivilDate(2026, 8, 17),
        symptoms: const {Symptom.mood: SymptomSeverity.mild},
      );
      expect(log.isEmpty, isFalse);
    });

    test('is true when every recorded symptom is none', () {
      // An entry like this carries no information. Treating it as empty keeps
      // "no entry" meaning "not logged" rather than "logged as nothing", which
      // matters because a gap is what tells segmentation a cycle may be missing.
      final log = DayLog(
        date: CivilDate(2026, 8, 17),
        symptoms: const {
          Symptom.mood: SymptomSeverity.none,
          Symptom.sleep: SymptomSeverity.none,
        },
      );
      expect(log.isEmpty, isTrue);
    });
  });

  group('value semantics', () {
    test('equality is by value', () {
      final a = DayLog(
        date: CivilDate(2026, 8, 17),
        flow: FlowIntensity.medium,
        symptoms: const {Symptom.cramps: SymptomSeverity.moderate},
      );
      final b = DayLog(
        date: CivilDate(2026, 8, 17),
        flow: FlowIntensity.medium,
        symptoms: const {Symptom.cramps: SymptomSeverity.moderate},
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differing on any field breaks equality', () {
      final base = DayLog(date: CivilDate(2026, 8, 17));
      expect(base, isNot(base.copyWith(date: CivilDate(2026, 8, 18))));
      expect(base, isNot(base.copyWith(flow: FlowIntensity.heavy)));
      expect(
        base,
        isNot(
          base.copyWith(
            symptoms: const {Symptom.cramps: SymptomSeverity.mild},
          ),
        ),
      );
    });

    test('copyWith leaves the original untouched', () {
      final original = DayLog(date: CivilDate(2026, 8, 17));
      final copy = original.copyWith(flow: FlowIntensity.heavy);
      expect(original.flow, FlowIntensity.none);
      expect(copy.flow, FlowIntensity.heavy);
      expect(copy.date, original.date);
    });
  });

  group('JSON round-trip', () {
    test('a fully populated entry survives a round-trip', () {
      final log = DayLog(
        date: CivilDate(2024, 2, 29),
        flow: FlowIntensity.heavy,
        symptoms: const {
          Symptom.cramps: SymptomSeverity.severe,
          Symptom.headache: SymptomSeverity.mild,
          Symptom.mood: SymptomSeverity.moderate,
        },
      );
      expect(DayLog.fromJson(log.toJson()), log);
    });

    test('a bare entry survives a round-trip', () {
      final log = DayLog(date: CivilDate(2026, 8, 17));
      expect(DayLog.fromJson(log.toJson()), log);
    });

    test('the date is encoded as a plain YYYY-MM-DD string', () {
      final json = DayLog(date: CivilDate(2026, 1, 2)).toJson();
      expect(json['date'], '2026-01-02');
    });

    test('enums are encoded by name, so the file stays readable', () {
      final json = DayLog(
        date: CivilDate(2026, 8, 17),
        flow: FlowIntensity.medium,
        symptoms: const {Symptom.sleep: SymptomSeverity.moderate},
      ).toJson();
      expect(json['flow'], 'medium');
      expect(json['symptoms'], <String, String>{'sleep': 'moderate'});
    });

    test('round-trips across every flow and severity combination', () {
      for (final flow in FlowIntensity.values) {
        for (final severity in SymptomSeverity.values) {
          final log = DayLog(
            date: CivilDate(2026, 8, 17),
            flow: flow,
            symptoms: {Symptom.cramps: severity},
          );
          expect(DayLog.fromJson(log.toJson()), log, reason: '$flow/$severity');
        }
      }
    });
  });
}
