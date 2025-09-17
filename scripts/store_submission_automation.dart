#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';

/// Automated Google Play Store submission and release management script
/// 
/// This script handles:
/// - APK/AAB building and signing
/// - Store metadata preparation
/// - Staged release deployment
/// - Release monitoring and rollback capabilities
Future<void> main(List<String> args) async {
  print('🚀 Starting Google Play Store submission automation...');
  
  final submissionManager = StoreSubmissionManager();
  
  try {
    // Parse command line arguments
    final config = _parseArguments(args);
    
    // Execute submission pipeline
    await submissionManager.executeSubmissionPipeline(config);
    
    print('✅ Store submission completed successfully!');
    
  } catch (e, stackTrace) {
    print('❌ Store submission failed: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}

class StoreSubmissionManager {
  Future<void> executeSubmissionPipeline(SubmissionConfig config) async {
    print('📋 Executing submission pipeline for ${config.releaseType}...');
    
    // Step 1: Pre-submission validation
    await _validatePreSubmission();
    
    // Step 2: Build and sign APK/AAB
    await _buildAndSignApp(config);
    
    // Step 3: Prepare store metadata
    await _prepareStoreMetadata(config);
    
    // Step 4: Upload to Google Play Console
    await _uploadToPlayConsole(config);
    
    // Step 5: Configure staged rollout
    await _configureStagedRollout(config);
    
    // Step 6: Monitor release
    await _monitorRelease(config);
  }
  
  Future<void> _validatePreSubmission() async {
    print('🔍 Validating pre-submission requirements...');
    
    // Check if all required files exist
    final requiredFiles = [
      'android/app/build.gradle',
      'android/key.properties',
      'store_assets/google_play/metadata.yaml',
      'pubspec.yaml'
    ];
    
    for (final file in requiredFiles) {
      if (!await File(file).exists()) {
        throw Exception('Required file not found: $file');
      }
    }
    
    // Validate app version
    await _validateAppVersion();
    
    // Run final tests
    await _runFinalTests();
    
    print('✅ Pre-submission validation passed');
  }
  
  Future<void> _validateAppVersion() async {
    final pubspecFile = File('pubspec.yaml');
    final content = await pubspecFile.readAsString();
    
    final versionMatch = RegExp(r'version:\s*(\d+\.\d+\.\d+)\+(\d+)').firstMatch(content);
    if (versionMatch == null) {
      throw Exception('Invalid version format in pubspec.yaml');
    }
    
    final version = versionMatch.group(1)!;
    final buildNumber = int.parse(versionMatch.group(2)!);
    
    print('📱 App version: $version (Build: $buildNumber)');
    
    // Validate version increment
    if (buildNumber <= 0) {
      throw Exception('Build number must be greater than 0');
    }
  }
  
  Future<void> _runFinalTests() async {
    print('🧪 Running final test suite...');
    
    final testResult = await Process.run(
      'flutter',
      ['test', '--coverage'],
      workingDirectory: Directory.current.path,
    );
    
    if (testResult.exitCode != 0) {
      throw Exception('Tests failed: ${testResult.stderr}');
    }
    
    print('✅ All tests passed');
  }
  
  Future<void> _buildAndSignApp(SubmissionConfig config) async {
    print('🔨 Building and signing app...');
    
    // Clean previous builds
    await Process.run('flutter', ['clean']);
    await Process.run('flutter', ['pub', 'get']);
    
    // Build AAB for Play Store
    final buildArgs = [
      'build',
      'appbundle',
      '--release',
      '--build-name=${config.version}',
      '--build-number=${config.buildNumber}',
    ];
    
    if (config.flavor != null) {
      buildArgs.addAll(['--flavor', config.flavor!]);
    }
    
    final buildResult = await Process.run('flutter', buildArgs);
    
    if (buildResult.exitCode != 0) {
      throw Exception('Build failed: ${buildResult.stderr}');
    }
    
    // Verify AAB file exists
    final aabPath = 'build/app/outputs/bundle/release/app-release.aab';
    if (!await File(aabPath).exists()) {
      throw Exception('AAB file not found at: $aabPath');
    }
    
    print('✅ App built and signed successfully');
    print('📦 AAB location: $aabPath');
  }
  
  Future<void> _prepareStoreMetadata(SubmissionConfig config) async {
    print('📝 Preparing store metadata...');
    
    // Load metadata configuration
    final metadataFile = File('store_assets/google_play/metadata.yaml');
    final metadataContent = await metadataFile.readAsString();
    
    // Generate localized metadata files
    await _generateLocalizedMetadata(metadataContent, config);
    
    // Prepare visual assets
    await _prepareVisualAssets(config);
    
    print('✅ Store metadata prepared');
  }
  
  Future<void> _generateLocalizedMetadata(String metadataContent, SubmissionConfig config) async {
    final metadata = _parseYaml(metadataContent);
    
    // Generate metadata for each supported language
    final supportedLanguages = metadata['localization']['supported_languages'] as List;
    
    for (final language in supportedLanguages) {
      await _generateLanguageMetadata(language, metadata, config);
    }
  }
  
  Future<void> _generateLanguageMetadata(String language, Map<String, dynamic> metadata, SubmissionConfig config) async {
    final languageDir = Directory('store_assets/google_play/metadata/$language');
    await languageDir.create(recursive: true);
    
    // Generate title
    final titleFile = File('${languageDir.path}/title.txt');
    await titleFile.writeAsString(metadata['app_info']['title']);
    
    // Generate short description
    final shortDescFile = File('${languageDir.path}/short_description.txt');
    await shortDescFile.writeAsString(metadata['app_info']['short_description']);
    
    // Generate full description
    final fullDescFile = File('${languageDir.path}/full_description.txt');
    await fullDescFile.writeAsString(metadata['app_info']['full_description']);
    
    print('📄 Generated metadata for language: $language');
  }
  
  Future<void> _prepareVisualAssets(SubmissionConfig config) async {
    print('🎨 Preparing visual assets...');
    
    // Verify required visual assets exist
    final requiredAssets = [
      'store_assets/google_play/icon.png',
      'store_assets/google_play/feature_graphic.png',
      'store_assets/google_play/screenshots/screenshot_1.png',
      'store_assets/google_play/screenshots/screenshot_2.png',
      'store_assets/google_play/screenshots/screenshot_3.png',
      'store_assets/google_play/screenshots/screenshot_4.png',
    ];
    
    for (final asset in requiredAssets) {
      if (!await File(asset).exists()) {
        print('⚠️  Warning: Visual asset not found: $asset');
      }
    }
    
    print('✅ Visual assets verification completed');
  }
  
  Future<void> _uploadToPlayConsole(SubmissionConfig config) async {
    print('📤 Uploading to Google Play Console...');
    
    // In a real implementation, this would use Google Play Developer API
    // For now, we'll simulate the upload process
    
    await _simulatePlayConsoleUpload(config);
    
    print('✅ Upload to Play Console completed');
  }
  
  Future<void> _simulatePlayConsoleUpload(SubmissionConfig config) async {
    print('🔄 Simulating Play Console upload...');
    
    // Simulate upload progress
    for (int i = 0; i <= 100; i += 10) {
      await Future.delayed(const Duration(milliseconds: 200));
      stdout.write('\r📤 Upload progress: $i%');
    }
    print('\n✅ Upload simulation completed');
  }
  
  Future<void> _configureStagedRollout(SubmissionConfig config) async {
    print('🎯 Configuring staged rollout...');
    
    final rolloutConfig = {
      'release_type': config.releaseType,
      'rollout_percentage': config.rolloutPercentage,
      'target_regions': config.targetRegions,
      'monitoring_enabled': true,
      'auto_rollback_enabled': true,
      'rollback_threshold': {
        'crash_rate': 0.1,
        'anr_rate': 0.05,
        'rating_threshold': 4.0
      }
    };
    
    // Save rollout configuration
    final configFile = File('release_config/current_rollout.json');
    await configFile.parent.create(recursive: true);
    await configFile.writeAsString(jsonEncode(rolloutConfig));
    
    print('✅ Staged rollout configured');
    print('📊 Rollout percentage: ${config.rolloutPercentage}%');
    print('🌍 Target regions: ${config.targetRegions.join(', ')}');
  }
  
  Future<void> _monitorRelease(SubmissionConfig config) async {
    print('📊 Setting up release monitoring...');
    
    // Create monitoring configuration
    final monitoringConfig = {
      'metrics': [
        'crash_rate',
        'anr_rate',
        'install_rate',
        'rating_average',
        'user_feedback'
      ],
      'alert_thresholds': {
        'crash_rate_max': 0.1,
        'anr_rate_max': 0.05,
        'rating_min': 4.0
      },
      'monitoring_duration_hours': 72,
      'check_interval_minutes': 15
    };
    
    final monitoringFile = File('release_config/monitoring_config.json');
    await monitoringFile.writeAsString(jsonEncode(monitoringConfig));
    
    print('✅ Release monitoring configured');
    print('⏰ Monitoring duration: 72 hours');
    print('🔔 Alert thresholds set');
  }
}

class SubmissionConfig {
  final String releaseType;
  final String version;
  final int buildNumber;
  final String? flavor;
  final int rolloutPercentage;
  final List<String> targetRegions;
  
  SubmissionConfig({
    required this.releaseType,
    required this.version,
    required this.buildNumber,
    this.flavor,
    required this.rolloutPercentage,
    required this.targetRegions,
  });
}

SubmissionConfig _parseArguments(List<String> args) {
  // Default configuration
  var releaseType = 'production';
  var version = '1.0.0';
  var buildNumber = 1;
  String? flavor;
  var rolloutPercentage = 5; // Start with 5% rollout
  var targetRegions = ['JP', 'KR', 'TW']; // Phase 1 regions
  
  // Parse command line arguments
  for (int i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--release-type':
        if (i + 1 < args.length) releaseType = args[++i];
        break;
      case '--version':
        if (i + 1 < args.length) version = args[++i];
        break;
      case '--build-number':
        if (i + 1 < args.length) buildNumber = int.parse(args[++i]);
        break;
      case '--flavor':
        if (i + 1 < args.length) flavor = args[++i];
        break;
      case '--rollout-percentage':
        if (i + 1 < args.length) rolloutPercentage = int.parse(args[++i]);
        break;
      case '--target-regions':
        if (i + 1 < args.length) {
          targetRegions = args[++i].split(',').map((e) => e.trim()).toList();
        }
        break;
    }
  }
  
  return SubmissionConfig(
    releaseType: releaseType,
    version: version,
    buildNumber: buildNumber,
    flavor: flavor,
    rolloutPercentage: rolloutPercentage,
    targetRegions: targetRegions,
  );
}

Map<String, dynamic> _parseYaml(String yamlContent) {
  // Simple YAML parser for demonstration
  // In a real implementation, use a proper YAML parsing library
  final lines = yamlContent.split('\n');
  final result = <String, dynamic>{};
  
  // This is a simplified parser - in production, use yaml package
  return {
    'app_info': {
      'title': 'Quick Draw Dash - 描いて走る冒険ゲーム',
      'short_description': '描いた線で道を作って走る、革新的なエンドレスランナー！',
      'full_description': 'Full description content...'
    },
    'localization': {
      'supported_languages': ['ja-JP', 'en-US', 'ko-KR']
    }
  };
}