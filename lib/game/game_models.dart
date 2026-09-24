/// Shared constants and plain data classes for the Doodle Jump game.
library;

const double kGravity = 2200.0;
const double kJumpVelocity = -820.0;
const double kMaxFallSpeed = 1500.0;
const double kMaxHorizontalSpeed = 340.0;

const double kPlatformWidth = 64.0;
const double kPlatformHeight = 14.0;
const double kPlayerWidth = 40.0;
const double kPlayerHeight = 46.0;

const double kMinGap = 68.0;
const double kMaxGap = 112.0;
const double kCameraRatio = 0.35;
const double kMovingPlatformChance = 0.28;
const double kPlatformSpeedMin = 55.0;
const double kPlatformSpeedMax = 95.0;

/// Distance from the bottom of the screen to the starting platform's top edge.
const double kGroundFloorOffset = 100.0;

class DoodlePlatform {
  DoodlePlatform({required this.x, required this.y, this.moving = false});

  double x;
  double y;
  final bool moving;
  double vx = 0;
  int dir = 1;

  /// Advances a moving platform, bouncing it off the screen edges.
  void update(double dt, double screenWidth) {
    if (!moving) return;
    x += dir * vx * dt;
    if (x <= 0) {
      x = 0;
      dir = 1;
    } else if (x >= screenWidth - kPlatformWidth) {
      x = screenWidth - kPlatformWidth;
      dir = -1;
    }
  }
}

class DoodlePlayer {
  double x = 0;
  double y = 0;
  double vx = 0;
  double vy = 0;
  bool facingRight = true;
}

enum GameStatus { ready, playing, dead }

class GameState {
  double screenWidth = 0;
  double screenHeight = 0;

  /// World Y that sits at the top of the screen. Decreases as the player climbs.
  double shift = 0;

  /// Drifts the decorative clouds horizontally.
  double cloudPhase = 0;

  int score = 0;
  int best = 0;
  int moveDir = 0;
  GameStatus status = GameStatus.ready;

  final DoodlePlayer player = DoodlePlayer();
  final List<DoodlePlatform> platforms = <DoodlePlatform>[];
}