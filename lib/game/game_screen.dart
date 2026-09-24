import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

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
  final math.Random _rng = math.Random();

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _topCursorY = 0;
  bool _sized = false;
  bool _leftHeld = false;
  bool _rightHeld = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
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

  void _resetGame() {
    final w = _state.screenWidth;

    _state.platforms.clear();
    _state.score = 0;
    _state.shift = 0;
    _state.moveDir = 0;
    _leftHeld = false;
    _rightHeld = false;

    final bottomY = _state.screenHeight - kGroundFloorOffset;
    _state.platforms.add(
      DoodlePlatform(x: (w - kPlatformWidth) / 2, y: bottomY),
    );

    var cursor = bottomY;
    while (cursor > -kMaxGap) {
      cursor -= _gap();
      _state.platforms.add(_makePlatform(cursor));
    }
    _topCursorY = cursor;

    _state.player
      ..x = (w - kPlayerWidth) / 2
      ..y = bottomY - kPlayerHeight - 26.0
      ..vx = 0
      ..vy = 0
      ..facingRight = true;
  }

  double _gap() => kMinGap + _rng.nextDouble() * (kMaxGap - kMinGap);

  DoodlePlatform _makePlatform(double y) {
    final moving = _rng.nextDouble() < kMovingPlatformChance;
    final platform = DoodlePlatform(
      x: _rng.nextDouble() * (_state.screenWidth - kPlatformWidth),
      y: y,
      moving: moving,
    );
    if (moving) {
      platform.vx =
          kPlatformSpeedMin + _rng.nextDouble() * (kPlatformSpeedMax - kPlatformSpeedMin);
      platform.dir = _rng.nextBool() ? 1 : -1;
    }
    return platform;
  }

  void _startGame() {
    if (_state.status == GameStatus.ready) {
      setState(() => _state.status = GameStatus.playing);
    } else if (_state.status == GameStatus.dead) {
      setState(() {
        _resetGame();
        _state.status = GameStatus.playing;
      });
    }
  }

  void _update(double dt) {
    if (_state.status != GameStatus.playing || dt <= 0) return;

    _state.cloudPhase += dt;

    final player = _state.player;

    player.vy += kGravity * dt;
    if (player.vy > kMaxFallSpeed) player.vy = kMaxFallSpeed;

    final target = kMaxHorizontalSpeed * _state.moveDir;
    player.vx += (target - player.vx) * math.min(1.0, 8.0 * dt);
    player.x += player.vx * dt;
    if (player.x > _state.screenWidth) {
      player.x -= _state.screenWidth + kPlayerWidth;
    } else if (player.x < -kPlayerWidth) {
      player.x += _state.screenWidth + kPlayerWidth;
    }
    if (target != 0) player.facingRight = target > 0;

    final prevBottom = player.y + kPlayerHeight;
    player.y += player.vy * dt;

    if (player.vy > 0) {
      final bottom = player.y + kPlayerHeight;
      for (final platform in _state.platforms) {
        if (prevBottom <= platform.y && bottom >= platform.y) {
          if (player.x + kPlayerWidth > platform.x &&
              player.x < platform.x + kPlatformWidth) {
            player.y = platform.y - kPlayerHeight;
            player.vy = kJumpVelocity;
            break;
          }
        }
      }
    }

    for (final platform in _state.platforms) {
      platform.update(dt, _state.screenWidth);
    }

    final screenY = player.y - _state.shift;
    if (screenY < _state.screenHeight * kCameraRatio) {
      _state.shift = player.y - _state.screenHeight * kCameraRatio;
      final climbed = math.max(0, ((-_state.shift) / 90.0).floor());
      if (climbed > _state.score) _state.score = climbed;
    }

    while (_topCursorY - kMaxGap > _state.shift) {
      _topCursorY -= _gap();
      _state.platforms.add(_makePlatform(_topCursorY));
    }

    _state.platforms.removeWhere(
      (platform) => platform.y - _state.shift > _state.screenHeight + 60.0,
    );

    if (screenY > _state.screenHeight + kPlayerHeight * 2) {
      if (_state.score > _state.best) _state.best = _state.score;
      setState(() => _state.status = GameStatus.dead);
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
      backgroundColor: const Color(0xFF6EC6FF),
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
      top: 28,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Text(
            _formatScore(_state.score),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              shadows: [
                Shadow(
                  blurRadius: 8,
                  color: Colors.black26,
                  offset: Offset(0, 2),
                ),
              ],
            ),
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
                Shadow(blurRadius: 14, color: Colors.black38, offset: Offset(0, 3)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Tap or press Space to start',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              shadows: const [
                Shadow(blurRadius: 8, color: Colors.black26),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Hold the left / right side of the screen to steer',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 48),
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
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
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 18),
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
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _startGame,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Play Again'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatScore(int value) => value.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (match) => '${match[1]},',
      );
}