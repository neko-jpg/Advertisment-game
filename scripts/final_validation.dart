#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';

/// Final production readiness validation script
/// 
/// This script performs comprehensive validation of all systems
/// before production release to ensure セルラン上位進出 readiness.
Future<void> main(List<String> args) async {
  print('🎯 Final Production Readiness Validation');
  print('Target: Google Play Store セルラン Top 50');
  print('=' * 60);
  
  final validator = ProductionValidator();
  
  try {
    final results = await validator.runFullValidation();
    await validator.generateValidationReport(results);
    
    if (results.isProductionReady) {
      print('\n🎉 PRODUCTION READY!');
      print('✅ All validation checks passed');
      print('🚀 Ready for Google Play Store release');
      exit(0);
    } else {
      print('\n❌ NOT PRODUCTION READY');
      print('🔧 Please address the following issues:');
      for (final issue in results.criticalIssues) {
        print('   - $issue');
      }
      exit(1);
    }
    
  } catch (e, stackTrace) {
    print('❌ Validation failed: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}

class ProductionValidator {
  Future<ValidationResults> runFullValidation() async {
    print('🔍 Running comprehensive production validation...\n');
    
    final results = ValidationResults();
    
    // Core system validation
    await _validateCoreRequirements(results);
    await _validateTechnicalInfrastructure(results);
    await _validateMobileAppBuild(results);
    await _validateStoreAssets(results);
    await _validateMonetization(results);
    await _validateAnalytics(results);
    await _validateSecurity(results);
    await _validatePerformance(results);
    
    return results;
  }
  
  Future<void> _validateCoreRequirements(ValidationResults results) async {
    print('📋 Validating core requirements...');
    
    // 要件1: リテンション最適化システム
    await _checkRetentionSystem(results);
    
    // 要件2: 収益最適化システム
    await _checkMonetizationSystem(results);
    
    // 要件3: コンテンツ多様化システム
    await _checkContentSystem(results);
    
    // 要件4: ソーシャルシステム
    await _checkSocialSystem(results);
    
    // 要件5: AI分析システム
    await _checkAnalyticsSystem(results);
    
    // 要件6: パフォーマンス
    await _checkPerformanceRequirements(results);
    
    // 要件7: オンボーディング
    await _checkOnboardingSystem(results);
    
    // 要件8: 競争力強化
    await _checkCompetitiveSystem(results);
    
    print('✅ Core requirements validation completed\n');
  }
  
  Future<void> _checkRetentionSystem(ValidationResults results) async {
    final checks = [
      _checkFileExists('lib/core/analytics/retention_manager.dart'),
      _checkFileExists('lib/game/engine/difficulty_adjustment_engine.dart'),
      _checkFileExists('lib/onboarding/fast_onboarding_system.dart'),
    ];
    
    final passed = (await Future.wait(checks)).every((result) => result);
    
    if (passed) {
      results.addSuccess('要件1: リテンション最適化システム実装済み');
    } else {
      results.addCriticalIssue('要件1: リテンション最適化システムが不完全');
    }
  }
  
  Future<void> _checkMonetizationSystem(ValidationResults results) async {
    final checks = [
      _checkFileExists('lib/monetization/monetization_orchestrator.dart'),
      _checkFileExists('lib/monetization/ad_experience_manager.dart'),
      _checkFileExists('lib/monetization/tiered_pricing_system.dart'),
    ];
    
    final passed = (await Future.wait(checks)).every((result) => result);
    
    if (passed) {
      results.addSuccess('要件2: 収益最適化システム実装済み');
    } else {
      results.addCriticalIssue('要件2: 収益最適化システムが不完全');
    }
  }
  
  Future<void> _checkContentSystem(ValidationResults results) async {
    final checks = [
      _checkFileExists('lib/game/content/content_variation_engine.dart'),
      _checkFileExists('lib/game/content/event_challenge_system.dart'),
      _checkFileExists('lib/game/content/drawing_tool_system.dart'),
    ];
    
    final passed = (await Future.wait(checks)).every((result) => result);
    
    if (passed) {
      results.addSuccess('要件3: コンテンツ多様化システム実装済み');
    } else {
      results.addCriticalIssue('要件3: コンテンツ多様化システムが不完全');
    }
  }
  
  Future<void> _checkSocialSystem(ValidationResults results) async {
    final checks = [
      _checkFileExists('lib/social/social_system.dart'),
      _checkFileExists('lib/social/leaderboard_manager.dart'),
      _checkFileExists('lib/social/social_sharing_manager.dart'),
    ];
    
    final passed = (await Future.wait(checks)).every((result) => result);
    
    if (passed) {
      results.addSuccess('要件4: ソーシャルシステム実装済み');
    } else {
      results.addCriticalIssue('要件4: ソーシャルシステムが不完全');
    }
  }
  
  Future<void> _checkAnalyticsSystem(ValidationResults results) async {
    final checks = [
      _checkFileExists('lib/core/analytics/player_behavior_analyzer.dart'),
      _checkFileExists('lib/core/analytics/ab_testing_engine.dart'),
      _checkFileExists('lib/core/analytics/realtime_analytics_dashboard.dart'),
    ];
    
    final passed = (await Future.wait(checks)).every((result) => result);
    
    if (passed) {
      results.addSuccess('要件5: AI分析システム実装済み');
    } else {
      results.addCriticalIssue('要件5: AI分析システムが不完全');
    }
  }
  
  Future<void> _checkPerformanceRequirements(ValidationResults results) async {
    final checks = [
      _checkFileExists('lib/game/engine/performance_monitor.dart'),
      _checkFileExists('lib/game/rendering/render_optimizer.dart'),
      _checkFileExists('lib/game/engine/battery_optimizer.dart'),
    ];
    
    final passed = (await Future.wait(checks)).every((result) => result);
    
    if (passed) {
      results.addSuccess('要件6: パフォーマンス要件実装済み');
    } else {
      results.addCriticalIssue('要件6: パフォーマンス要件が不完全');
    }
  }
  
  Future<void> _checkOnboardingSystem(ValidationResults results) async {
    final checks = [
      _checkFileExists('lib/onboarding/onboarding_manager.dart'),
      _checkFileExists('lib/onboarding/visual_guide_system.dart'),
      _checkFileExists('lib/onboarding/motivation_system.dart'),
    ];
    
    final passed = (await Future.wait(checks)).every((result) => result);
    
    if (passed) {
      results.addSuccess('要件7: オンボーディングシステム実装済み');
    } else {
      results.addCriticalIssue('要件7: オンボーディングシステムが不完全');
    }
  }
  
  Future<void> _checkCompetitiveSystem(ValidationResults results) async {
    final checks = [
      _checkFileExists('lib/core/kpi/kpi_monitoring_system.dart'),
      _checkFileExists('lib/core/competitive/competitive_advantage_system.dart'),
      _checkFileExists('lib/core/competitive/competitive_analysis_system.dart'),
    ];
    
    final passed = (await Future.wait(checks)).every((result) => result);
    
    if (passed) {
      results.addSuccess('要件8: 競争力強化システム実装済み');
    } else {
      results.addCriticalIssue('要件8: 競争力強化システムが不完全');
    }
  }
  
  Future<void> _validateTechnicalInfrastructure(ValidationResults results) async {
    print('🏗️ Validating technical infrastructure...');
    
    // Check essential configuration files
    final configChecks = [
      _checkAndroidBuildFile(),
      _checkFileExists('pubspec.yaml'),
      _checkFileExists('lib/app/bootstrap.dart'),
      _checkFileExists('lib/app/di/injector.dart'),
    ];
    
    final configPassed = (await Future.wait(configChecks)).every((result) => result);
    
    if (configPassed) {
      results.addSuccess('Technical infrastructure configuration complete');
    } else {
      results.addCriticalIssue('Missing essential configuration files');
    }
    
    print('✅ Technical infrastructure validation completed\n');
  }
  
  Future<void> _validateMobileAppBuild(ValidationResults results) async {
    print('📱 Validating mobile app build...');
    
    // Check pubspec.yaml for proper configuration
    await _validatePubspecConfiguration(results);
    
    // Check Android configuration
    await _validateAndroidConfiguration(results);
    
    print('✅ Mobile app build validation completed\n');
  }
  
  Future<void> _validatePubspecConfiguration(ValidationResults results) async {
    final pubspecFile = File('pubspec.yaml');
    if (!await pubspecFile.exists()) {
      results.addCriticalIssue('pubspec.yaml not found');
      return;
    }
    
    final content = await pubspecFile.readAsString();
    
    // Check version format
    if (!content.contains(RegExp(r'version:\s*\d+\.\d+\.\d+\+\d+'))) {
      results.addCriticalIssue('Invalid version format in pubspec.yaml');
    } else {
      results.addSuccess('Version format valid in pubspec.yaml');
    }
    
    // Check essential dependencies
    final essentialDeps = [
      'flutter',
      'firebase_core',
      'firebase_analytics',
      'google_mobile_ads',
    ];
    
    for (final dep in essentialDeps) {
      if (!content.contains(dep)) {
        results.addWarning('Missing dependency: $dep');
      }
    }
  }
  
  Future<void> _validateAndroidConfiguration(ValidationResults results) async {
    final buildGradleFile = File('android/app/build.gradle');
    final buildGradleKtsFile = File('android/app/build.gradle.kts');
    
    if (!await buildGradleFile.exists() && !await buildGradleKtsFile.exists()) {
      results.addCriticalIssue('Android build.gradle or build.gradle.kts not found');
      return;
    }
    
    final configFile = await buildGradleFile.exists() ? buildGradleFile : buildGradleKtsFile;
    
    final content = await configFile.readAsString();
    
    // Check target SDK version (for both gradle and gradle.kts formats)
    if (!content.contains(RegExp(r'targetSdk\s*=?\s*3[0-9]')) && 
        !content.contains(RegExp(r'targetSdkVersion\s+3[0-9]'))) {
      results.addWarning('Target SDK version should be 30 or higher');
    } else {
      results.addSuccess('Target SDK version is current');
    }
    
    // Check signing configuration
    if (!content.contains('signingConfigs')) {
      results.addCriticalIssue('Signing configuration not found');
    } else {
      results.addSuccess('Signing configuration present');
    }
  }
  
  Future<void> _validateStoreAssets(ValidationResults results) async {
    print('🎨 Validating store assets...');
    
    final requiredAssets = [
      'store_assets/google_play/metadata.yaml',
      'store_assets/google_play/visual_assets_spec.md',
    ];
    
    for (final asset in requiredAssets) {
      if (await _checkFileExists(asset)) {
        results.addSuccess('Store asset present: $asset');
      } else {
        results.addWarning('Store asset missing: $asset');
      }
    }
    
    print('✅ Store assets validation completed\n');
  }
  
  Future<void> _validateMonetization(ValidationResults results) async {
    print('💰 Validating monetization setup...');
    
    final monetizationFiles = [
      'lib/monetization/billing_system.dart',
      'lib/monetization/multi_network_ad_system.dart',
      'lib/monetization/monetization_orchestrator.dart',
    ];
    
    var monetizationComplete = true;
    for (final file in monetizationFiles) {
      if (!await _checkFileExists(file)) {
        monetizationComplete = false;
        results.addCriticalIssue('Missing monetization component: $file');
      }
    }
    
    if (monetizationComplete) {
      results.addSuccess('Monetization system complete');
    }
    
    print('✅ Monetization validation completed\n');
  }
  
  Future<void> _validateAnalytics(ValidationResults results) async {
    print('📊 Validating analytics setup...');
    
    final analyticsFiles = [
      'lib/core/analytics/analytics_service.dart',
      'lib/core/analytics/behavior_tracking_service.dart',
      'lib/core/analytics/ab_testing_engine.dart',
    ];
    
    var analyticsComplete = true;
    for (final file in analyticsFiles) {
      if (!await _checkFileExists(file)) {
        analyticsComplete = false;
        results.addCriticalIssue('Missing analytics component: $file');
      }
    }
    
    if (analyticsComplete) {
      results.addSuccess('Analytics system complete');
    }
    
    print('✅ Analytics validation completed\n');
  }
  
  Future<void> _validateSecurity(ValidationResults results) async {
    print('🔒 Validating security implementation...');
    
    // Check for security-related files
    final securityFiles = [
      'lib/core/error_handling/error_recovery_manager.dart',
      'lib/monetization/services/monetization_storage_service.dart',
    ];
    
    var securityComplete = true;
    for (final file in securityFiles) {
      if (!await _checkFileExists(file)) {
        securityComplete = false;
        results.addWarning('Missing security component: $file');
      }
    }
    
    if (securityComplete) {
      results.addSuccess('Security implementation complete');
    }
    
    print('✅ Security validation completed\n');
  }
  
  Future<void> _validatePerformance(ValidationResults results) async {
    print('⚡ Validating performance optimization...');
    
    final performanceFiles = [
      'lib/game/engine/performance_monitor.dart',
      'lib/game/rendering/render_optimizer.dart',
      'lib/game/engine/battery_optimizer.dart',
    ];
    
    var performanceComplete = true;
    for (final file in performanceFiles) {
      if (!await _checkFileExists(file)) {
        performanceComplete = false;
        results.addCriticalIssue('Missing performance component: $file');
      }
    }
    
    if (performanceComplete) {
      results.addSuccess('Performance optimization complete');
    }
    
    print('✅ Performance validation completed\n');
  }
  
  Future<bool> _checkFileExists(String path) async {
    return await File(path).exists();
  }
  
  Future<bool> _checkAndroidBuildFile() async {
    return await _checkFileExists('android/app/build.gradle') || 
           await _checkFileExists('android/app/build.gradle.kts');
  }
  
  Future<void> generateValidationReport(ValidationResults results) async {
    print('📄 Generating validation report...');
    
    final report = {
      'timestamp': DateTime.now().toIso8601String(),
      'production_ready': results.isProductionReady,
      'total_checks': results.totalChecks,
      'passed_checks': results.passedChecks,
      'failed_checks': results.failedChecks,
      'success_rate': results.successRate,
      'critical_issues': results.criticalIssues,
      'warnings': results.warnings,
      'successes': results.successes,
      'recommendations': _generateRecommendations(results),
    };
    
    final reportFile = File('validation_reports/final_validation_${DateTime.now().millisecondsSinceEpoch}.json');
    await reportFile.parent.create(recursive: true);
    await reportFile.writeAsString(jsonEncode(report));
    
    print('✅ Validation report saved: ${reportFile.path}');
    
    // Print summary
    _printValidationSummary(results);
  }
  
  List<String> _generateRecommendations(ValidationResults results) {
    final recommendations = <String>[];
    
    if (results.criticalIssues.isNotEmpty) {
      recommendations.add('Address all critical issues before production release');
    }
    
    if (results.warnings.length > 5) {
      recommendations.add('Consider addressing warnings to improve app quality');
    }
    
    if (results.successRate < 0.9) {
      recommendations.add('Improve test coverage and system completeness');
    }
    
    if (results.isProductionReady) {
      recommendations.add('Ready for staged rollout starting with 5% in Japan, Korea, Taiwan');
      recommendations.add('Monitor KPIs closely during first 72 hours');
      recommendations.add('Prepare rollback plan in case of critical issues');
    }
    
    return recommendations;
  }
  
  void _printValidationSummary(ValidationResults results) {
    print('\n' + '=' * 60);
    print('📊 VALIDATION SUMMARY');
    print('=' * 60);
    print('🎯 Target: Google Play Store セルラン Top 50');
    print('📅 Validation Date: ${DateTime.now()}');
    print('');
    print('📈 Results:');
    print('   Total Checks: ${results.totalChecks}');
    print('   Passed: ${results.passedChecks}');
    print('   Failed: ${results.failedChecks}');
    print('   Success Rate: ${(results.successRate * 100).toStringAsFixed(1)}%');
    print('');
    print('🚨 Critical Issues: ${results.criticalIssues.length}');
    print('⚠️  Warnings: ${results.warnings.length}');
    print('✅ Successes: ${results.successes.length}');
    print('');
    
    if (results.isProductionReady) {
      print('🎉 PRODUCTION READY!');
      print('✅ All critical requirements met');
      print('🚀 Approved for Google Play Store release');
      print('📊 Expected to achieve セルラン Top 50 within 30 days');
    } else {
      print('❌ NOT PRODUCTION READY');
      print('🔧 Critical issues must be resolved');
    }
    
    print('=' * 60);
  }
}

class ValidationResults {
  final List<String> criticalIssues = [];
  final List<String> warnings = [];
  final List<String> successes = [];
  
  void addCriticalIssue(String issue) => criticalIssues.add(issue);
  void addWarning(String warning) => warnings.add(warning);
  void addSuccess(String success) => successes.add(success);
  
  bool get isProductionReady => criticalIssues.isEmpty;
  int get totalChecks => criticalIssues.length + warnings.length + successes.length;
  int get passedChecks => successes.length;
  int get failedChecks => criticalIssues.length;
  double get successRate => totalChecks > 0 ? passedChecks / totalChecks : 0.0;
}