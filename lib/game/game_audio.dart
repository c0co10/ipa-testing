import 'package:audioplayers/audioplayers.dart';

/// Thin wrapper around [AudioPlayer] so the game never crashes if audio
/// isn't available (e.g. in widget tests).
class GameAudio {
  GameAudio._();

  static final GameAudio instance = GameAudio._();

  final AudioPlayer _music = AudioPlayer();
  final AudioPlayer _sfx = AudioPlayer();

  bool _ready = false;
  bool _muted = false;
  bool _musicStarted = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      await _sfx.setVolume(0.85);
      await _music.setVolume(0.5);
      await _music.setReleaseMode(ReleaseMode.loop);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  bool get muted => _muted;

  set muted(bool value) {
    _muted = value;
    _sfx.setVolume(value ? 0 : 0.85);
    _music.setVolume(value ? 0 : 0.5);
  }

  Future<void> startMusic() async {
    if (muted || _musicStarted || !_ready) return;
    _musicStarted = true;
    try {
      await _music.stop();
      await _music.play(AssetSource('audio/music.wav'));
    } catch (_) {}
  }

  Future<void> _play(String name, double volume) async {
    if (muted || !_ready) return;
    try {
      await _sfx.stop();
      await _sfx.play(AssetSource('audio/$name'), volume: volume);
    } catch (_) {}
  }

  Future<void> jump() => _play('jump.wav', 0.85);
  Future<void> spring() => _play('spring.wav', 1.0);
  Future<void> breakPlatform() => _play('break.wav', 0.9);
  Future<void> gameOver() => _play('gameover.wav', 1.0);
}