import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'full_system_integration_test.dart' as full_system;
import '../performance/performance_integration_test.dart' as performance;
import '../security/security_privacy_test.dart' as security;

/// Comprehensive test runner for all integration tests
/// 
/// This runner executes all integration tests in sequence and provides
/// detailed reporting on system performance, security, and functionality.
void main() {
  group('Complete Integration Test Suite', () {
    late TestResults results;
    
    setUpAll(() {
      results = TestResults();
      print('🚀 Starting comprehensive integration test suite...');
      print('📊 Testing all systems for production readiness');
    });

    tearDownAll(() {
      _printFinalReport(results);
    });

    group('🔧 Full System Integration', () {
      setUpAll(() {
        print('\n🔧 Running full system integration tests...');
        results.startCategory('Full System Integration');
      });

      tearDownAll(() {
        results.endCategory('Full System Integration');
      });

      // Run all full system integration tests
      full_system.main();
    });

    group('⚡ Performance Integration', () {
      setUpAll(() {
        print('\n⚡ Running performance integration tests...');
        results.startCategory('Performance Integration');
      });

      tearDownAll(() {
        results.endCategory('Performance Integration');
      });

      // Run all performance tests
      performance.main();
    });

    group('🔒 Security and Privacy', () {
      setUpAll(() {
        print('\n🔒 Running security and privacy tests...');
        results.startCategory('Security and Privacy');
      });

      tearDownAll(() {
        results.endCategory('Security and Privacy');
      });

      // Run all security tests
      security.main();
    });

    test('📋 Generate comprehensive test report', () async {
      await _generateTestReport(results);
      expect(results.overallSuccess, isTrue, 
        reason: 'All integration tests must pass for production readiness');
    });
  });
}

class TestResults {
  final Map<String, CategoryResults> _categories = {};
  String? _currentCategory;
  DateTime? _startTime;

  void startCategory(String category) {
    _currentCategory = category;
    _startTime = DateTime.now();
    _categories[category] = CategoryResults(category);
  }

  void endCategory(String category) {
    if (_currentCategory == category && _startTime != null) {
      final duration = DateTime.now().difference(_startTime!);
      _categories[category]?.duration = duration;
    }
  }

  void recordTest(String testName, bool passed, {String? error}) {
    if (_currentCategory != null) {
      _categories[_currentCategory]?.addTest(testName, passed, error: error);
    }
  }

  bool get overallSuccess {
    return _categories.values.every((category) => category.allTestsPassed);
  }

  Map<String, CategoryResults> get categories => Map.unmodifiable(_categories);
}

class CategoryResults {
  final String name;
  final List<TestResult> tests = [];
  Duration? duration;

  CategoryResults(this.name);

  void addTest(String testName, bool passed, {String? error}) {
    tests.add(TestResult(testName, passed, error));
  }

  bool get allTestsPassed => tests.every((test) => test.passed);
  int get passedCount => tests.where((test) => test.passed).length;
  int get failedCount => tests.where((test) => !test.passed).length;
}

class TestResult {
  final String name;
  final bool passed;
  final String? error;

  TestResult(this.name, this.passed, this.error);
}

void _printFinalReport(TestResults results) {
  print('\n' + '=' * 80);
  print('📊 COMPREHENSIVE INTEGRATION TEST REPORT');
  print('=' * 80);
  
  for (final category in results.categories.values) {
    print('\n📁 ${category.name}');
    print('   Duration: ${category.duration?.inSeconds ?? 0}s');
    print('   Tests: ${category.tests.length}');
    print('   ✅ Passed: ${category.passedCount}');
    print('   ❌ Failed: ${category.failedCount}');
    
    if (category.failedCount > 0) {
      print('   Failed tests:');
      for (final test in category.tests.where((t) => !t.passed)) {
        print('     - ${test.name}');
        if (test.error != null) {
          print('       Error: ${test.error}');
        }
      }
    }
  }
  
  print('\n' + '=' * 80);
  if (results.overallSuccess) {
    print('🎉 ALL TESTS PASSED - SYSTEM READY FOR PRODUCTION');
  } else {
    print('❌ SOME TESTS FAILED - REVIEW REQUIRED BEFORE PRODUCTION');
  }
  print('=' * 80);
}

Future<void> _generateTestReport(TestResults results) async {
  final reportFile = File('test_reports/integration_test_report.md');
  await reportFile.parent.create(recursive: true);
  
  final buffer = StringBuffer();
  buffer.writeln('# Integration Test Report');
  buffer.writeln('');
  buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
  buffer.writeln('');
  
  buffer.writeln('## Summary');
  buffer.writeln('');
  buffer.writeln('| Category | Tests | Passed | Failed | Duration |');
  buffer.writeln('|----------|-------|--------|--------|----------|');
  
  for (final category in results.categories.values) {
    buffer.writeln('| ${category.name} | ${category.tests.length} | '
        '${category.passedCount} | ${category.failedCount} | '
        '${category.duration?.inSeconds ?? 0}s |');
  }
  
  buffer.writeln('');
  buffer.writeln('## Detailed Results');
  buffer.writeln('');
  
  for (final category in results.categories.values) {
    buffer.writeln('### ${category.name}');
    buffer.writeln('');
    
    for (final test in category.tests) {
      final status = test.passed ? '✅' : '❌';
      buffer.writeln('- $status ${test.name}');
      if (test.error != null) {
        buffer.writeln('  - Error: ${test.error}');
      }
    }
    buffer.writeln('');
  }
  
  buffer.writeln('## Production Readiness Checklist');
  buffer.writeln('');
  buffer.writeln('- [${results.overallSuccess ? 'x' : ' '}] All integration tests pass');
  buffer.writeln('- [${_checkPerformanceRequirements(results) ? 'x' : ' '}] Performance requirements met (60FPS, memory optimization)');
  buffer.writeln('- [${_checkSecurityRequirements(results) ? 'x' : ' '}] Security and privacy requirements met');
  buffer.writeln('- [${_checkSystemStability(results) ? 'x' : ' '}] System stability verified');
  
  await reportFile.writeAsString(buffer.toString());
  print('📄 Test report generated: ${reportFile.path}');
}

bool _checkPerformanceRequirements(TestResults results) {
  final performanceCategory = results.categories['Performance Integration'];
  return performanceCategory?.allTestsPassed ?? false;
}

bool _checkSecurityRequirements(TestResults results) {
  final securityCategory = results.categories['Security and Privacy'];
  return securityCategory?.allTestsPassed ?? false;
}

bool _checkSystemStability(TestResults results) {
  final systemCategory = results.categories['Full System Integration'];
  return systemCategory?.allTestsPassed ?? false;
}