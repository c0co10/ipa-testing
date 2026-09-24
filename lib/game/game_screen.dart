import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_audio.dart';
import 'game_models.dart';
import 'game_painter.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  final GameState _state = GameState();
  final GameAudio _audio = GameAudio.instance;
  final math.Random _rng = math.Random();

  late final Ticker _ticker;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  Duration _lastTick = Duration.zero;
  double _topCursorY = 0;
  bool _sized = false;
  bool _leftHeld = false;
  bool _rightHeld = false;
  bool _tiltAvailable = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _loadBestScore();
    _initSensors();
    _audio.init();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _accelSub?.cancel();
    super.dispose();
  }

  Future<void> _loadBestScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final best = prefs.getInt('bestScore') ?? 0;
      if (mounted) {
        setState(() => _state.best = best);
      }
    } catch (_) {}
  }

  void _saveBestScore(int value) {
    try {
      SharedPreferences.getInstance().then((p) => p.setInt('bestScore', value));
    } catch (_) {}
  }

  void _initSensors() {
    try {
      _accelSub = accelerometerEventStream().listen(
        (event) {
          _tiltAvailable = true;
          // Tilting the phone right gives a negative x (gravity vector flips),
          // so negate to move the doodle right when you tilt right.
          _state.tilt = (-event.x / 9.81).clamp(-1.0, 1.0);
        },
        onError: (_) {
          _tiltAvailable = false;
          _state.tilt = 0;
        },
        cancelOnError: true,
      );
    } catch (_) {
      _tiltAvailable = false;
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1000000;
    _lastTick = elapsed;
    _update(dt.clamp(0.0, 1.0 / 30.0));
    setState(() {});
  }

  void _initSize(Size size) {
    if (_sized) return;
    _sized = true;
    _state.screenWidth = size.width;
    _state.screenHeight = size.height;
    _resetGame();
  }

  double _gap() => kMinGap + _rng.nextDouble() * (kMaxGap - kMinGap);

  DoodlePlatform _makePlatform(
    double y, {
    bool safe = false,
  }) {
    final moving = !safe && _rng.nextDouble() < kMovingPlatformChance;
    final breakable = !safe && _rng.nextDouble() < kBreakableChance;
    final hasSpring = !safe &&
        !breakable &&
        _rng.nextDouble() < kSpringChance;
    final platform = DoodlePlatform(
      x: _rng.nextDouble() * (_state.screenWidth - kPlatformWidth),
      y: y,
      moving: moving,
      breakable: breakable,
      hasSpring: hasSpring,
    );
    if (moving) {
      platform.vx = kPlatformSpeedMin +
          _rng.nextDouble() * (kPlatformSpeedMax - kPlatformSpeedMin);
      platform.dir = _rng.nextBool() ? 1 : -1;
    }
    return platform;
  }

  void _resetGame() {
    final w = _state.screenWidth;

    _state.platforms.clear();
    _state.particles.clear();
    _state.score = 0;
    _state.shift = 0;
    _state.moveDir = 0;
    _state.tilt = 0;
    _state.shake = 0;
    _state.banner = null;
    _state.lastBannerScore = 0;
    _state.time = 0;
    _leftHeld = false;
    _rightHeld = false;

    final bottomY = _state.screenHeight - kGroundFloorOffset;
    _state.platforms.add(
      DoodlePlatform(
        x: (w - kPlatformWidth) / 2,
        y: bottomY,
        moving: false,
        breakable: false,
        hasSpring: false,
      ),
    );

    var cursor = bottomY;
    var safeCount = 0;
    while (cursor > -kMaxGap) {
      cursor -= _gap();
      final safe = safeCount < 4;
      _state.platforms.add(_makePlatform(cursor, safe: safe));
      safeCount++;
    }
    _topCursorY = cursor;

    _state.player
      ..x = (w - kPlayerWidth) / 2
      ..y = bottomY - kPlayerHeight - 26.0
      ..vx = 0
      ..vy = 0
      ..facingRight = true;
  }

  void _startGame() {
    if (_state.status == GameStatus.ready) {
      setState(() {
        _state.status = GameStatus.playing;
        _state.time = 0;
      });
      _audio.startMusic();
    } else if (_state.status == GameStatus.dead) {
      setState(() {
        _resetGame();
        _state.status = GameStatus.playing;
      });
      _audio.startMusic();
    }
  }

  void _toggleSound() {
    setState(() {
      _state.soundOn = !_state.soundOn;
      _audio.muted = !_state.soundOn;
    });
    try {
      SharedPreferences.getInstance()
          .then((p) => p.setBool('soundOn', _state.soundOn));
    } catch (_) {}
  }

  void _burst(
    double x,
    double y,
    Color color,
    int count,
    double speed, {
    double upward = 120,
  }) {
    final list = _state.particles;
    for (var i = 0; i < count; i++) {
      if (list.length >= kMaxParticles) break;
      final angle = _rng.nextDouble() * 2 * math.pi;
      final spd = speed * (0.4 + _rng.nextDouble());
      list.add(
        Particle(
          x: x + (_rng.nextDouble() - 0.5) * 10,
          y: y,
          vx: math.cos(angle) * spd,
          vy: math.sin(angle) * spd - upward,
          life: 0.35 + _rng.nextDouble() * 0.35,
          maxLife: 0.7,
          size: 2.2 + _rng.nextDouble() * 2.2,
          color: color,
        ),
      );
    }
  }

  void _update(double dt) {
    if (_state.status != GameStatus.playing || dt <= 0) return;

    _state.time += dt;
    if (_state.bannerTimer > 0) {
      _state.bannerTimer -= dt;
      if (_state.bannerTimer <= 0) _state.banner = null;
    }

    // Screen shake decays.
    if (_state.shake > 0) {
      _state.shake -= dt * 26;
      if (_state.shake <= 0) _state.shake = 0;
      if (_state.shake > 0) {
        _state.shakeX = (_rng.nextDouble() - 0.5) * 2 * _state.shake;
        _state.shakeY = (_rng.nextDouble() - 0.5) * 2 * _state.shake;
      } else {
        _state.shakeX = 0;
        _state.shakeY = 0;
      }
    }

    final player = _state.player;

    player.vy += kGravity * dt;
    if (player.vy > kMaxFallSpeed) player.vy = kMaxFallSpeed;

    final target = _state.moveDir != 0
        ? _state.moveDir.toDouble()
        : (_tiltAvailable ? _state.tilt : 0);
    player.vx += (target * kMaxHorizontalSpeed - player.vx) *
        math.min(1.0, 10.0 * dt);
    player.x += player.vx * dt;
    if (player.x > _state.screenWidth) {
      player.x -= _state.screenWidth + kPlayerWidth;
    } else if (player.x < -kPlayerWidth) {
      player.x += _state.screenWidth + kPlayerWidth;
    }
    if (target != 0) player.facingRight = target > 0;

    // Rocket trail while soaring.
    if (player.vy < -250) {
      _burst(
        player.x + kPlayerWidth / 2,
        player.y + kPlayerHeight - 2,
        Colors.white.withOpacity(0.6),
        1,
        20,
        upward: 0,
      );
    }

    final prevBottom = player.y + kPlayerHeight;
    player.y += player.vy * dt;

    if (player.vy > 0) {
      final bottom = player.y + kPlayerHeight;
      final centerX = player.x + kPlayerWidth / 2;
      for (final platform in _state.platforms) {
        if (platform.isBroken) continue;
        final plBottom = platform.y; // top edge of platform (y is top)
        if (prevBottom <= plBottom && bottom >= plBottom) {
          // Only count a real landing: the player's horizontal center must
          // be over the platform. A 1px corner graze is not a jump.
          final centerOver = centerX > platform.x &&
              centerX < platform.x + kPlatformWidth;
          if (!centerOver) continue;
          if (platform.hasSpring) {
            _audio.spring();
            _state.shake = math.max(_state.shake, 5);
            _burst(
              platform.x + kPlatformWidth / 2,
              plBottom,
              GamePalette.springRed,
              12,
              180,
              upward: 60,
            );
            player.y = plBottom - kPlayerHeight;
            player.vy = kSpringJumpVelocity;
            platform.hasSpring = false;
            break;
          }
          _audio.jump();
          player.y = plBottom - kPlayerHeight;
          player.vy = kJumpVelocity;
          if (platform.breakable && !platform.isBroken) {
            platform.isBroken = true;
            _audio.breakPlatform();
            _state.shake = math.max(_state.shake, 4);
            _burst(
              platform.x + kPlatformWidth / 2,
              plBottom,
              GamePalette.breakableBottom,
              10,
              140,
              upward: 140,
            );
          } else {
            final color = platform.moving
                ? GamePalette.movingTop
                : GamePalette.platformTop;
            _burst(
              platform.x + kPlatformWidth / 2,
              plBottom,
              color,
              6,
              90,
              upward: 40,
            );
          }
          break;
        }
      }
    }

    for (final platform in _state.platforms) {
      platform.update(dt, _state.screenWidth);
    }

    // Age out particles.
    _state.particles.removeWhere((p) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += 500 * dt;
      p.life -= dt;
      return p.life <= 0;
    });

    final screenY = player.y - _state.shift;
    if (screenY < _state.screenHeight * kCameraRatio) {
      _state.shift = player.y - _state.screenHeight * kCameraRatio;
      final climbed = math.max(0, ((-_state.shift) / 90.0).floor());
      if (climbed > _state.score) {
        _state.score = climbed;
        if (climbed > 0 &&
            climbed % kScoreStep == 0 &&
            climbed > _state.lastBannerScore) {
          _state.lastBannerScore = climbed;
          _state.banner = '+${_formatScore(climbed.toInt())}';
          _state.bannerTimer = 1.4;
        }
      }
    }

    while (_topCursorY - kMaxGap > _state.shift) {
      _topCursorY -= _gap();
      _state.platforms.add(_makePlatform(_topCursorY));
    }

    _state.platforms.removeWhere(
      (platform) => platform.y - _state.shift > _state.screenHeight + 80.0,
    );

    if (screenY > _state.screenHeight + kPlayerHeight * 2) {
      if (_state.score > _state.best) {
        _state.best = _state.score;
        _saveBestScore(_state.best);
      }
      _audio.gameOver();
      _state.shake = 6;
      setState(() => _state.status = GameStatus.dead);
      _state.shake = 0;
      _lastTick = Duration.zero;
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (event is KeyDownEvent) {
      if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.enter) {
        _startGame();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowLeft) {
        _leftHeld = true;
        _state.moveDir = _rightHeld ? 1 : -1;
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        _rightHeld = true;
        _state.moveDir = _leftHeld ? -1 : 1;
        return KeyEventResult.handled;
      }
    } else if (event is KeyUpEvent) {
      if (key == LogicalKeyboardKey.arrowLeft) {
        _leftHeld = false;
        _state.moveDir = _rightHeld ? 1 : 0;
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        _rightHeld = false;
        _state.moveDir = _leftHeld ? -1 : 0;
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_state.status != GameStatus.playing) {
      _startGame();
      return;
    }
    _state.moveDir = event.localPosition.dx < _state.screenWidth / 2 ? -1 : 1;
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_state.status != GameStatus.playing) return;
    if (_leftHeld || _rightHeld) return;
    _state.moveDir = 0;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    _initSize(size);

    return Scaffold(
      backgroundColor: GamePalette.skyTop,
      body: Focus(
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Listener(
          onPointerDown: _onPointerDown,
          onPointerUp: _onPointerUp,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: GamePainter(_state)),
              _buildHud(),
              if (_state.status == GameStatus.ready) _buildReadyOverlay(),
              if (_state.status == GameStatus.dead) _buildGameOverOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHud() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            children: [
              Text(
                _formatScore(_state.score),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  shadows: [
                    Shadow(
                      blurRadius: 8,
                      color: Colors.black26,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              if (_state.best > 0)
                Text(
                  'BEST ${_formatScore(_state.best)}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadyOverlay() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Doodle Jump',
            style: TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  blurRadius: 14,
                  color: Colors.black38,
                  offset: Offset(0, 3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _startGame,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF2E7D32),
              padding:
                  const EdgeInsets.symmetric(horizontal: 46, vertical: 16),
              textStyle: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(40),
              ),
            ),
            child: const Text('Tap to Start'),
          ),
          const SizedBox(height: 18),
          Text(
            _tiltAvailable
                ? 'Tilt your phone to steer'
                : 'Hold the left / right side of the screen to steer',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              shadows: const [
                Shadow(blurRadius: 6, color: Colors.black26),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ride the springs. Avoid cracked platforms!',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 26),
          _buildSoundToggle(),
        ],
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    final isNewBest = _state.score >= _state.best &&
        _state.score > 0 &&
        _state.best > 0;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 44),
        padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 26),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Game Over',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (isNewBest)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'NEW BEST!',
                  style: TextStyle(
                    color: const Color(0xFFFFD54F),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Score   ${_formatScore(_state.score)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Best   ${_formatScore(_state.best)}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _startGame,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 13),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: const Text('Play Again'),
            ),
            const SizedBox(height: 14),
            _buildSoundToggle(),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundToggle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _state.soundOn ? Icons.music_note : Icons.music_off,
          color: Colors.white.withOpacity(0.9),
          size: 18,
        ),
        const SizedBox(width: 8),
        Switch(
          value: _state.soundOn,
          onChanged: (_) => _toggleSound(),
          activeThumbColor: Colors.white,
          activeTrackColor: const Color(0xFF2E7D32),
          inactiveThumbColor: Colors.white24,
        ),
      ],
    );
  }

  String _formatScore(int value) => value.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (match) => '${match[1]},',
      );
}