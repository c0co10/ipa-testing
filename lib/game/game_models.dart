import 'dart:ui' show Color;

/// Shared constants and plain data classes for the Doodle Jump game.
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

/// Springs — big bouncy boosters resting on top of some platforms.
const double kSpringWidth = 18.0;
const double kSpringHeight = 22.0;
const double kSpringJumpVelocity = -1350.0;
const double kSpringChance = 0.13;

/// Cracked brown platforms that break shortly after being landed on.
const double kBreakableChance = 0.18;
const double kBreakableGravity = 1400.0;
const double kBreakableDelay = 0.25;

const int kMaxParticles = 160;

/// Score milestone that flashes a banner (+500, +1000, ...).
const double kScoreStep = 500.0;

class DoodlePlatform {
  DoodlePlatform({
    required this.x,
    required this.y,
    this.moving = false,
    this.breakable = false,
    this.hasSpring = false,
  });

  double x;
  double y;
  final bool moving;
  bool breakable;
  bool hasSpring;
  double vx = 0;
  int dir = 1;

  bool isBroken = false;
  double crumbleTimer = 0;
  double fallVy = 0;
  double rot = 0;

  /// Advances a platform. Moving platforms slide side to side; broken
  /// platforms crumble and fall off the screen with a spin.
  void update(double dt, double screenWidth) {
    if (isBroken) {
      crumbleTimer = 0;
      fallVy += kBreakableGravity * dt;
      y += fallVy * dt;
      rot += dt * 3.0;
      if (fallVy > 900) fallVy = 900;
      return;
    }
    if (moving) {
      x += dir * vx * dt;
      if (x <= 0) {
        x = 0;
        dir = 1;
      } else if (x >= screenWidth - kPlatformWidth) {
        x = screenWidth - kPlatformWidth;
        dir = -1;
      }
    }
    if (breakable) {
      crumbleTimer += dt;
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

class Particle {
  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.maxLife,
    required this.size,
    required this.color,
  });

  double x;
  double y;
  double vx;
  double vy;
  double life;
  final double maxLife;
  final double size;
  final Color color;
}

enum GameStatus { ready, playing, dead }

class GameState {
  double screenWidth = 0;
  double screenHeight = 0;

  /// World Y that sits at the top of the screen. Decreases as the player climbs.
  double shift = 0;

  /// Drifts the decorative clouds horizontally / drives idle sprite animation.
  double time = 0;

  int score = 0;
  int best = 0;

  /// -1..1 tilt from the accelerometer (negative = move left).
  double tilt = 0;

  /// Manual steering (touch halves / arrow keys). 0 means tilt is used.
  int moveDir = 0;

  GameStatus status = GameStatus.ready;
  final DoodlePlayer player = DoodlePlayer();
  final List<DoodlePlatform> platforms = <DoodlePlatform>[];
  final List<Particle> particles = <Particle>[];

  double shake = 0;
  double shakeX = 0;
  double shakeY = 0;

  String? banner;
  double bannerTimer = 0;
  int lastBannerScore = 0;

  bool soundOn = true;
}

/// Palette shared by the painter.
class GamePalette {
  GamePalette._();

  static const Color skyTop = Color(0xFF5FC4FF);
  static const Color skyBottom = Color(0xFFD6F2FF);
  static const Color sunGlow = Color(0xFFFFF59D);
  static const Color sunCore = Color(0xFFFFE082);
  static const Color platformTop = Color(0xFF66BB6A);
  static const Color platformBottom = Color(0xFF2E7D32);
  static const Color movingTop = Color(0xFF4FC3F7);
  static const Color movingBottom = Color(0xFF0288D1);
  static const Color breakableTop = Color(0xFFB48A5C);
  static const Color breakableBottom = Color(0xFF6D4C2F);
  static const Color springRed = Color(0xFFE53935);
  static const Color springDark = Color(0xFFB71C1C);
  static const Color doodleGreen = Color(0xFF43A047);
  static const Color doodleDark = Color(0xFF2E7D32);
  static const Color doodleDeep = Color(0xFF1B5E20);
  static const Color doodleBelly = Color(0xFF81C784);
}