import 'package:flutter/material.dart';

/// プレミアムゲーム体験用のカラーパレット
class PremiumColors {
  // プライマリーカラー
  static const Color primary = Color(0xFF00D4FF);      // ネオンシアン
  static const Color secondary = Color(0xFF9D4EDD);    // ネオンパープル
  static const Color accent = Color(0xFFFF006E);       // ネオンピンク
  static const Color warning = Color(0xFFFFBE0B);      // ネオンイエロー
  static const Color success = Color(0xFF8338EC);      // ネオングリーン
  
  // 背景グラデーション
  static const List<Color> backgroundGradient = [
    Color(0xFF0F0F23), // ダークブルー
    Color(0xFF1A1A2E), // ミッドナイト
    Color(0xFF16213E), // ディープブルー
  ];
  
  // エフェクトカラー
  static const Color glowColor = Color(0xFF00D4FF);
  static const Color particleColor = Color(0xFF9D4EDD);
  static const Color trailColor = Color(0xFFFF006E);
  
  // UI要素
  static const Color surfaceLight = Color(0x1AFFFFFF);
  static const Color surfaceMedium = Color(0x33FFFFFF);
  static const Color surfaceDark = Color(0x0DFFFFFF);
  
  // テキストカラー
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF);
  static const Color textTertiary = Color(0x80FFFFFF);
  
  // ボーダーカラー
  static const Color borderLight = Color(0x40FFFFFF);
  static const Color borderMedium = Color(0x60FFFFFF);
  static const Color borderStrong = Color(0x80FFFFFF);
}

/// プレミアムテキストスタイル
class PremiumTextStyles {
  static const TextStyle title = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w900,
    letterSpacing: 2.0,
    color: PremiumColors.textPrimary,
    shadows: [
      Shadow(
        offset: Offset(0, 0),
        blurRadius: 20,
        color: PremiumColors.glowColor,
      ),
      Shadow(
        offset: Offset(0, 4),
        blurRadius: 8,
        color: Colors.black54,
      ),
    ],
  );
  
  static const TextStyle subtitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
    color: PremiumColors.textSecondary,
    shadows: [
      Shadow(
        offset: Offset(0, 2),
        blurRadius: 4,
        color: Colors.black38,
      ),
    ],
  );
  
  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    color: PremiumColors.textSecondary,
  );
  
  static const TextStyle button = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
    color: PremiumColors.textPrimary,
    shadows: [
      Shadow(
        offset: Offset(0, 1),
        blurRadius: 2,
        color: Colors.black26,
      ),
    ],
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.8,
    color: PremiumColors.textTertiary,
  );
  
  static const TextStyle score = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.5,
    color: PremiumColors.primary,
    shadows: [
      Shadow(
        offset: Offset(0, 0),
        blurRadius: 15,
        color: PremiumColors.primary,
      ),
      Shadow(
        offset: Offset(0, 2),
        blurRadius: 4,
        color: Colors.black54,
      ),
    ],
  );
}

/// プレミアムテーマデータ
class PremiumTheme {
  static ThemeData get theme {
    return ThemeData.dark().copyWith(
      primaryColor: PremiumColors.primary,
      colorScheme: const ColorScheme.dark(
        primary: PremiumColors.primary,
        secondary: PremiumColors.secondary,
        surface: Color(0xFF1A1A2E),
        background: Color(0xFF0F0F23),
        error: PremiumColors.accent,
      ),
      textTheme: const TextTheme(
        displayLarge: PremiumTextStyles.title,
        displayMedium: PremiumTextStyles.subtitle,
        bodyLarge: PremiumTextStyles.body,
        bodyMedium: PremiumTextStyles.body,
        labelLarge: PremiumTextStyles.button,
        bodySmall: PremiumTextStyles.caption,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: PremiumColors.textPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
  
  /// 動的背景グラデーション
  static BoxDecoration get backgroundDecoration {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: PremiumColors.backgroundGradient,
      ),
    );
  }
  
  /// アニメーション用の背景グラデーション
  static BoxDecoration getAnimatedBackgroundDecoration(double animationValue) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(PremiumColors.backgroundGradient[0], 
                    PremiumColors.backgroundGradient[1], animationValue * 0.3)!,
          Color.lerp(PremiumColors.backgroundGradient[1], 
                    PremiumColors.backgroundGradient[2], animationValue * 0.2)!,
          Color.lerp(PremiumColors.backgroundGradient[2], 
                    PremiumColors.backgroundGradient[0], animationValue * 0.1)!,
        ],
      ),
    );
  }
}

/// プレミアムエフェクト用の定数
class PremiumEffects {
  // アニメーション時間
  static const Duration fastAnimation = Duration(milliseconds: 150);
  static const Duration normalAnimation = Duration(milliseconds: 300);
  static const Duration slowAnimation = Duration(milliseconds: 500);
  static const Duration verySlowAnimation = Duration(milliseconds: 800);
  
  // ブラー値
  static const double lightBlur = 5.0;
  static const double normalBlur = 10.0;
  static const double heavyBlur = 20.0;
  
  // 透明度
  static const double lightOpacity = 0.05;
  static const double normalOpacity = 0.1;
  static const double heavyOpacity = 0.2;
  
  // グロー強度
  static const double lightGlow = 0.3;
  static const double normalGlow = 0.5;
  static const double heavyGlow = 0.8;
  
  // ボーダー幅
  static const double thinBorder = 0.5;
  static const double normalBorder = 1.0;
  static const double thickBorder = 2.0;
}