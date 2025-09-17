import 'package:flutter/foundation.dart';

import '../env.dart';

enum LogLevel { debug, info, warn, error }

class AppLogger {
  AppLogger({required AppEnvironment environment})
      : _environment = environment,
        _minLevel = environment.isTestBuild ? LogLevel.debug : LogLevel.info;

  final AppEnvironment _environment;
  final LogLevel _minLevel;

  void debug(String message) {
    _log(LogLevel.debug, message);
  }

  void info(String message) {
    _log(LogLevel.info, message);
  }

  void warn(String message, {Object? error}) {
    _log(LogLevel.warn, message, error: error);
  }

  void error(String message, {Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, error: error, stackTrace: stackTrace);
  }

  void _log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < _minLevel.index) {
      return;
    }

    final buffer = StringBuffer('[${_environment.name}] ${level.name.toUpperCase()}: $message');
    if (error != null) {
      buffer.write(' | error: $error');
    }
    debugPrint(buffer.toString());
    if (stackTrace != null && level.index >= LogLevel.warn.index) {
      debugPrint(stackTrace.toString());
    }
  }
}
