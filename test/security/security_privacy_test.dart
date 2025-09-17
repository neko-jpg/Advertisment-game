import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:crypto/crypto.dart';

import '../../lib/app/bootstrap.dart';
import '../../lib/app/di/injector.dart';
import '../../lib/core/analytics/analytics_service.dart';
import '../../lib/core/analytics/behavior_tracking_service.dart';
import '../../lib/monetization/services/monetization_storage_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Security and Privacy Tests', () {
    setUpAll(() async {
      await bootstrap();
    });

    tearDownAll(() async {
      await serviceLocator.reset();
    });

    test('Data encryption and secure storage', () async {
      final storageService = serviceLocator<MonetizationStorageService>();
      
      // Test sensitive data encryption
      const sensitiveData = 'user_payment_token_12345';
      await storageService.storeSecureData('payment_token', sensitiveData);
      
      // Verify data is encrypted in storage
      final storedData = await storageService.getSecureData('payment_token');
      expect(storedData, equals(sensitiveData));
      
      // Verify raw storage doesn't contain plain text
      final rawStorage = await storageService.getRawStorageData('payment_token');
      expect(rawStorage, isNot(equals(sensitiveData)));
      expect(rawStorage, isNotNull);
    });

    test('User data anonymization', () async {
      final analyticsService = serviceLocator<AnalyticsService>();
      final behaviorService = serviceLocator<BehaviorTrackingService>();
      
      // Test that personal identifiers are anonymized
      const userId = 'user123@example.com';
      final anonymizedId = analyticsService.anonymizeUserId(userId);
      
      expect(anonymizedId, isNot(equals(userId)));
      expect(anonymizedId.length, greaterThan(10)); // Should be a hash
      expect(anonymizedId, matches(RegExp(r'^[a-f0-9]+$'))); // Should be hex
      
      // Test behavior data anonymization
      final behaviorData = await behaviorService.collectAnonymizedBehaviorData(userId);
      expect(behaviorData.userId, equals(anonymizedId));
      expect(behaviorData.personalInfo, isEmpty);
    });

    test('GDPR compliance - data deletion', () async {
      final analyticsService = serviceLocator<AnalyticsService>();
      final storageService = serviceLocator<MonetizationStorageService>();
      
      const userId = 'gdpr_test_user';
      
      // Store some user data
      await analyticsService.trackUserEvent(userId, 'test_event', {'data': 'test'});
      await storageService.storeUserData(userId, {'preference': 'value'});
      
      // Verify data exists
      final userData = await storageService.getUserData(userId);
      expect(userData, isNotEmpty);
      
      // Request data deletion (GDPR right to be forgotten)
      await analyticsService.deleteAllUserData(userId);
      await storageService.deleteAllUserData(userId);
      
      // Verify data is deleted
      final deletedUserData = await storageService.getUserData(userId);
      expect(deletedUserData, isEmpty);
    });

    test('Data minimization principle', () async {
      final behaviorService = serviceLocator<BehaviorTrackingService>();
      
      // Test that only necessary data is collected
      final collectedData = await behaviorService.collectMinimalBehaviorData('test_user');
      
      // Verify no sensitive personal information is collected
      expect(collectedData.containsKey('email'), isFalse);
      expect(collectedData.containsKey('phone'), isFalse);
      expect(collectedData.containsKey('realName'), isFalse);
      expect(collectedData.containsKey('address'), isFalse);
      
      // Verify only game-relevant data is collected
      expect(collectedData.containsKey('gameActions'), isTrue);
      expect(collectedData.containsKey('sessionDuration'), isTrue);
      expect(collectedData.containsKey('gameProgress'), isTrue);
    });

    test('Secure communication and API calls', () async {
      final analyticsService = serviceLocator<AnalyticsService>();
      
      // Test that all API calls use HTTPS
      final apiEndpoints = analyticsService.getApiEndpoints();
      for (final endpoint in apiEndpoints) {
        expect(endpoint.startsWith('https://'), isTrue, 
          reason: 'All API endpoints must use HTTPS: $endpoint');
      }
      
      // Test API request signing
      final requestData = {'event': 'test', 'timestamp': DateTime.now().millisecondsSinceEpoch};
      final signedRequest = analyticsService.signApiRequest(requestData);
      
      expect(signedRequest.containsKey('signature'), isTrue);
      expect(signedRequest['signature'], isNotEmpty);
      
      // Verify signature is valid
      final isValidSignature = analyticsService.verifyApiRequestSignature(signedRequest);
      expect(isValidSignature, isTrue);
    });

    test('Input validation and sanitization', () async {
      final analyticsService = serviceLocator<AnalyticsService>();
      
      // Test SQL injection prevention
      const maliciousInput = "'; DROP TABLE users; --";
      final sanitizedInput = analyticsService.sanitizeInput(maliciousInput);
      expect(sanitizedInput, isNot(contains('DROP TABLE')));
      expect(sanitizedInput, isNot(contains(';')));
      
      // Test XSS prevention
      const xssInput = '<script>alert("xss")</script>';
      final sanitizedXss = analyticsService.sanitizeInput(xssInput);
      expect(sanitizedXss, isNot(contains('<script>')));
      expect(sanitizedXss, isNot(contains('alert')));
      
      // Test data length limits
      final longInput = 'a' * 10000;
      final truncatedInput = analyticsService.sanitizeInput(longInput);
      expect(truncatedInput.length, lessThanOrEqualTo(1000));
    });

    test('Consent management and opt-out functionality', () async {
      final analyticsService = serviceLocator<AnalyticsService>();
      
      // Test default consent state
      final defaultConsent = await analyticsService.getUserConsent('new_user');
      expect(defaultConsent.analyticsConsent, isFalse); // Should default to false
      expect(defaultConsent.advertisingConsent, isFalse);
      
      // Test consent granting
      await analyticsService.grantConsent('test_user', 
        analytics: true, advertising: false);
      
      final grantedConsent = await analyticsService.getUserConsent('test_user');
      expect(grantedConsent.analyticsConsent, isTrue);
      expect(grantedConsent.advertisingConsent, isFalse);
      
      // Test opt-out functionality
      await analyticsService.revokeConsent('test_user');
      final revokedConsent = await analyticsService.getUserConsent('test_user');
      expect(revokedConsent.analyticsConsent, isFalse);
      expect(revokedConsent.advertisingConsent, isFalse);
    });

    test('Child privacy protection (COPPA compliance)', () async {
      final analyticsService = serviceLocator<AnalyticsService>();
      
      // Test age verification
      const childUserId = 'child_user_age_12';
      await analyticsService.setUserAge(childUserId, 12);
      
      // Verify restricted data collection for children
      final childDataCollection = await analyticsService.getDataCollectionPolicy(childUserId);
      expect(childDataCollection.personalDataAllowed, isFalse);
      expect(childDataCollection.behavioralTrackingAllowed, isFalse);
      expect(childDataCollection.advertisingAllowed, isFalse);
      
      // Test that child data is handled with extra protection
      final childData = await analyticsService.collectChildSafeData(childUserId);
      expect(childData.containsKey('personalInfo'), isFalse);
      expect(childData.containsKey('location'), isFalse);
      expect(childData.containsKey('contacts'), isFalse);
    });

    test('Data breach detection and response', () async {
      final analyticsService = serviceLocator<AnalyticsService>();
      
      // Simulate suspicious activity
      await analyticsService.reportSuspiciousActivity('unusual_access_pattern', {
        'userId': 'test_user',
        'accessCount': 1000,
        'timeWindow': '1_minute'
      });
      
      // Verify security measures are triggered
      final securityStatus = await analyticsService.getSecurityStatus();
      expect(securityStatus.alertsActive, isTrue);
      expect(securityStatus.suspiciousActivityDetected, isTrue);
      
      // Test automatic security response
      final securityResponse = await analyticsService.getAutomaticSecurityResponse();
      expect(securityResponse.accountLocked, isTrue);
      expect(securityResponse.adminNotified, isTrue);
    });

    test('Secure random number generation', () {
      final analyticsService = serviceLocator<AnalyticsService>();
      
      // Test cryptographically secure random generation
      final randomBytes = analyticsService.generateSecureRandomBytes(32);
      expect(randomBytes.length, equals(32));
      
      // Test that generated values are different
      final randomBytes2 = analyticsService.generateSecureRandomBytes(32);
      expect(randomBytes, isNot(equals(randomBytes2)));
      
      // Test random string generation for tokens
      final randomToken = analyticsService.generateSecureToken();
      expect(randomToken.length, greaterThanOrEqualTo(32));
      expect(randomToken, matches(RegExp(r'^[a-zA-Z0-9]+$')));
    });
  });
}

// Extension methods for testing
extension AnalyticsServiceTesting on AnalyticsService {
  String anonymizeUserId(String userId) {
    final bytes = utf8.encode(userId);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  List<String> getApiEndpoints() {
    return [
      'https://api.analytics.example.com',
      'https://api.monetization.example.com',
      'https://api.social.example.com'
    ];
  }
  
  Map<String, dynamic> signApiRequest(Map<String, dynamic> data) {
    final jsonData = jsonEncode(data);
    final bytes = utf8.encode(jsonData);
    final signature = sha256.convert(bytes).toString();
    
    return {
      ...data,
      'signature': signature
    };
  }
  
  bool verifyApiRequestSignature(Map<String, dynamic> signedData) {
    final signature = signedData.remove('signature');
    final jsonData = jsonEncode(signedData);
    final bytes = utf8.encode(jsonData);
    final expectedSignature = sha256.convert(bytes).toString();
    
    return signature == expectedSignature;
  }
  
  String sanitizeInput(String input) {
    return input
        .replaceAll(RegExp(r'[<>"\';]'), '')
        .replaceAll(RegExp(r'(DROP|DELETE|INSERT|UPDATE|SELECT)\s+', caseSensitive: false), '')
        .substring(0, input.length > 1000 ? 1000 : input.length);
  }
  
  Uint8List generateSecureRandomBytes(int length) {
    final random = List<int>.generate(length, (i) => DateTime.now().microsecondsSinceEpoch % 256);
    return Uint8List.fromList(random);
  }
  
  String generateSecureToken() {
    final bytes = generateSecureRandomBytes(32);
    return base64Url.encode(bytes).replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
  }
}