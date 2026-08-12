import 'package:ads_core/ads_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FrequencyGuard', () {
    late DateTime clock;
    late FrequencyGuard guard;

    FrequencyGuard buildGuard({
      Duration coldStartGrace = const Duration(seconds: 30),
      Duration minInterval = const Duration(seconds: 60),
      int maxPerSession = 3,
      Set<String> disabledCountries = const {},
    }) {
      clock = DateTime(2026, 1, 1, 12, 0, 0);
      return FrequencyGuard(
        config: FrequencyGuardConfig(
          coldStartGrace: coldStartGrace,
          minInterval: minInterval,
          maxPerSession: maxPerSession,
          disabledCountries: disabledCountries,
        ),
        now: () => clock,
      );
    }

    setUp(() {
      guard = buildGuard();
    });

    test('blocks during cold start grace', () {
      final decision = guard.evaluate();
      expect(decision.allowed, isFalse);
      expect(decision.reason, FrequencyBlockReason.coldStart);
    });

    test('blocks one millisecond before grace elapses', () {
      clock = clock.add(
        const Duration(seconds: 30) - const Duration(milliseconds: 1),
      );
      expect(guard.evaluate().allowed, isFalse);
    });

    test('allows exactly at the cold start grace boundary', () {
      clock = clock.add(const Duration(seconds: 30));
      expect(guard.evaluate().allowed, isTrue);
    });

    test('blocks if shown more recently than min interval', () {
      clock = clock.add(const Duration(seconds: 30));
      expect(guard.evaluate().allowed, isTrue);
      guard.recordShown();

      clock = clock.add(const Duration(seconds: 59));
      final decision = guard.evaluate();
      expect(decision.allowed, isFalse);
      expect(decision.reason, FrequencyBlockReason.minInterval);
    });

    test('allows exactly at the min interval boundary', () {
      clock = clock.add(const Duration(seconds: 30));
      guard.recordShown();

      clock = clock.add(const Duration(seconds: 60));
      expect(guard.evaluate().allowed, isTrue);
    });

    test('blocks once session cap is reached', () {
      guard = buildGuard(coldStartGrace: Duration.zero, minInterval: Duration.zero, maxPerSession: 2);

      expect(guard.evaluate().allowed, isTrue);
      guard.recordShown();
      expect(guard.evaluate().allowed, isTrue);
      guard.recordShown();

      final decision = guard.evaluate();
      expect(decision.allowed, isFalse);
      expect(decision.reason, FrequencyBlockReason.sessionCap);
    });

    test('resetSession clears both the interval clock and the session count', () {
      guard = buildGuard(coldStartGrace: Duration.zero, minInterval: const Duration(seconds: 60), maxPerSession: 1);

      expect(guard.evaluate().allowed, isTrue);
      guard.recordShown();
      expect(guard.evaluate().allowed, isFalse);

      guard.resetSession();
      expect(guard.evaluate().allowed, isTrue);
    });

    test('blocks a disabled country regardless of other checks', () {
      guard = buildGuard(
        coldStartGrace: Duration.zero,
        minInterval: Duration.zero,
        disabledCountries: {'TR', 'DE'},
      );

      final decision = guard.evaluate(countryCode: 'tr');
      expect(decision.allowed, isFalse);
      expect(decision.reason, FrequencyBlockReason.disabledCountry);
    });

    test('allows a country not in the disabled list', () {
      guard = buildGuard(
        coldStartGrace: Duration.zero,
        minInterval: Duration.zero,
        disabledCountries: {'TR'},
      );

      expect(guard.evaluate(countryCode: 'US').allowed, isTrue);
    });

    test('allows when countryCode is null even with a non-empty disabled list', () {
      guard = buildGuard(
        coldStartGrace: Duration.zero,
        minInterval: Duration.zero,
        disabledCountries: {'TR'},
      );

      expect(guard.evaluate().allowed, isTrue);
    });

    test('evaluate never throws for any state', () {
      expect(() => guard.evaluate(countryCode: ''), returnsNormally);
      expect(() => guard.evaluate(countryCode: 'zz'), returnsNormally);
    });
  });
}
