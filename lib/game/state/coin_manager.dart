import 'package:flutter/material.dart';

/// コイン管理プロバイダー
class CoinProvider with ChangeNotifier {
  final List<Coin> _coins = [];
  int _totalCoins = 0;
  
  List<Coin> get coins => List.unmodifiable(_coins);
  int get totalCoins => _totalCoins;
  
  /// コインの更新
  void update(double deltaTime, double playerX) {
    // コインの位置更新
    for (final coin in _coins) {
      coin.x -= 5.0 * deltaTime / 16.67; // 60FPSベース
    }
    
    // 画面外のコインを削除
    _coins.removeWhere((coin) => coin.x < -50);
    
    notifyListeners();
  }
  
  /// コインの追加
  void addCoin(double x, double y) {
    _coins.add(Coin(x: x, y: y));
    notifyListeners();
  }
  
  /// コインの収集
  bool collectCoin(double playerX, double playerY, double playerWidth, double playerHeight) {
    for (int i = 0; i < _coins.length; i++) {
      final coin = _coins[i];
      if (_isColliding(playerX, playerY, playerWidth, playerHeight, coin)) {
        _coins.removeAt(i);
        _totalCoins++;
        notifyListeners();
        return true;
      }
    }
    return false;
  }
  
  bool _isColliding(double px, double py, double pw, double ph, Coin coin) {
    return px < coin.x + coin.width &&
           px + pw > coin.x &&
           py < coin.y + coin.height &&
           py + ph > coin.y;
  }
  
  /// リセット
  void reset() {
    _coins.clear();
    notifyListeners();
  }
  
  /// エフェクトのクリア
  void clearEffects() {
    // エフェクト関連のクリーンアップ
  }
  
  /// 遠くのコインをクリア
  void clearDistantCoins() {
    _coins.removeWhere((coin) => coin.x < -200);
    notifyListeners();
  }
}

/// コインクラス
class Coin {
  double x;
  double y;
  final double width;
  final double height;
  
  Coin({
    required this.x,
    required this.y,
    this.width = 20,
    this.height = 20,
  });
}