import 'license_status.dart';
import 'license_rules.dart';

class LicenseEvaluator {
  static LicenseStatus evaluate({
    required DateTime expiresAt,
    required DateTime now,
  }) {
    if (now.isBefore(expiresAt)) {
      return LicenseStatus.active;
    }

    final graceLimit =
        expiresAt.add(const Duration(days: LicenseRules.graceDays));

    if (now.isBefore(graceLimit)) {
      return LicenseStatus.grace;
    }

    return LicenseStatus.expired;
  }
}
