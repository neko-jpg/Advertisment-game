import 'package:audioplayers/audioplayers.dart';

import 'gen/assets.gen.dart';

// Manages all audio playback for the game.
class SoundProvider {
  SoundProvider({bool enableAudio = true}) : _enabled = enableAudio {
    if (enableAudio) {
      _bgmPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.loop);
      _sfxPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.release);
    }
  }

  final bool _enabled;
  AudioPlayer? _bgmPlayer;
  AudioPlayer? _sfxPlayer;

  bool _isBgmPlaying = false;
  bool _resumeAfterInterruption = false;

  Future<void> _playSfx(String assetPath) async {
    if (!_enabled) {
      return;
    }
    await _sfxPlayer!.play(AssetSource(assetPath));
  }

  void playJumpSfx() => _playSfx(Assets.audio.jump);
  void playCoinSfx() => _playSfx(Assets.audio.coin);
  void playGameOverSfx() => _playSfx(Assets.audio.gameOver);

  Future<void> startBgm() async {
    if (!_enabled) {
      return;
    }
    await _bgmPlayer!.play(AssetSource(Assets.audio.bgm));
    _isBgmPlaying = true;
    _resumeAfterInterruption = false;
  }

  Future<void> pauseBgmForInterruption() async {
    if (!_enabled) {
      return;
    }
    _resumeAfterInterruption = _isBgmPlaying;
    if (_isBgmPlaying) {
      await _bgmPlayer!.pause();
      _isBgmPlaying = false;
    }
  }

  Future<void> resumeBgmAfterInterruption() async {
    if (!_enabled) {
      return;
    }
    if (_resumeAfterInterruption && !_isBgmPlaying) {
      await _bgmPlayer!.resume();
      _isBgmPlaying = true;
    }
    _resumeAfterInterruption = false;
  }

  Future<void> stopBgm() async {
    if (!_enabled) {
      return;
    }
    await _bgmPlayer!.stop();
    _isBgmPlaying = false;
    _resumeAfterInterruption = false;
  }

  void dispose() {
    if (!_enabled) {
      return;
    }
    _bgmPlayer?.dispose();
    _sfxPlayer?.dispose();
  }
}
