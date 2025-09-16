
import 'package:audioplayers/audioplayers.dart';

// Manages all audio playback for the game.
class SoundProvider {
  SoundProvider() {
    _bgmPlayer = AudioPlayer();
    _bgmPlayer.setReleaseMode(ReleaseMode.loop); // Loop the background music

    _sfxPlayer = AudioPlayer();
    _sfxPlayer.setReleaseMode(
      ReleaseMode.release,
    ); // Release resources after playing a short sound
  }

  late final AudioPlayer _bgmPlayer;
  late final AudioPlayer _sfxPlayer;

  static const String _bgmPath = 'assets/audio/bgm.mp3';
  static const String _jumpSfxPath = 'assets/audio/jump.wav';
  static const String _coinSfxPath = 'assets/audio/coin.wav';
  static const String _gameOverSfxPath = 'assets/audio/game_over.wav';

  bool _isBgmPlaying = false;
  bool _resumeAfterInterruption = false;

  Future<void> _playSfx(String assetPath) async {
    await _sfxPlayer.play(AssetSource(assetPath));
  }

  void playJumpSfx() => _playSfx(_jumpSfxPath);
  void playCoinSfx() => _playSfx(_coinSfxPath);
  void playGameOverSfx() => _playSfx(_gameOverSfxPath);

  Future<void> startBgm() async {
    await _bgmPlayer.play(AssetSource(_bgmPath));
    _isBgmPlaying = true;
    _resumeAfterInterruption = false;
  }

  Future<void> pauseBgmForInterruption() async {
    _resumeAfterInterruption = _isBgmPlaying;
    if (_isBgmPlaying) {
      await _bgmPlayer.pause();
      _isBgmPlaying = false;
    }
  }

  Future<void> resumeBgmAfterInterruption() async {
    if (_resumeAfterInterruption && !_isBgmPlaying) {
      await _bgmPlayer.resume();
      _isBgmPlaying = true;
    }
    _resumeAfterInterruption = false;
  }

  Future<void> stopBgm() async {
    await _bgmPlayer.stop();
    _isBgmPlaying = false;
    _resumeAfterInterruption = false;
  }

  void dispose() {
    _bgmPlayer.dispose();
    _sfxPlayer.dispose();
  }
}

