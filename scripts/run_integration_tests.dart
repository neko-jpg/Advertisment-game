#!/usr/bin/env dart

import 'dart:io';

/// Script to run comprehensive integration tests for production readiness
/// 
/// This script executes all integration tests including:
/// - Full system integration tests
/// - Performance tests (60FPS, memory optimization)
/// - Security and privacy tests
/// - System stability tests
Future<void> main(List<String> args) async {
  print('🚀 Starting comprehensive integration test suite...');
  print('📊 Verifying production readiness for Quick Draw Dash');
  
  final stopwatch = Stopwatch()..start();
  
  try {
    // Ensure we're in the correct directory
    final currentDir = Directory.current;
    if (!await File('pubspec.yaml').exists()) {
      print('❌ Error: Must run from project root directory');
      exit(1);
    }
    
    // Run Flutter tests with integration test configuration
    print('\n🔧 Running full system integration tests...');
    await _runTestSuite('test/integration/full_system_integration_test.dart');
    
    print('\n⚡ Running performance integration tests...');
    await _runTestSuite('test/performance/performance_integration_test.dart');
    
    print('\n🔒 Running security and privacy tests...');
    await _runTestSuite('test/security/security_privacy_test.dart');
    
    print('\n📋 Running comprehensive test runner...');
    await _runTestSuite('test/integration/test_runner.dart');
    
    stopwatch.stop();
    
    print('\n' + '=' * 80);
    print('🎉 INTEGRATION TEST SUITE COMPLETED SUCCESSFULLY');
    print('⏱️  Total execution time: ${stopwatch.elapsed.inMinutes}m ${stopwatch.elapsed.inSeconds % 60}s');
    print('✅ System is ready for production deployment');
    print('=' * 80);
    
  } catch (e, stackTrace) {
    stopwatch.stop();
    print('\n❌ Integration tests failed:');
    print('Error: $e');
    print('Stack trace: $stackTrace');
    print('\n🔧 Please fix the issues before proceeding to production');
    exit(1);
  }
}

Future<void> _runTestSuite(String testPath) async {
  print('  📝 Running: $testPath');
  
  final result = await Process.run(
    'flutter',
    ['test', testPath, '--reporter=expanded'],
    workingDirectory: Directory.current.path,
  );
  
  if (result.exitCode != 0) {
    print('❌ Test suite failed: $testPath');
    print('STDOUT: ${result.stdout}');
    print('STDERR: ${result.stderr}');
    throw Exception('Test suite failed: $testPath');
  }
  
  print('✅ Test suite passed: $testPath');
  
  // Print relevant output
  final output = result.stdout.toString();
  if (output.contains('FAILED') || output.contains('ERROR')) {
    print('⚠️  Warning: Test output contains failure indicators');
    print(output);
  }
}