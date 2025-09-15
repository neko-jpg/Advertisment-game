
import 'package:audioplayers/audioplayers.dart';

// Manages all audio playback for the game.
class SoundProvider {
  late final AudioPlayer _bgmPlayer;
  late final AudioPlayer _sfxPlayer;
  
  final String _bgmPath = 'audio/bgm.mp3';
  final String _jumpSfxPath = 'audio/jump.wav';
  final String _coinSfxPath = 'audio/coin.wav';
  final String _gameOverSfxPath = 'audio/game_over.wav';

  SoundProvider() {
    _bgmPlayer = AudioPlayer();
    _bgmPlayer.setReleaseMode(ReleaseMode.loop); // Loop the background music

    _sfxPlayer = AudioPlayer();
    _sfxPlayer.setReleaseMode(ReleaseMode.release); // Release resources after playing a short sound
  }

  Future<void> _playSfx(String assetPath) async {
    await _sfxPlayer.play(AssetSource(assetPath));
  }

  void playJumpSfx() => _playSfx(_jumpSfxPath);
  void playCoinSfx() => _playSfx(_coinSfxPath);
  void playGameOverSfx() => _playSfx(_gameOverSfxPath);

  Future<void> startBgm() async {
    await _bgmPlayer.play(AssetSource(_bgmPath));
  }

  void stopBgm() {
    _bgmPlayer.stop();
  }

  void dispose() {
    _bgmPlayer.dispose();
    _sfxPlayer.dispose();
  }
}

