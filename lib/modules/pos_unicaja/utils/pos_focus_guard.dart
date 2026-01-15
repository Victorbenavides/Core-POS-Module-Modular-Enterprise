import 'package:flutter/foundation.dart';

class PosFocusGuard {
  static final ValueNotifier<bool> suspended = ValueNotifier<bool>(false);

  static Future<T> suspend<T>(Future<T> Function() fn) async {
    suspended.value = true;
    try {
      return await fn();
    } finally {
      suspended.value = false;
    }
  }
}
