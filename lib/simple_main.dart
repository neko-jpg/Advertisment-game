import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const QuickDrawDashGame());
}

class QuickDrawDashGame extends StatelessWidget {
  const QuickDrawDashGame({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quick Draw Dash - 描いて走る冒険ゲーム',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const GameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // ゲーム状態
  GameState _gameState = GameState.menu;
  int _score = 0;
  int _highScore = 0;
  int _coins = 0;
  int _gems = 0;
  int _lives = 3;
  double _speed = 2.0;
  int _consecutiveFailures = 0;
  int _combo = 0;
  double _scoreMultiplier = 1.0;
  int _meters = 0;
  GameMode _currentMode = GameMode.endless;
  int _level = 1;
  int _xp = 0;
  int _xpToNextLevel = 100;
  
  // プレイヤー
  late AnimationController _playerController;
  late Animation<double> _playerAnimation;
  Offset _playerPosition = const Offset(100, 300);
  bool _isPlayerOnLine = false;
  bool _isJumping = false;
  PlayerSkin _currentSkin = PlayerSkin.defaultSkin;
  bool _hasShield = false;
  bool _hasMagnet = false;
  Timer? _powerUpTimer;
  
  // プレイヤーアップグレード
  final Map<PlayerUpgrade, int> _playerUpgrades = {
    PlayerUpgrade.speed: 0,
    PlayerUpgrade.jump: 0,
    PlayerUpgrade.shield: 0,
    PlayerUpgrade.magnet: 0,
  };
  
  // スキルシステム
  final Map<ActiveSkill, bool> _unlockedSkills = {
    ActiveSkill.doubleJump: false,
    ActiveSkill.timeSlow: false,
    ActiveSkill.shockwave: false,
  };
  bool _isDoubleJumpAvailable = true;
  bool _isTimeSlowActive = false;
  Timer? _skillTimer;
  int _skillCooldown = 0;
  ActiveSkill _selectedSkill = ActiveSkill.doubleJump;
  
  // 描画システム
  final List<DrawnLine> _drawnLines = [];
  final List<Offset> _currentLine = [];
  bool _isDrawing = false;
  LineType _currentLineType = LineType.normal;
  
  // ゲーム要素
  final List<Obstacle> _obstacles = [];
  final List<Enemy> _enemies = [];
  Boss? _currentBoss;
  final List<Coin> _gameCoins = [];
  final List<PowerUp> _powerUps = [];
  final List<Particle> _particles = [];
  
  // アニメーション
  late AnimationController _gameController;
  late AnimationController _backgroundController;
  late Animation<double> _backgroundAnimation;
  late AnimationController _shakeController;
  late AnimationController _bossIntroController;
  
  // テーマシステム
  GameTheme _currentTheme = GameTheme.neon;
  
  // 難易度調整
  double _difficultyMultiplier = 1.0;
  int _obstacleSpawnRate = 2000;
  int _enemySpawnRate = 3000;
  int _bossSpawnInterval = 60000; // 60秒ごとにボス
  int _lastSpawnTime = 0;
  int _lastBossSpawnTime = 0;
  
  // タイマー
  Timer? _gameTimer;
  Timer? _spawnTimer;
  Timer? _comboTimer;
  Timer? _skillCooldownTimer;
  Timer? _bossAttackTimer;
  
  // プログレッション
  int _totalGamesPlayed = 0;
  int _totalCoinsCollected = 0;
  int _totalMetersRun = 0;
  final Map<AchievementType, bool> _achievements = {};
  
  // デイリークエスト
  final Map<DailyQuest, int> _dailyQuests = {
    DailyQuest.collectCoins: 0,
    DailyQuest.runMeters: 0,
    DailyQuest.avoidObstacles: 0,
    DailyQuest.defeatEnemies: 0,
  };
  DateTime? _lastPlayDate;
  
  // チャレンジモード
  int _currentChallenge = 0;
  final List<Challenge> _challenges = [
    Challenge(
      id: 1,
      name: 'スピードラン',
      description: '30秒間でできるだけ遠くへ進もう',
      duration: 30000,
      goalType: ChallengeGoalType.distance,
      reward: 100,
    ),
    Challenge(
      id: 2,
      name: 'コインコレクター',
      description: '50コインを集めよう',
      duration: 45000,
      goalType: ChallengeGoalType.coins,
      reward: 150,
    ),
    Challenge(
      id: 3,
      name: '障害物マスター',
      description: '20個の障害物を避けよう',
      duration: 40000,
      goalType: ChallengeGoalType.avoidObstacles,
      reward: 120,
    ),
  ];
  int _challengeTimeLeft = 0;
  int _challengeGoal = 0;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeGame();
    _loadGameData();
  }
  
  void _initializeAnimations() {
    _playerController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _playerAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _playerController, curve: Curves.easeInOut),
    );
    
    _gameController = AnimationController(
      duration: const Duration(milliseconds: 16),
      vsync: this,
    );
    
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
    _backgroundAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _backgroundController, curve: Curves.linear),
    );
    
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _bossIntroController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
  }
  
  void _initializeGame() {
    _gameState = GameState.menu;
    _score = 0;
    _lives = 3;
    _speed = 2.0 + (_playerUpgrades[PlayerUpgrade.speed]! * 0.2);
    _consecutiveFailures = 0;
    _combo = 0;
    _scoreMultiplier = 1.0;
    _meters = 0;
    _playerPosition = const Offset(100, 300);
    _drawnLines.clear();
    _obstacles.clear();
    _enemies.clear();
    _currentBoss = null;
    _gameCoins.clear();
    _powerUps.clear();
    _particles.clear();
    _hasShield = false;
    _hasMagnet = false;
    _currentLineType = LineType.normal;
    _isDoubleJumpAvailable = true;
    _isTimeSlowActive = false;
    _powerUpTimer?.cancel();
    _comboTimer?.cancel();
    _skillTimer?.cancel();
    _skillCooldownTimer?.cancel();
    _bossAttackTimer?.cancel();
    _bossIntroController.reset();
  }
  
  Future<void> _loadGameData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _highScore = prefs.getInt('highScore') ?? 0;
      _coins = prefs.getInt('coins') ?? 0;
      _gems = prefs.getInt('gems') ?? 0;
      _totalGamesPlayed = prefs.getInt('totalGamesPlayed') ?? 0;
      _totalCoinsCollected = prefs.getInt('totalCoinsCollected') ?? 0;
      _totalMetersRun = prefs.getInt('totalMetersRun') ?? 0;
      _level = prefs.getInt('level') ?? 1;
      _xp = prefs.getInt('xp') ?? 0;
      _xpToNextLevel = prefs.getInt('xpToNextLevel') ?? 100;
      
      // プレイヤーアップグレードの読み込み
      for (var upgrade in PlayerUpgrade.values) {
        _playerUpgrades[upgrade] = prefs.getInt('upgrade_${upgrade.name}') ?? 0;
      }
      
      // スキルの読み込み
      for (var skill in ActiveSkill.values) {
        _unlockedSkills[skill] = prefs.getBool('skill_${skill.name}') ?? false;
      }
      
      // アチーブメントの読み込み
      for (var type in AchievementType.values) {
        _achievements[type] = prefs.getBool('achievement_${type.name}') ?? false;
      }
      
      // デイリークエストの読み込み
      final lastPlayDate = prefs.getString('lastPlayDate');
      if (lastPlayDate != null) {
        _lastPlayDate = DateTime.parse(lastPlayDate);
        final now = DateTime.now();
        if (_lastPlayDate!.year != now.year || 
            _lastPlayDate!.month != now.month || 
            _lastPlayDate!.day != now.day) {
          // 日付が変わったらデイリークエストをリセット
          _resetDailyQuests();
        } else {
          for (var quest in DailyQuest.values) {
            _dailyQuests[quest] = prefs.getInt('dailyQuest_${quest.name}') ?? 0;
          }
        }
      }
      
      // スキンの読み込み
      final skinIndex = prefs.getInt('currentSkin') ?? 0;
      _currentSkin = PlayerSkin.values[skinIndex.clamp(0, PlayerSkin.values.length - 1)];
      
      // 選択されたスキルの読み込み
      final skillIndex = prefs.getInt('selectedSkill') ?? 0;
      _selectedSkill = ActiveSkill.values[skillIndex.clamp(0, ActiveSkill.values.length - 1)];
    });
  }
  
  Future<void> _saveGameData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('highScore', _highScore);
    await prefs.setInt('coins', _coins);
    await prefs.setInt('gems', _gems);
    await prefs.setInt('totalGamesPlayed', _totalGamesPlayed);
    await prefs.setInt('totalCoinsCollected', _totalCoinsCollected);
    await prefs.setInt('totalMetersRun', _totalMetersRun);
    await prefs.setInt('level', _level);
    await prefs.setInt('xp', _xp);
    await prefs.setInt('xpToNextLevel', _xpToNextLevel);
    await prefs.setString('lastPlayDate', DateTime.now().toString());
    
    // プレイヤーアップグレードの保存
    for (var entry in _playerUpgrades.entries) {
      await prefs.setInt('upgrade_${entry.key.name}', entry.value);
    }
    
    // スキルの保存
    for (var entry in _unlockedSkills.entries) {
      await prefs.setBool('skill_${entry.key.name}', entry.value);
    }
    
    // アチーブメントの保存
    for (var entry in _achievements.entries) {
      await prefs.setBool('achievement_${entry.key.name}', entry.value);
    }
    
    // デイリークエストの保存
    for (var entry in _dailyQuests.entries) {
      await prefs.setInt('dailyQuest_${entry.key.name}', entry.value);
    }
    
    // スキンの保存
    await prefs.setInt('currentSkin', _currentSkin.index);
    
    // 選択されたスキルの保存
    await prefs.setInt('selectedSkill', _selectedSkill.index);
  }
  
  void _resetDailyQuests() {
    setState(() {
      _dailyQuests[DailyQuest.collectCoins] = 0;
      _dailyQuests[DailyQuest.runMeters] = 0;
      _dailyQuests[DailyQuest.avoidObstacles] = 0;
      _dailyQuests[DailyQuest.defeatEnemies] = 0;
    });
  }
  
  void _checkAchievements() {
    // ハイスコア達成
    if (_score > _highScore && !_achievements[AchievementType.highScore]!) {
      setState(() {
        _achievements[AchievementType.highScore] = true;
        _gems += 10; // 報酬
      });
      _showAchievementPopup(AchievementType.highScore);
    }
    
    // コインコレクター
    if (_totalCoinsCollected >= 1000 && !_achievements[AchievementType.coinCollector]!) {
      setState(() {
        _achievements[AchievementType.coinCollector] = true;
        _gems += 5;
      });
      _showAchievementPopup(AchievementType.coinCollector);
    }
    
    // 走行距離
    if (_totalMetersRun >= 5000 && !_achievements[AchievementType.marathonRunner]!) {
      setState(() {
        _achievements[AchievementType.marathonRunner] = true;
        _gems += 8;
      });
      _showAchievementPopup(AchievementType.marathonRunner);
    }
    
    // 敵撃破
    if (_totalMetersRun >= 10000 && !_achievements[AchievementType.enemyDestroyer]!) {
      setState(() {
        _achievements[AchievementType.enemyDestroyer] = true;
        _gems += 12;
      });
      _showAchievementPopup(AchievementType.enemyDestroyer);
    }
    
    // ボスクラッシャー
    if (_totalMetersRun >= 20000 && !_achievements[AchievementType.bossCrusher]!) {
      setState(() {
        _achievements[AchievementType.bossCrusher] = true;
        _gems += 20;
      });
      _showAchievementPopup(AchievementType.bossCrusher);
    }
  }
  
  void _showAchievementPopup(AchievementType type) {
    // アチーブメント獲得ポップアップを表示
    // 実装はUI部分で行う
  }
  
  void _startGame() {
    setState(() {
      _gameState = GameState.playing;
      _initializeGame();
      _totalGamesPlayed++;
      
      // チャレンジモードの設定
      if (_currentMode == GameMode.challenge && _currentChallenge > 0) {
        final challenge = _challenges.firstWhere((c) => c.id == _currentChallenge);
        _challengeTimeLeft = challenge.duration;
        _challengeGoal = 0;
      }
    });
    
    _backgroundController.repeat();
    
    // ゲームループ開始
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _updateGame();
    });
    
    // 要素スポーンタイマー
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _lastSpawnTime += 100;
      _spawnGameElements();
    });
    
    // チャレンジモードのタイマー
    if (_currentMode == GameMode.challenge) {
      _challengeTimeLeft = _challenges.firstWhere((c) => c.id == _currentChallenge).duration;
    }
    
    // ハプティックフィードバック
    HapticFeedback.lightImpact();
  }
  
  void _updateGame() {
    if (_gameState != GameState.playing) return;
    
    setState(() {
      // チャレンジモードの時間更新
      if (_currentMode == GameMode.challenge) {
        _challengeTimeLeft -= 16;
        if (_challengeTimeLeft <= 0) {
          _completeChallenge();
          return;
        }
      }
      
      // プレイヤー更新
      _updatePlayer();
      
      // 障害物更新
      _updateObstacles();
      
      // 敵更新
      _updateEnemies();
      
      // ボス更新
      _updateBoss();
      
      // コイン更新
      _updateCoins();
      
      // パワーアップ更新
      _updatePowerUps();
      
      // パーティクル更新
      _updateParticles();
      
      // 衝突判定
      _checkCollisions();
      
      // スコア更新
      _score += (1 * _difficultyMultiplier * _scoreMultiplier).round();
      _meters += (1 * _difficultyMultiplier).round();
      _totalMetersRun += (1 * _difficultyMultiplier).round();
      _dailyQuests[DailyQuest.runMeters] = _dailyQuests[DailyQuest.runMeters]! + 1;
      
      // 速度増加
      _speed += 0.001;
      
      // 難易度調整
      if (_score % 1000 == 0) {
        _difficultyMultiplier += 0.1;
        _obstacleSpawnRate = (2000 / _difficultyMultiplier).round().clamp(500, 2000);
        _enemySpawnRate = (3000 / _difficultyMultiplier).round().clamp(1000, 3000);
      }
      
      // ボス出現チェック
      if (_currentBoss == null && _lastSpawnTime - _lastBossSpawnTime > _bossSpawnInterval) {
        _spawnBoss();
      }
    });
  }
  
  void _updatePlayer() {
    // 重力適用
    if (!_isPlayerOnLine && !_isJumping) {
      _playerPosition = Offset(
        _playerPosition.dx,
        _playerPosition.dy + 3,
      );
    }
    
    // 描いた線との衝突判定
    _isPlayerOnLine = false;
    for (final line in _drawnLines) {
      if (_isPlayerOnDrawnLine(line)) {
        _isPlayerOnLine = true;
        _applyLineEffect(line.type);
        break;
      }
    }
    
    // マグネット効果
    if (_hasMagnet) {
      _attractCoins();
    }
    
    // タイムスロー効果
    if (_isTimeSlowActive) {
      // ゲーム速度を半分に
    }
    
    // 画面外チェック
    if (_playerPosition.dy > 600) {
      _playerDied();
    }
  }
  
  void _applyLineEffect(LineType type) {
    switch (type) {
      case LineType.normal:
        // 基本効果なし
        break;
      case LineType.speed:
        _speed *= 1.2;
        _createParticles(_playerPosition, 10, Colors.blue);
        break;
      case LineType.jump:
        _jump();
        _createParticles(_playerPosition, 10, Colors.green);
        break;
      case LineType.shield:
        _hasShield = true;
        _createParticles(_playerPosition, 15, Colors.yellow);
        break;
      case LineType.heal:
        if (_lives < 3) {
          _lives++;
          _createParticles(_playerPosition, 15, Colors.pink);
        }
        break;
    }
  }
  
  void _attractCoins() {
    final magnetRadius = 150.0 + (_playerUpgrades[PlayerUpgrade.magnet]! * 30.0);
    for (final coin in _gameCoins) {
      final distance = (coin.position - _playerPosition).distance;
      if (distance < magnetRadius) {
        final direction = _normalizeOffset(_playerPosition - coin.position);
        coin.position = Offset(
          coin.position.dx + direction.dx * 5,
          coin.position.dy + direction.dy * 5,
        );
      }
    }
    
    // パワーアップも引き寄せる
    for (final powerUp in _powerUps) {
      final distance = (powerUp.position - _playerPosition).distance;
      if (distance < magnetRadius) {
        final direction = _normalizeOffset(_playerPosition - powerUp.position);
        powerUp.position = Offset(
          powerUp.position.dx + direction.dx * 5,
          powerUp.position.dy + direction.dy * 5,
        );
      }
    }
  }
  
  Offset _normalizeOffset(Offset offset) {
    final length = offset.distance;
    if (length == 0) return Offset.zero;
    return Offset(offset.dx / length, offset.dy / length);
  }
  
  bool _isPlayerOnDrawnLine(DrawnLine line) {
    const playerRadius = 15.0;
    
    for (int i = 0; i < line.points.length - 1; i++) {
      final p1 = line.points[i];
      final p2 = line.points[i + 1];
      
      final distance = _distanceToLineSegment(_playerPosition, p1, p2);
      if (distance < playerRadius) {
        return true;
      }
    }
    return false;
  }
  
  double _distanceToLineSegment(Offset point, Offset lineStart, Offset lineEnd) {
    final A = point.dx - lineStart.dx;
    final B = point.dy - lineStart.dy;
    final C = lineEnd.dx - lineStart.dx;
    final D = lineEnd.dy - lineStart.dy;
    
    final dot = A * C + B * D;
    final lenSq = C * C + D * D;
    
    if (lenSq == 0) return math.sqrt(A * A + B * B);
    
    final param = dot / lenSq;
    
    late double xx, yy;
    
    if (param < 0) {
      xx = lineStart.dx;
      yy = lineStart.dy;
    } else if (param > 1) {
      xx = lineEnd.dx;
      yy = lineEnd.dy;
    } else {
      xx = lineStart.dx + param * C;
      yy = lineStart.dy + param * D;
    }
    
    final dx = point.dx - xx;
    final dy = point.dy - yy;
    return math.sqrt(dx * dx + dy * dy);
  }
  
  void _updateObstacles() {
    _obstacles.removeWhere((obstacle) {
      obstacle.position = Offset(
        obstacle.position.dx - _speed * (obstacle.type == ObstacleType.moving ? 0.7 : 1.0),
        obstacle.position.dy,
      );
      return obstacle.position.dx < -50;
    });
  }
  
  void _updateEnemies() {
    _enemies.removeWhere((enemy) {
      // 敵の移動パターン
      switch (enemy.type) {
        case EnemyType.flying:
          enemy.position = Offset(
            enemy.position.dx - _speed * 0.8,
            enemy.position.dy + math.sin(_lastSpawnTime / 500) * 2,
          );
          break;
        case EnemyType.ground:
          enemy.position = Offset(
            enemy.position.dx - _speed * 0.9,
            enemy.position.dy,
          );
          break;
        case EnemyType.chasing:
          // プレイヤーを追跡
          final directionX = (_playerPosition.dx - enemy.position.dx).sign;
          final directionY = (_playerPosition.dy - enemy.position.dy).sign;
          enemy.position = Offset(
            enemy.position.dx - _speed * 0.7 + directionX * 1.5,
            enemy.position.dy + directionY * 1.5,
          );
          break;
      }
      
      return enemy.position.dx < -50 || enemy.health <= 0;
    });
  }
  
  void _updateBoss() {
    if (_currentBoss == null) return;
    
    final boss = _currentBoss!;
    
    // ボスの移動パターン
    switch (boss.type) {
      case BossType.dragon:
        boss.position = Offset(
          boss.position.dx - _speed * 0.5,
          200 + math.sin(_lastSpawnTime / 300) * 100,
        );
        break;
      case BossType.golem:
        boss.position = Offset(
          boss.position.dx - _speed * 0.3,
          boss.position.dy,
        );
        break;
    }
    
    // ボスが画面外に出たら削除
    if (boss.position.dx < -100) {
      _currentBoss = null;
    }
  }
  
  void _updateCoins() {
    _gameCoins.removeWhere((coin) {
      coin.position = Offset(
        coin.position.dx - _speed,
        coin.position.dy,
      );
      return coin.position.dx < -30;
    });
  }
  
  void _updatePowerUps() {
    _powerUps.removeWhere((powerUp) {
      powerUp.position = Offset(
        powerUp.position.dx - _speed,
        powerUp.position.dy,
      );
      return powerUp.position.dx < -40;
    });
  }
  
  void _updateParticles() {
    _particles.removeWhere((particle) {
      particle.position = Offset(
        particle.position.dx - _speed,
        particle.position.dy + particle.velocity.dy,
      );
      particle.lifetime--;
      return particle.lifetime <= 0 || particle.position.dx < -50;
    });
  }
  
  void _checkCollisions() {
    const playerRadius = 15.0;
    
    // 障害物との衝突
    for (final obstacle in _obstacles) {
      final distance = (obstacle.position - _playerPosition).distance;
      if (distance < playerRadius + obstacle.radius) {
        if (_hasShield) {
          _hasShield = false;
          _createParticles(_playerPosition, 20, Colors.yellow);
          _obstacles.remove(obstacle);
          _dailyQuests[DailyQuest.avoidObstacles] = _dailyQuests[DailyQuest.avoidObstacles]! + 1;
          break;
        } else {
          _playerDied();
          return;
        }
      }
    }
    
    // 敵との衝突
    for (final enemy in _enemies) {
      final distance = (enemy.position - _playerPosition).distance;
      if (distance < playerRadius + enemy.radius) {
        if (_hasShield) {
          _hasShield = false;
          _createParticles(_playerPosition, 20, Colors.yellow);
          enemy.health -= 1;
          if (enemy.health <= 0) {
            _defeatEnemy(enemy);
            _enemies.remove(enemy);
          }
          break;
        } else {
          _playerDied();
          return;
        }
      }
    }
    
    // ボスとの衝突
    if (_currentBoss != null) {
      final boss = _currentBoss!;
      final distance = (boss.position - _playerPosition).distance;
      if (distance < playerRadius + boss.radius) {
        if (_hasShield) {
          _hasShield = false;
          _createParticles(_playerPosition, 20, Colors.yellow);
          boss.health -= 5;
          if (boss.health <= 0) {
            _defeatBoss();
            _currentBoss = null;
          }
        } else {
          _playerDied();
          return;
        }
      }
    }
    
    // コインとの衝突
    _gameCoins.removeWhere((coin) {
      final distance = (coin.position - _playerPosition).distance;
      if (distance < playerRadius + 15) {
        _collectCoin();
        return true;
      }
      return false;
    });
    
    // パワーアップとの衝突
    _powerUps.removeWhere((powerUp) {
      final distance = (powerUp.position - _playerPosition).distance;
      if (distance < playerRadius + 20) {
        _collectPowerUp(powerUp);
        return true;
      }
      return false;
    });
  }
  
  void _spawnGameElements() {
    final random = math.Random();
    
    // 障害物スポーン
    if (_lastSpawnTime % _obstacleSpawnRate == 0 && random.nextDouble() < 0.7) {
      _obstacles.add(Obstacle(
        position: Offset(800, 200 + random.nextDouble() * 300),
        radius: 20 + random.nextDouble() * 10,
        type: ObstacleType.values[random.nextInt(ObstacleType.values.length)],
      ));
    }
    
    // 敵スポーン
    if (_lastSpawnTime % _enemySpawnRate == 0 && random.nextDouble() < 0.5) {
      _enemies.add(Enemy(
        position: Offset(800, 150 + random.nextDouble() * 400),
        radius: 25 + random.nextDouble() * 10,
        type: EnemyType.values[random.nextInt(EnemyType.values.length)],
        health: 1 + random.nextInt(2),
      ));
    }
    
    // コインスポーン
    if (_lastSpawnTime % 1000 == 0 && random.nextDouble() < 0.5) {
      _gameCoins.add(Coin(
        position: Offset(800, 150 + random.nextDouble() * 400),
        value: 1 + random.nextInt(3), // 1-3コイン
      ));
    }
    
    // パワーアップスポーン
    if (_lastSpawnTime % 5000 == 0 && random.nextDouble() < 0.2) {
      _powerUps.add(PowerUp(
        position: Offset(800, 200 + random.nextDouble() * 300),
        type: PowerUpType.values[random.nextInt(PowerUpType.values.length)],
      ));
    }
    
    // ラインタイムスポーン（特殊ラインを描くチャンス）
    if (_lastSpawnTime % 8000 == 0 && random.nextDouble() < 0.3) {
      _currentLineType = LineType.values[1 + random.nextInt(LineType.values.length - 1)];
      _createParticles(const Offset(400, 100), 15, _getLineTypeColor(_currentLineType));
    }
  }
  
  void _spawnBoss() {
    final random = math.Random();
    setState(() {
      _currentBoss = Boss(
        position: const Offset(800, 300),
        radius: 50,
        type: BossType.values[random.nextInt(BossType.values.length)],
        health: 20 + (_level * 5),
      );
      _lastBossSpawnTime = _lastSpawnTime;
    });
    
    _bossIntroController.forward();
    
    // ボスの攻撃パターン
    _bossAttackTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_currentBoss == null) {
        timer.cancel();
        return;
      }
      _bossAttack();
    });
  }
  
  void _bossAttack() {
    if (_currentBoss == null) return;
    
    final boss = _currentBoss!;
    final random = math.Random();
    
    // ボスの種類に応じた攻撃
    switch (boss.type) {
      case BossType.dragon:
        // 火の玉を発射
        _enemies.add(Enemy(
          position: boss.position,
          radius: 15,
          type: EnemyType.flying,
          health: 1,
          isProjectile: true,
        ));
        break;
      case BossType.golem:
        // 岩を投げる
        for (int i = 0; i < 3; i++) {
          _obstacles.add(Obstacle(
            position: Offset(boss.position.dx, boss.position.dy - 50 + i * 50),
            radius: 15,
            type: ObstacleType.moving,
          ));
        }
        break;
    }
    
    _createParticles(boss.position, 10, Colors.red);
  }
  
  void _createParticles(Offset position, int count, Color color) {
    final random = math.Random();
    for (int i = 0; i < count; i++) {
      _particles.add(Particle(
        position: position,
        velocity: Offset((random.nextDouble() - 0.5) * 3, (random.nextDouble() - 0.5) * 3),
        color: color,
        size: 2 + random.nextDouble() * 4,
        lifetime: 20 + random.nextInt(30),
      ));
    }
  }
  
  void _collectCoin() {
    setState(() {
      final coinValue = 1 + (_playerUpgrades[PlayerUpgrade.coinValue]! ~/ 2);
      _coins += coinValue;
      _totalCoinsCollected += coinValue;
      _dailyQuests[DailyQuest.collectCoins] = _dailyQuests[DailyQuest.collectCoins]! + 1;
      _score += 50 * _scoreMultiplier.round();
      _combo++;
      
      // チャレンジモードのゴール更新
      if (_currentMode == GameMode.challenge) {
        final challenge = _challenges.firstWhere((c) => c.id == _currentChallenge);
        if (challenge.goalType == ChallengeGoalType.coins) {
          _challengeGoal += coinValue;
          if (_challengeGoal >= challenge.goalValue) {
            _completeChallenge();
          }
        }
      }
      
      // コンボシステム
      if (_comboTimer != null) {
        _comboTimer!.cancel();
      }
      _comboTimer = Timer(const Duration(seconds: 3), () {
        setState(() {
          _combo = 0;
          _scoreMultiplier = 1.0;
        });
      });
      
      // コンボに応じたマルチプライヤー
      if (_combo >= 15) {
        _scoreMultiplier = 3.0;
      } else if (_combo >= 10) {
        _scoreMultiplier = 2.0;
      } else if (_combo >= 5) {
        _scoreMultiplier = 1.5;
      }
    });
    
    _createParticles(_playerPosition, 5, Colors.amber);
    HapticFeedback.selectionClick();
  }
  
  void _defeatEnemy(Enemy enemy) {
    setState(() {
      _score += 100 * _scoreMultiplier.round();
      _dailyQuests[DailyQuest.defeatEnemies] = _dailyQuests[DailyQuest.defeatEnemies]! + 1;
      _addXp(10);
      
      // チャレンジモードのゴール更新
      if (_currentMode == GameMode.challenge) {
        final challenge = _challenges.firstWhere((c) => c.id == _currentChallenge);
        if (challenge.goalType == ChallengeGoalType.defeatEnemies) {
          _challengeGoal += 1;
          if (_challengeGoal >= challenge.goalValue) {
            _completeChallenge();
          }
        }
      }
    });
    
    _createParticles(enemy.position, 10, Colors.red);
    HapticFeedback.mediumImpact();
  }
  
  void _defeatBoss() {
    setState(() {
      _score += 1000 * _scoreMultiplier.round();
      _coins += 20;
      _addXp(50);
    });
    
    _createParticles(_currentBoss!.position, 30, Colors.orange);
    HapticFeedback.heavyImpact();
  }
  
  void _addXp(int amount) {
    setState(() {
      _xp += amount;
      if (_xp >= _xpToNextLevel) {
        _levelUp();
      }
    });
  }
  
  void _levelUp() {
    setState(() {
      _level++;
      _xp -= _xpToNextLevel;
      _xpToNextLevel = (100 * math.pow(1.2, _level - 1)).round();
      _lives = 3; // レベルアップでライフ回復
    });
    
    _createParticles(_playerPosition, 20, Colors.blue);
    HapticFeedback.mediumImpact();
  }
  
  void _collectPowerUp(PowerUp powerUp) {
    setState(() {
      switch (powerUp.type) {
        case PowerUpType.speedBoost:
          _speed *= 1.5;
          _powerUpTimer = Timer(const Duration(seconds: 5), () {
            _speed /= 1.5;
          });
          break;
        case PowerUpType.shield:
          _hasShield = true;
          _powerUpTimer = Timer(Duration(seconds: 8 + _playerUpgrades[PlayerUpgrade.shield]! * 2), () {
            _hasShield = false;
          });
          break;
        case PowerUpType.magnet:
          _hasMagnet = true;
          _powerUpTimer = Timer(Duration(seconds: 6 + _playerUpgrades[PlayerUpgrade.magnet]! * 2), () {
            _hasMagnet = false;
          });
          break;
        case PowerUpType.multiplier:
          _scoreMultiplier *= 2;
          _powerUpTimer = Timer(const Duration(seconds: 10), () {
            _scoreMultiplier /= 2;
          });
          break;
        case PowerUpType.extraLife:
          if (_lives < 3) {
            _lives++;
          }
          break;
      }
    });
    
    _createParticles(_playerPosition, 15, _getPowerUpColor(powerUp.type));
    HapticFeedback.mediumImpact();
  }
  
  void _useActiveSkill() {
    if (_skillCooldown > 0 || !_unlockedSkills[_selectedSkill]!) return;
    
    setState(() {
      _skillCooldown = _getSkillCooldown(_selectedSkill);
      
      switch (_selectedSkill) {
        case ActiveSkill.doubleJump:
          _doubleJump();
          break;
        case ActiveSkill.timeSlow:
          _activateTimeSlow();
          break;
        case ActiveSkill.shockwave:
          _activateShockwave();
          break;
      }
    });
    
    // クールダウンタイマー
    _skillCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _skillCooldown--;
        if (_skillCooldown <= 0) {
          timer.cancel();
        }
      });
    });
  }
  
  void _doubleJump() {
    if (!_isJumping) return;
    
    setState(() {
      _playerPosition = Offset(
        _playerPosition.dx,
        _playerPosition.dy - 120,
      );
      _isDoubleJumpAvailable = false;
    });
    
    _createParticles(_playerPosition, 10, Colors.cyan);
    HapticFeedback.lightImpact();
  }
  
  void _activateTimeSlow() {
    setState(() {
      _isTimeSlowActive = true;
    });
    
    _skillTimer = Timer(const Duration(seconds: 5), () {
      setState(() {
        _isTimeSlowActive = false;
      });
    });
    
    _createParticles(_playerPosition, 20, Colors.purple);
    HapticFeedback.mediumImpact();
  }
  
  void _activateShockwave() {
    // 周囲の敵をノックバック
    for (final enemy in _enemies) {
      final distance = (enemy.position - _playerPosition).distance;
      if (distance < 200) {
        final direction = _normalizeOffset(enemy.position - _playerPosition);
        enemy.position = Offset(
          enemy.position.dx + direction.dx * 100,
          enemy.position.dy + direction.dy * 100,
        );
        enemy.health -= 1;
        
        if (enemy.health <= 0) {
          _defeatEnemy(enemy);
        }
      }
    }
    
    // 障害物もノックバック
    for (final obstacle in _obstacles) {
      final distance = (obstacle.position - _playerPosition).distance;
      if (distance < 200) {
        final direction = _normalizeOffset(obstacle.position - _playerPosition);
        obstacle.position = Offset(
          obstacle.position.dx + direction.dx * 100,
          obstacle.position.dy + direction.dy * 100,
        );
      }
    }
    
    _createParticles(_playerPosition, 30, Colors.orange);
    HapticFeedback.heavyImpact();
  }
  
  int _getSkillCooldown(ActiveSkill skill) {
    switch (skill) {
      case ActiveSkill.doubleJump:
        return 10;
      case ActiveSkill.timeSlow:
        return 20;
      case ActiveSkill.shockwave:
        return 15;
    }
  }
  
  void _playerDied() {
    setState(() {
      _lives--;
      _consecutiveFailures++;
      _combo = 0;
      _scoreMultiplier = 1.0;
      
      // 難易度調整（3回連続失敗で難易度下げる）
      if (_consecutiveFailures >= 3) {
        _difficultyMultiplier = math.max(0.5, _difficultyMultiplier * 0.8);
        _consecutiveFailures = 0;
      }
    });
    
    _createParticles(_playerPosition, 20, Colors.red);
    _shakeScreen();
    HapticFeedback.heavyImpact();
    
    if (_lives <= 0) {
      _gameOver();
    } else {
      _respawnPlayer();
    }
  }
  
  void _shakeScreen() {
    _shakeController.forward(from: 0);
  }
  
  void _respawnPlayer() {
    setState(() {
      _playerPosition = const Offset(100, 300);
      _isJumping = false;
      _isDoubleJumpAvailable = true;
    });
  }
  
  void _completeChallenge() {
    final challenge = _challenges.firstWhere((c) => c.id == _currentChallenge);
    setState(() {
      _coins += challenge.reward;
      _gems += 5;
    });
    
    _gameOver();
  }
  
  void _gameOver() {
    setState(() {
      _gameState = GameState.gameOver;
      if (_score > _highScore) {
        _highScore = _score;
      }
    });
    
    _gameTimer?.cancel();
    _spawnTimer?.cancel();
    _backgroundController.stop();
    _skillCooldownTimer?.cancel();
    _bossAttackTimer?.cancel();
    _saveGameData();
    _checkAchievements();
  }
  
  void _jump() {
    if (_isJumping && (!_unlockedSkills[ActiveSkill.doubleJump]! || !_isDoubleJumpAvailable)) return;
    
    if (_isJumping && _isDoubleJumpAvailable) {
      _doubleJump();
      return;
    }
    
    setState(() {
      _isJumping = true;
    });
    
    _playerController.forward().then((_) {
      setState(() {
        final jumpHeight = 100 + (_playerUpgrades[PlayerUpgrade.jump]! * 20);
        _playerPosition = Offset(
          _playerPosition.dx,
          _playerPosition.dy - jumpHeight,
        );
      });
      
      Timer(const Duration(milliseconds: 300), () {
        setState(() {
          _isJumping = false;
        });
        _playerController.reverse();
      });
    });
    
    _createParticles(_playerPosition, 5, Colors.white);
    HapticFeedback.lightImpact();
  }
  
  void _onPanStart(DragStartDetails details) {
    if (_gameState != GameState.playing) return;
    
    setState(() {
      _isDrawing = true;
      _currentLine.clear();
      _currentLine.add(details.localPosition);
    });
  }
  
  void _onPanUpdate(DragUpdateDetails details) {
    if (_gameState != GameState.playing || !_isDrawing) return;
    
    setState(() {
      _currentLine.add(details.localPosition);
    });
  }
  
  void _onPanEnd(DragEndDetails details) {
    if (_gameState != GameState.playing || !_isDrawing) return;
    
    setState(() {
      _isDrawing = false;
      if (_currentLine.length > 1) {
        _drawnLines.add(DrawnLine(
          points: List.from(_currentLine),
          color: _getLineTypeColor(_currentLineType),
          width: 5.0,
          type: _currentLineType,
        ));
        
        // 古い線を削除（最大8本まで）
        if (_drawnLines.length > 8) {
          _drawnLines.removeAt(0);
        }
        
        // 通常の線に戻す
        _currentLineType = LineType.normal;
      }
      _currentLine.clear();
    });
    
    _createParticles(_currentLine.isNotEmpty ? _currentLine.last : const Offset(0, 0), 8, _getLineTypeColor(_currentLineType));
    HapticFeedback.selectionClick();
  }
  
  void _switchGameMode(GameMode mode) {
    setState(() {
      _currentMode = mode;
    });
  }
  
  void _selectChallenge(int challengeId) {
    setState(() {
      _currentChallenge = challengeId;
    });
  }
  
  void _upgradePlayer(PlayerUpgrade upgrade) {
    if (_coins < _getUpgradeCost(upgrade)) return;
    
    setState(() {
      _coins -= _getUpgradeCost(upgrade);
      _playerUpgrades[upgrade] = _playerUpgrades[upgrade]! + 1;
    });
    
    _saveGameData();
    HapticFeedback.selectionClick();
  }
  
  void _unlockSkill(ActiveSkill skill) {
    if (_gems < 15) return;
    
    setState(() {
      _gems -= 15;
      _unlockedSkills[skill] = true;
    });
    
    _saveGameData();
    HapticFeedback.selectionClick();
  }
  
  void _selectSkill(ActiveSkill skill) {
    setState(() {
      _selectedSkill = skill;
    });
    
    _saveGameData();
    HapticFeedback.selectionClick();
  }
  
  int _getUpgradeCost(PlayerUpgrade upgrade) {
    final baseCosts = {
      PlayerUpgrade.speed: 50,
      PlayerUpgrade.jump: 40,
      PlayerUpgrade.shield: 60,
      PlayerUpgrade.magnet: 70,
      PlayerUpgrade.coinValue: 80,
    };
    
    return baseCosts[upgrade]! * (_playerUpgrades[upgrade]! + 1);
  }
  
  Color _getLineTypeColor(LineType type) {
    switch (type) {
      case LineType.normal:
        return _getThemeColor();
      case LineType.speed:
        return Colors.blue;
      case LineType.jump:
        return Colors.green;
      case LineType.shield:
        return Colors.yellow;
      case LineType.heal:
        return Colors.pink;
    }
  }
  
  Color _getPowerUpColor(PowerUpType type) {
    switch (type) {
      case PowerUpType.speedBoost:
        return Colors.blue;
      case PowerUpType.shield:
        return Colors.yellow;
      case PowerUpType.magnet:
        return Colors.purple;
      case PowerUpType.multiplier:
        return Colors.orange;
      case PowerUpType.extraLife:
        return Colors.pink;
    }
  }
  
  Color _getThemeColor() {
    switch (_currentTheme) {
      case GameTheme.neon:
        return Colors.cyan;
      case GameTheme.japanese:
        return Colors.red;
      case GameTheme.space:
        return Colors.purple;
    }
  }
  
  void _switchTheme() {
    setState(() {
      final themes = GameTheme.values;
      final currentIndex = themes.indexOf(_currentTheme);
      _currentTheme = themes[(currentIndex + 1) % themes.length];
    });
  }
  
  void _switchSkin() {
    setState(() {
      final skins = PlayerSkin.values;
      final currentIndex = skins.indexOf(_currentSkin);
      _currentSkin = skins[(currentIndex + 1) % skins.length];
    });
    _saveGameData();
  }
  
  @override
  void dispose() {
    _playerController.dispose();
    _gameController.dispose();
    _backgroundController.dispose();
    _shakeController.dispose();
    _bossIntroController.dispose();
    _gameTimer?.cancel();
    _spawnTimer?.cancel();
    _comboTimer?.cancel();
    _skillCooldownTimer?.cancel();
    _bossAttackTimer?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_shakeController, _bossIntroController]),
        builder: (context, child) {
          final shakeOffset = Offset(
            0,
            _shakeController.value * 10 * math.sin(_shakeController.value * 20),
          );
          
          final bossIntroScale = _bossIntroController.value < 0.5 
              ? _bossIntroController.value * 2 
              : 1.0;
          
          return Transform.translate(
            offset: shakeOffset,
            child: Stack(
              children: [
                Container(
                  decoration: _getBackgroundDecoration(),
                  child: Stack(
                    children: [
                      // パララックス背景
                      _buildParallaxBackground(),
                      
                      // ゲーム画面
                      if (_gameState == GameState.playing) ...[
                        // ゲームエリア
                        GestureDetector(
                          onPanStart: _onPanStart,
                          onPanUpdate: _onPanUpdate,
                          onPanEnd: _onPanEnd,
                          onTap: _jump,
                          onDoubleTap: _useActiveSkill,
                          child: CustomPaint(
                            painter: GamePainter(
                              drawnLines: _drawnLines,
                              currentLine: _currentLine,
                              isDrawing: _isDrawing,
                              playerPosition: _playerPosition,
                              obstacles: _obstacles,
                              enemies: _enemies,
                              boss: _currentBoss,
                              coins: _gameCoins,
                              powerUps: _powerUps,
                              particles: _particles,
                              theme: _currentTheme,
                              playerSkin: _currentSkin,
                              hasShield: _hasShield,
                              hasMagnet: _hasMagnet,
                              currentLineType: _currentLineType,
                              isTimeSlowActive: _isTimeSlowActive,
                            ),
                            size: Size.infinite,
                          ),
                        ),
                        
                        // ボス登場アニメーション
                        if (_currentBoss != null && _bossIntroController.value < 1.0)
                          Transform.scale(
                            scale: bossIntroScale,
                            child: Center(
                              child: Text(
                                '${_getBossName(_currentBoss!.type)} 登場!',
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(2, 2),
                                      blurRadius: 4,
                                      color: Colors.black,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        
                        // UI オーバーレイ
                        _buildGameUI(),
                        
                        // ラインタイプインジケーター
                        _buildLineTypeIndicator(),
                        
                        // スキルボタン
                        _buildSkillButton(),
                      ],
                      
                      // メニュー画面
                      if (_gameState == GameState.menu) _buildMenuScreen(),
                      
                      // ゲームオーバー画面
                      if (_gameState == GameState.gameOver) _buildGameOverScreen(),
                      
                      // アップグレード画面
                      if (_gameState == GameState.upgrade) _buildUpgradeScreen(),
                    ],
                  ),
                ),
                
                // タイムスロー効果
                if (_isTimeSlowActive)
                  Container(
                    color: Colors.purple.withOpacity(0.2),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildParallaxBackground() {
    return Stack(
      children: [
        // 遠景
        Transform.translate(
          offset: Offset(-_backgroundAnimation.value * 100, 0),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _getParallaxColors(0),
              ),
            ),
          ),
        ),
        
        // 中景
        Transform.translate(
          offset: Offset(-_backgroundAnimation.value * 200, 0),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _getParallaxColors(1),
              ),
            ),
          ),
        ),
        
        // 近景
        Transform.translate(
          offset: Offset(-_backgroundAnimation.value * 300, 0),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _getParallaxColors(2),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  List<Color> _getParallaxColors(int layer) {
    switch (_currentTheme) {
      case GameTheme.neon:
        return [
          [Color(0xFF0F0F23), Color(0xFF1A1A2E), Color(0xFF16213E)],
          [Color(0xFF1A1A2E).withOpacity(0.7), Color(0xFF16213E).withOpacity(0.7)],
          [Color(0xFF16213E).withOpacity(0.5), Color(0xFF0F0F23).withOpacity(0.5)],
        ][layer];
      case GameTheme.japanese:
        return [
          [Color(0xFF2C1810), Color(0xFF8B4513), Color(0xFFD2691E)],
          [Color(0xFF8B4513).withOpacity(0.7), Color(0xFFD2691E).withOpacity(0.7)],
          [Color(0xFFD2691E).withOpacity(0.5), Color(0xFF2C1810).withOpacity(0.5)],
        ][layer];
      case GameTheme.space:
        return [
          [Color(0xFF0B0B2F), Color(0xFF1E1E3F), Color(0xFF2D1B69)],
          [Color(0xFF1E1E3F).withOpacity(0.7), Color(0xFF2D1B69).withOpacity(0.7)],
          [Color(0xFF2D1B69).withOpacity(0.5), Color(0xFF0B0B2F).withOpacity(0.5)],
        ][layer];
    }
  }
  
  BoxDecoration _getBackgroundDecoration() {
    switch (_currentTheme) {
      case GameTheme.neon:
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0F23), Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        );
      case GameTheme.japanese:
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2C1810), Color(0xFF8B4513), Color(0xFFD2691E)],
          ),
        );
      case GameTheme.space:
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B0B2F), Color(0xFF1E1E3F), Color(0xFF2D1B69)],
          ),
        );
    }
  }
  
  Widget _buildLineTypeIndicator() {
    if (_currentLineType == LineType.normal) return const SizedBox();
    
    return Positioned(
      top: 100,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(
              Icons.auto_awesome,
              color: _getLineTypeColor(_currentLineType),
              size: 30,
            ),
            const SizedBox(height: 8),
            Text(
              _getLineTypeName(_currentLineType),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSkillButton() {
    if (!_unlockedSkills[_selectedSkill]!) return const SizedBox();
    
    return Positioned(
      bottom: 20,
      right: 20,
      child: Column(
        children: [
          // クールダウン表示
          if (_skillCooldown > 0)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$_skillCooldown',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          
          const SizedBox(height: 10),
          
          // スキルボタン
          GestureDetector(
            onTap: _skillCooldown > 0 ? null : _useActiveSkill,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _skillCooldown > 0 ? Colors.grey : Colors.purple,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                _getSkillIcon(_selectedSkill),
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  IconData _getSkillIcon(ActiveSkill skill) {
    switch (skill) {
      case ActiveSkill.doubleJump:
        return Icons.arrow_upward;
      case ActiveSkill.timeSlow:
        return Icons.timer;
      case ActiveSkill.shockwave:
        return Icons.flash_on;
    }
  }
  
  String _getLineTypeName(LineType type) {
    switch (type) {
      case LineType.normal:
        return '通常';
      case LineType.speed:
        return 'スピード';
      case LineType.jump:
        return 'ジャンプ';
      case LineType.shield:
        return 'シールド';
      case LineType.heal:
        return 'ヒール';
    }
  }
  
  String _getBossName(BossType type) {
    switch (type) {
      case BossType.dragon:
        return '火炎龍';
      case BossType.golem:
        return '岩の巨人';
    }
  }
  
  Widget _buildGameUI() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 上部UI
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // スコア
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'スコア: $_score',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_scoreMultiplier > 1.0)
                        Text(
                          'x$_scoreMultiplier',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
                
                // ライフ
                Row(
                  children: List.generate(_lives, (index) => 
                    const Icon(Icons.favorite, color: Colors.red, size: 24)
                  ),
                ),
              ],
            ),
            
            const Spacer(),
            
            // 下部UI
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // コイン
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        '$_coins',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // コンボ表示
                if (_combo > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'コンボ: $_combo',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                // テーマ切り替えボタン
                FloatingActionButton(
                  mini: true,
                  onPressed: _switchTheme,
                  backgroundColor: _getThemeColor(),
                  child: const Icon(Icons.palette, color: Colors.white),
                ),
              ],
            ),
            
            // チャレンジモードの進捗表示
            if (_currentMode == GameMode.challenge) 
              _buildChallengeProgress(),
            
            // ボスの体力表示
            if (_currentBoss != null)
              _buildBossHealthBar(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildChallengeProgress() {
    final challenge = _challenges.firstWhere((c) => c.id == _currentChallenge);
    final progress = _challengeGoal / challenge.goalValue;
    
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            challenge.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${_challengeGoal}/${challenge.goalValue}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '残り時間: ${(_challengeTimeLeft / 1000).toStringAsFixed(1)}秒',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBossHealthBar() {
    if (_currentBoss == null) return const SizedBox();
    
    final boss = _currentBoss!;
    final progress = boss.health / boss.maxHealth;
    
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            _getBossName(boss.type),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${boss.health}/${boss.maxHealth}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildMenuScreen() {
    return Container(
      decoration: _getBackgroundDecoration(),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ロゴ
              const Icon(
                Icons.brush,
                size: 120,
                color: Colors.cyan,
              ),
              const SizedBox(height: 20),
              
              // タイトル
              const Text(
                'Quick Draw Dash',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(2, 2),
                      blurRadius: 4,
                      color: Colors.cyan,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 10),
              const Text(
                '描いて走る冒険ゲーム',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white70,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // ゲームモード選択
              _buildGameModeSelector(),
              
              const SizedBox(height: 20),
              
              // ハイスコア
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      'ハイスコア: $_highScore',
                      style: const TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'コイン: $_coins   ジェム: $_gems',
                      style: const TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Lv.$_level (XP: $_xp/$_xpToNextLevel)',
                      style: const TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // 開始ボタン
              ElevatedButton(
                onPressed: _startGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'ゲーム開始',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // その他のボタン
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // スキン選択ボタン
                  ElevatedButton(
                    onPressed: _switchSkin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('スキン: ${_getSkinName(_currentSkin)}'),
                  ),
                  
                  const SizedBox(width: 10),
                  
                  // アップグレードボタン
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _gameState = GameState.upgrade;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('アップグレード'),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // 説明
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  '画面をタップしてジャンプ\nダブルタップでスキル発動\n指で線を描いて道を作ろう！\n特殊な線でパワーアップ！',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white60,
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // デイリークエスト
              _buildDailyQuests(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildGameModeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            'ゲームモード',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // エンドレスモード
          ListTile(
            leading: Icon(
              Icons.all_inclusive,
              color: _currentMode == GameMode.endless ? Colors.cyan : Colors.white70,
            ),
            title: const Text(
              'エンドレス',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              '制限時間なくプレイ',
              style: TextStyle(color: Colors.white70),
            ),
            trailing: _currentMode == GameMode.endless 
                ? const Icon(Icons.check, color: Colors.cyan)
                : null,
            onTap: () => _switchGameMode(GameMode.endless),
          ),
          
          // チャレンジモード
          ListTile(
            leading: Icon(
              Icons.flag,
              color: _currentMode == GameMode.challenge ? Colors.cyan : Colors.white70,
            ),
            title: const Text(
              'チャレンジ',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              '特定の目標に挑戦',
              style: TextStyle(color: Colors.white70),
            ),
            trailing: _currentMode == GameMode.challenge 
                ? const Icon(Icons.check, color: Colors.cyan)
                : null,
            onTap: () => _switchGameMode(GameMode.challenge),
          ),
          
          // チャレンジ選択
          if (_currentMode == GameMode.challenge)
            Column(
              children: _challenges.map((challenge) {
                return ListTile(
                  leading: Icon(
                    Icons.star,
                    color: _currentChallenge == challenge.id ? Colors.amber : Colors.white70,
                  ),
                  title: Text(
                    challenge.name,
                    style: TextStyle(
                      color: _currentChallenge == challenge.id ? Colors.amber : Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    challenge.description,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: _currentChallenge == challenge.id 
                      ? const Icon(Icons.check, color: Colors.amber)
                      : null,
                  onTap: () => _selectChallenge(challenge.id),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
  
  String _getSkinName(PlayerSkin skin) {
    switch (skin) {
      case PlayerSkin.defaultSkin:
        return 'デフォルト';
      case PlayerSkin.ninja:
        return '忍者';
      case PlayerSkin.robot:
        return 'ロボット';
      case PlayerSkin.astronaut:
        return '宇宙飛行士';
    }
  }
  
  Widget _buildDailyQuests() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            'デイリークエスト',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          // コイン収集クエスト
          _buildQuestItem('コインを50枚集める', _dailyQuests[DailyQuest.collectCoins]!, 50, Colors.amber),
          const SizedBox(height: 8),
          // 走行距離クエスト
          _buildQuestItem('100m走る', _dailyQuests[DailyQuest.runMeters]!, 100, Colors.green),
          const SizedBox(height: 8),
          // 障害物回避クエスト
          _buildQuestItem('障害物を10回回避', _dailyQuests[DailyQuest.avoidObstacles]!, 10, Colors.blue),
          const SizedBox(height: 8),
          // 敵撃破クエスト
          _buildQuestItem('敵を5体倒す', _dailyQuests[DailyQuest.defeatEnemies]!, 5, Colors.red),
        ],
      ),
    );
  }
  
  Widget _buildQuestItem(String title, int progress, int target, Color color) {
    return Row(
      children: [
        Icon(Icons.circle, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        Text(
          '$progress/$target',
          style: TextStyle(color: color),
        ),
      ],
    );
  }
  
  Widget _buildUpgradeScreen() {
    return Container(
      decoration: _getBackgroundDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _gameState = GameState.menu;
                  });
                },
              ),
              title: const Text(
                'アップグレード',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // プレイヤーアップグレード
                    _buildPlayerUpgrades(),
                    
                    const SizedBox(height: 20),
                    
                    // スキルアップグレード
                    _buildSkillUpgrades(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPlayerUpgrades() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            'プレイヤーアップグレード',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // スピードアップグレード
          _buildUpgradeItem(
            PlayerUpgrade.speed,
            Icons.speed,
            'スピード',
            '移動速度がアップします',
          ),
          
          const SizedBox(height: 8),
          
          // ジャンプアップグレード
          _buildUpgradeItem(
            PlayerUpgrade.jump,
            Icons.arrow_upward,
            'ジャンプ',
            'ジャンプ力がアップします',
          ),
          
          const SizedBox(height: 8),
          
          // シールドアップグレード
          _buildUpgradeItem(
            PlayerUpgrade.shield,
            Icons.shield,
            'シールド',
            'シールドの持続時間が延長します',
          ),
          
          const SizedBox(height: 8),
          
          // マグネットアップグレード
          _buildUpgradeItem(
            PlayerUpgrade.magnet,
            Icons.radio_button_checked,
            'マグネット',
            '磁力の範囲と持続時間がアップします',
          ),
          
          const SizedBox(height: 8),
          
          // コイン価値アップグレード
          _buildUpgradeItem(
            PlayerUpgrade.coinValue,
            Icons.monetization_on,
            'コイン価値',
            '獲得コインの価値がアップします',
          ),
        ],
      ),
    );
  }
  
  Widget _buildUpgradeItem(PlayerUpgrade upgrade, IconData icon, String title, String description) {
    final level = _playerUpgrades[upgrade]!;
    final cost = _getUpgradeCost(upgrade);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title Lv.$level',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _coins >= cost ? () => _upgradePlayer(upgrade) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _coins >= cost ? Colors.amber : Colors.grey,
              foregroundColor: Colors.black,
            ),
            child: Text('$costコイン'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSkillUpgrades() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            'アクティブスキル',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // ダブルジャンプ
          _buildSkillItem(
            ActiveSkill.doubleJump,
            Icons.arrow_upward,
            'ダブルジャンプ',
            '空中でもう一度ジャンプできます',
          ),
          
          const SizedBox(height: 8),
          
          // タイムスロー
          _buildSkillItem(
            ActiveSkill.timeSlow,
            Icons.timer,
            'タイムスロー',
            '時間の流れを遅くします',
          ),
          
          const SizedBox(height: 8),
          
          // ショックウェーブ
          _buildSkillItem(
            ActiveSkill.shockwave,
            Icons.flash_on,
            'ショックウェーブ',
            '周囲の敵を吹き飛ばします',
          ),
        ],
      ),
    );
  }
  
  Widget _buildSkillItem(ActiveSkill skill, IconData icon, String title, String description) {
    final isUnlocked = _unlockedSkills[skill]!;
    final isSelected = _selectedSkill == skill;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected ? Colors.purple.withOpacity(0.3) : Colors.black38,
        borderRadius: BorderRadius.circular(12),
        border: isSelected ? Border.all(color: Colors.purple) : null,
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          if (!isUnlocked)
            ElevatedButton(
              onPressed: _gems >= 15 ? () => _unlockSkill(skill) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _gems >= 15 ? Colors.purple : Colors.grey,
                foregroundColor: Colors.white,
              ),
              child: const Text('15ジェム'),
            )
          else
            IconButton(
              icon: Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected ? Colors.cyan : Colors.white70,
              ),
              onPressed: () => _selectSkill(skill),
            ),
        ],
      ),
    );
  }
  
  Widget _buildGameOverScreen() {
    final isChallenge = _currentMode == GameMode.challenge;
    final isSuccess = isChallenge && _challengeGoal >= _challenges.firstWhere((c) => c.id == _currentChallenge).goalValue;
    
    return Container(
      decoration: _getBackgroundDecoration(),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ゲームオーバーテキスト
            Text(
              isChallenge
                ? isSuccess ? 'チャレンジ成功!' : 'チャレンジ失敗'
                : 'ゲームオーバー',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: isChallenge && isSuccess ? Colors.green : Colors.red,
              ),
            ),
            
            const SizedBox(height: 40),
            
            // 最終スコア
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    'スコア: $_score',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (_score == _highScore && !isChallenge)
                  const Text(
                    'ニューハイスコア！',
                    style: TextStyle(
                      color: Colors.yellow,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '獲得コイン: $_coins',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.amber,
                    ),
                  ),
                  Text(
                    '走行距離: ${_meters}m',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  
                  if (isChallenge && isSuccess)
                    Column(
                      children: [
                        const SizedBox(height: 10),
                        Text(
                          '報酬: ${_challenges.firstWhere((c) => c.id == _currentChallenge).reward}コイン',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // ボタン
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  child: const Text('もう一度'),
                ),
                
                const SizedBox(width: 20),
                
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _gameState = GameState.menu;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  child: const Text('メニュー'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ゲーム状態
enum GameState { menu, playing, gameOver, upgrade }

// ゲームモード
enum GameMode { endless, challenge }

// テーマ
enum GameTheme { neon, japanese, space }

// パワーアップタイプ
enum PowerUpType { speedBoost, shield, magnet, multiplier, extraLife }

// ラインタイプ
enum LineType { normal, speed, jump, shield, heal }

// 障害物タイプ
enum ObstacleType { normal, moving, spinning }

// 敵タイプ
enum EnemyType { flying, ground, chasing }

// ボスタイプ
enum BossType { dragon, golem }

// プレイヤースキン
enum PlayerSkin { defaultSkin, ninja, robot, astronaut }

// プレイヤーアップグレード
enum PlayerUpgrade { speed, jump, shield, magnet, coinValue }

// アクティブスキル
enum ActiveSkill { doubleJump, timeSlow, shockwave }

// アチーブメントタイプ
enum AchievementType { highScore, coinCollector, marathonRunner, enemyDestroyer, bossCrusher }

// デイリークエスト
enum DailyQuest { collectCoins, runMeters, avoidObstacles, defeatEnemies }

// チャレンジ目標タイプ
enum ChallengeGoalType { distance, coins, avoidObstacles, defeatEnemies }

// 描いた線のクラス
class DrawnLine {
  final List<Offset> points;
  final Color color;
  final double width;
  final LineType type;
  
  DrawnLine({
    required this.points,
    required this.color,
    required this.width,
    required this.type,
  });
}

// 障害物クラス
class Obstacle {
  Offset position;
  final double radius;
  final ObstacleType type;
  
  Obstacle({
    required this.position,
    required this.radius,
    required this.type,
  });
}

// 敵クラス
class Enemy {
  Offset position;
  final double radius;
  final EnemyType type;
  int health;
  bool isProjectile;
  
  Enemy({
    required this.position,
    required this.radius,
    required this.type,
    this.health = 1,
    this.isProjectile = false,
  });
}

// ボスクラス
class Boss {
  Offset position;
  final double radius;
  final BossType type;
  int health;
  int get maxHealth => health;
  
  Boss({
    required this.position,
    required this.radius,
    required this.type,
    required this.health,
  });
}

// コインクラス
class Coin {
  Offset position;
  final int value;
  
  Coin({required this.position, this.value = 1});
}

// パワーアップクラス
class PowerUp {
  Offset position;
  final PowerUpType type;
  
  PowerUp({
    required this.position,
    required this.type,
  });
}

// パーティクルクラス
class Particle {
  Offset position;
  Offset velocity;
  Color color;
  double size;
  int lifetime;
  
  Particle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.lifetime,
  });
}

// チャレンジクラス
class Challenge {
  final int id;
  final String name;
  final String description;
  final int duration;
  final ChallengeGoalType goalType;
  final int reward;
  
  int get goalValue {
    switch (goalType) {
      case ChallengeGoalType.distance:
        return 500;
      case ChallengeGoalType.coins:
        return 50;
      case ChallengeGoalType.avoidObstacles:
        return 20;
      case ChallengeGoalType.defeatEnemies:
        return 10;
    }
  }
  
  Challenge({
    required this.id,
    required this.name,
    required this.description,
    required this.duration,
    required this.goalType,
    required this.reward,
  });
}

// ゲーム描画クラス
class GamePainter extends CustomPainter {
  final List<DrawnLine> drawnLines;
  final List<Offset> currentLine;
  final bool isDrawing;
  final Offset playerPosition;
  final List<Obstacle> obstacles;
  final List<Enemy> enemies;
  final Boss? boss;
  final List<Coin> coins;
  final List<PowerUp> powerUps;
  final List<Particle> particles;
  final GameTheme theme;
  final PlayerSkin playerSkin;
  final bool hasShield;
  final bool hasMagnet;
  final LineType currentLineType;
  final bool isTimeSlowActive;
  
  GamePainter({
    required this.drawnLines,
    required this.currentLine,
    required this.isDrawing,
    required this.playerPosition,
    required this.obstacles,
    required this.enemies,
    required this.boss,
    required this.coins,
    required this.powerUps,
    required this.particles,
    required this.theme,
    required this.playerSkin,
    required this.hasShield,
    required this.hasMagnet,
    required this.currentLineType,
    required this.isTimeSlowActive,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // 描いた線を描画
    for (final line in drawnLines) {
      _drawLine(canvas, line);
    }
    
    // 現在描いている線を描画
    if (isDrawing && currentLine.length > 1) {
      _drawCurrentLine(canvas);
    }
    
    // パーティクルを描画
    for (final particle in particles) {
      _drawParticle(canvas, particle);
    }
    
    // コインを描画
    for (final coin in coins) {
      _drawCoin(canvas, coin);
    }
    
    // パワーアップを描画
    for (final powerUp in powerUps) {
      _drawPowerUp(canvas, powerUp);
    }
    
    // 障害物を描画
    for (final obstacle in obstacles) {
      _drawObstacle(canvas, obstacle);
    }
    
    // 敵を描画
    for (final enemy in enemies) {
      _drawEnemy(canvas, enemy);
    }
    
    // ボスを描画
    if (boss != null) {
      _drawBoss(canvas, boss!);
    }
    
    // プレイヤーを描画
    _drawPlayer(canvas);
    
    // タイムスロー効果
    if (isTimeSlowActive) {
      final paint = Paint()
        ..color = Colors.purple.withOpacity(0.1)
        ..blendMode = BlendMode.multiply;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    }
  }
  
  void _drawLine(Canvas canvas, DrawnLine line) {
    final paint = Paint()
      ..color = line.color
      ..strokeWidth = line.width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    if (line.points.isNotEmpty) {
      path.moveTo(line.points.first.dx, line.points.first.dy);
      for (int i = 1; i < line.points.length; i++) {
        path.lineTo(line.points[i].dx, line.points[i].dy);
      }
    }
    
    canvas.drawPath(path, paint);
    
    // グロー効果
    final glowPaint = Paint()
      ..color = line.color.withOpacity(0.3)
      ..strokeWidth = line.width + 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    canvas.drawPath(path, glowPaint);
  }
  
  void _drawCurrentLine(Canvas canvas) {
    final paint = Paint()
      ..color = _getLineTypeColor(currentLineType).withOpacity(0.7)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    path.moveTo(currentLine.first.dx, currentLine.first.dy);
    for (int i = 1; i < currentLine.length; i++) {
      path.lineTo(currentLine[i].dx, currentLine[i].dy);
    }
    
    canvas.drawPath(path, paint);
  }
  
  void _drawParticle(Canvas canvas, Particle particle) {
    final paint = Paint()
      ..color = particle.color.withOpacity(particle.lifetime / 50.0)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(particle.position, particle.size, paint);
  }
  
  void _drawPlayer(Canvas canvas) {
    final paint = Paint()
      ..color = _getPlayerColor()
      ..style = PaintingStyle.fill;
    
    // プレイヤー本体
    canvas.drawCircle(playerPosition, 15, paint);
    
    // スキンに応じた詳細の描画
    _drawPlayerDetails(canvas);
    
    // シールド効果
    if (hasShield) {
      final shieldPaint = Paint()
        ..color = Colors.yellow.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      
      canvas.drawCircle(playerPosition, 20, shieldPaint);
      
      // シールドのグロー効果
      final shieldGlowPaint = Paint()
        ..color = Colors.yellow.withOpacity(0.1)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      
      canvas.drawCircle(playerPosition, 23, shieldGlowPaint);
    }
    
    // マグネット効果
    if (hasMagnet) {
      final magnetPaint = Paint()
        ..color = Colors.purple.withOpacity(0.2)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(playerPosition, 150, magnetPaint);
    }
    
    // グロー効果
    final glowPaint = Paint()
      ..color = _getThemeColor().withOpacity(0.5)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    
    canvas.drawCircle(playerPosition, 18, glowPaint);
  }
  
  void _drawPlayerDetails(Canvas canvas) {
    switch (playerSkin) {
      case PlayerSkin.defaultSkin:
        // 目
        final eyePaint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.fill;
        
        canvas.drawCircle(
          Offset(playerPosition.dx - 5, playerPosition.dy - 5),
          3,
          eyePaint,
        );
        canvas.drawCircle(
          Offset(playerPosition.dx + 5, playerPosition.dy - 5),
          3,
          eyePaint,
        );
        break;
        
      case PlayerSkin.ninja:
        // 忍者スキン
        final maskPaint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.fill;
        
        canvas.drawCircle(
          Offset(playerPosition.dx, playerPosition.dy - 5),
          10,
          maskPaint,
        );
        break;
        
      case PlayerSkin.robot:
        // ロボットスキン
        final eyePaint = Paint()
          ..color = Colors.red
          ..style = PaintingStyle.fill;
        
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(playerPosition.dx - 5, playerPosition.dy - 5),
            width: 6,
            height: 6,
          ),
          eyePaint,
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(playerPosition.dx + 5, playerPosition.dy - 5),
            width: 6,
            height: 6,
          ),
          eyePaint,
        );
        break;
        
      case PlayerSkin.astronaut:
        // 宇宙飛行士スキン
        final visorPaint = Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.fill;
        
        canvas.drawCircle(
          Offset(playerPosition.dx, playerPosition.dy),
          12,
          visorPaint,
        );
        break;
    }
  }
  
  Color _getPlayerColor() {
    switch (playerSkin) {
      case PlayerSkin.defaultSkin:
        return Colors.white;
      case PlayerSkin.ninja:
        return Colors.grey;
      case PlayerSkin.robot:
        return Colors.blueGrey;
      case PlayerSkin.astronaut:
        return Colors.white;
    }
  }
  
  void _drawObstacle(Canvas canvas, Obstacle obstacle) {
    final paint = Paint()
      ..color = _getObstacleColor(obstacle.type)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(obstacle.position, obstacle.radius, paint);
    
    // 危険マーク
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '!',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        obstacle.position.dx - textPainter.width / 2,
        obstacle.position.dy - textPainter.height / 2,
      ),
    );
  }
  
  Color _getObstacleColor(ObstacleType type) {
    switch (type) {
      case ObstacleType.normal:
        return Colors.red;
      case ObstacleType.moving:
        return Colors.orange;
      case ObstacleType.spinning:
        return Colors.purple;
    }
  }
  
  void _drawEnemy(Canvas canvas, Enemy enemy) {
    final paint = Paint()
      ..color = _getEnemyColor(enemy.type)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(enemy.position, enemy.radius, paint);
    
    // 敵の詳細
    if (enemy.isProjectile) {
      // プロジェクトイル（火の玉など）
      final innerPaint = Paint()
        ..color = Colors.orange
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(enemy.position, enemy.radius * 0.7, innerPaint);
    } else {
      // 通常の敵
      final eyePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        Offset(enemy.position.dx - 5, enemy.position.dy - 5),
        3,
        eyePaint,
      );
      canvas.drawCircle(
        Offset(enemy.position.dx + 5, enemy.position.dy - 5),
        3,
        eyePaint,
      );
    }
  }
  
  Color _getEnemyColor(EnemyType type) {
    switch (type) {
      case EnemyType.flying:
        return Colors.purple;
      case EnemyType.ground:
        return Colors.red;
      case EnemyType.chasing:
        return Colors.orange;
    }
  }
  
  void _drawBoss(Canvas canvas, Boss boss) {
    final paint = Paint()
      ..color = _getBossColor(boss.type)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(boss.position, boss.radius, paint);
    
    // ボスの詳細
    switch (boss.type) {
      case BossType.dragon:
        // ドラゴンの特徴
        final wingPaint = Paint()
          ..color = Colors.red
          ..style = PaintingStyle.fill;
        
        // 翼
        canvas.drawCircle(
          Offset(boss.position.dx - 30, boss.position.dy - 20),
          15,
          wingPaint,
        );
        canvas.drawCircle(
          Offset(boss.position.dx + 30, boss.position.dy - 20),
          15,
          wingPaint,
        );
        
        // 目
        final eyePaint = Paint()
          ..color = Colors.yellow
          ..style = PaintingStyle.fill;
        
        canvas.drawCircle(
          Offset(boss.position.dx - 15, boss.position.dy - 10),
          5,
          eyePaint,
        );
        canvas.drawCircle(
          Offset(boss.position.dx + 15, boss.position.dy - 10),
          5,
          eyePaint,
        );
        break;
        
      case BossType.golem:
        // ゴーレムの特徴
        final detailPaint = Paint()
          ..color = Colors.grey[800]!
          ..style = PaintingStyle.fill;
        
        // 岩のテクスチャ
        canvas.drawCircle(
          Offset(boss.position.dx - 20, boss.position.dy - 15),
          10,
          detailPaint,
        );
        canvas.drawCircle(
          Offset(boss.position.dx + 20, boss.position.dy - 15),
          10,
          detailPaint,
        );
        canvas.drawCircle(
          Offset(boss.position.dx, boss.position.dy + 15),
          12,
          detailPaint,
        );
        
        // 目
        final eyePaint = Paint()
          ..color = Colors.red
          ..style = PaintingStyle.fill;
        
        canvas.drawCircle(
          Offset(boss.position.dx - 15, boss.position.dy - 10),
          5,
          eyePaint,
        );
        canvas.drawCircle(
          Offset(boss.position.dx + 15, boss.position.dy - 10),
          5,
          eyePaint,
        );
        break;
    }
  }
  
  Color _getBossColor(BossType type) {
    switch (type) {
      case BossType.dragon:
        return Colors.red;
      case BossType.golem:
        return Colors.grey;
    }
  }
  
  void _drawCoin(Canvas canvas, Coin coin) {
    final paint = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(coin.position, 15, paint);
    
    // コインマーク
    final textPainter = TextPainter(
      text: TextSpan(
        text: '¥',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        coin.position.dx - textPainter.width / 2,
        coin.position.dy - textPainter.height / 2,
      ),
    );
    
    // コインのグロー効果
    final glowPaint = Paint()
      ..color = Colors.amber.withOpacity(0.3)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    canvas.drawCircle(coin.position, 18, glowPaint);
  }
  
  void _drawPowerUp(Canvas canvas, PowerUp powerUp) {
    final paint = Paint()
      ..color = _getPowerUpColor(powerUp.type)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(powerUp.position, 20, paint);
    
    // パワーアップアイコン
    String icon;
    switch (powerUp.type) {
      case PowerUpType.speedBoost:
        icon = '⚡';
        break;
      case PowerUpType.shield:
        icon = '🛡';
        break;
      case PowerUpType.magnet:
        icon = '🧲';
        break;
      case PowerUpType.multiplier:
        icon = '✖';
        break;
      case PowerUpType.extraLife:
        icon = '❤';
        break;
    }
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: icon,
        style: const TextStyle(fontSize: 16),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        powerUp.position.dx - textPainter.width / 2,
        powerUp.position.dy - textPainter.height / 2,
      ),
    );
    
    // パワーアップのグロー効果
    final glowPaint = Paint()
      ..color = _getPowerUpColor(powerUp.type).withOpacity(0.3)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    
    canvas.drawCircle(powerUp.position, 25, glowPaint);
  }
  
  Color _getPowerUpColor(PowerUpType type) {
    switch (type) {
      case PowerUpType.speedBoost:
        return Colors.blue;
      case PowerUpType.shield:
        return Colors.yellow;
      case PowerUpType.magnet:
        return Colors.purple;
      case PowerUpType.multiplier:
        return Colors.orange;
      case PowerUpType.extraLife:
        return Colors.pink;
    }
  }
  
  Color _getLineTypeColor(LineType type) {
    switch (type) {
      case LineType.normal:
        return _getThemeColor();
      case LineType.speed:
        return Colors.blue;
      case LineType.jump:
        return Colors.green;
      case LineType.shield:
        return Colors.yellow;
      case LineType.heal:
        return Colors.pink;
    }
  }
  
  Color _getThemeColor() {
    switch (theme) {
      case GameTheme.neon:
        return Colors.cyan;
      case GameTheme.japanese:
        return Colors.red;
      case GameTheme.space:
        return Colors.purple;
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ユーティリティ拡張
extension OffsetExtensions on Offset {
  Offset get normalized => distance > 0 ? this / distance : this;
}