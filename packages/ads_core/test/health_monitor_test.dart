import 'package:ads_core/ads_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HealthMonitor', () {
    test('reports unhealthy only once the threshold is reached', () {
      final monitor = HealthMonitor(failureThreshold: 3);

      expect(monitor.recordFailure('levelplay'), isFalse);
      expect(monitor.recordFailure('levelplay'), isFalse);
      expect(monitor.recordFailure('levelplay'), isTrue);
    });

    test('a success resets the consecutive-failure streak', () {
      final monitor = HealthMonitor(failureThreshold: 3);

      expect(monitor.recordFailure('max'), isFalse);
      expect(monitor.recordFailure('max'), isFalse);
      monitor.recordSuccess('max');

      expect(monitor.failureCountFor('max'), 0);
      expect(monitor.recordFailure('max'), isFalse);
    });

    test('tracks each provider key independently', () {
      final monitor = HealthMonitor(failureThreshold: 2);

      expect(monitor.recordFailure('levelplay'), isFalse);
      expect(monitor.recordFailure('max'), isFalse);
      expect(monitor.recordFailure('max'), isTrue);

      expect(monitor.failureCountFor('levelplay'), 1);
      expect(monitor.failureCountFor('max'), 2);
    });

    test('failureCountFor is zero for a never-seen provider', () {
      final monitor = HealthMonitor(failureThreshold: 3);
      expect(monitor.failureCountFor('unknown'), 0);
    });

    test('reset clears a single provider without touching others', () {
      final monitor = HealthMonitor(failureThreshold: 2);
      monitor.recordFailure('levelplay');
      monitor.recordFailure('max');

      monitor.reset('levelplay');

      expect(monitor.failureCountFor('levelplay'), 0);
      expect(monitor.failureCountFor('max'), 1);
    });

    test('resetAll clears every provider', () {
      final monitor = HealthMonitor(failureThreshold: 2);
      monitor.recordFailure('levelplay');
      monitor.recordFailure('max');

      monitor.resetAll();

      expect(monitor.failureCountFor('levelplay'), 0);
      expect(monitor.failureCountFor('max'), 0);
    });

    test('threshold of 1 trips on the very first failure', () {
      final monitor = HealthMonitor(failureThreshold: 1);
      expect(monitor.recordFailure('levelplay'), isTrue);
    });
  });
}
