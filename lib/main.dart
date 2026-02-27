import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:audioplayers/audioplayers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const BouncerApp());
}

enum Difficulty { easy, normal, hard }

class BouncerApp extends StatelessWidget {
  const BouncerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF050816),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF3366),
          brightness: Brightness.dark,
        ),
        textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.white)),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const MainMenuScreen(),
    );
  }
}

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  Difficulty _selected = Difficulty.normal;

  String _difficultyLabel(Difficulty d) {
    switch (d) {
      case Difficulty.easy:
        return 'Easy';
      case Difficulty.normal:
        return 'Normal';
      case Difficulty.hard:
        return 'Hard';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'BOUNCER',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Select difficulty',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: Difficulty.values.map((d) {
                  final bool active = d == _selected;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(_difficultyLabel(d)),
                      selected: active,
                      onSelected: (_) {
                        setState(() {
                          _selected = d;
                        });
                      },
                      selectedColor: const Color(0xFFFF3366),
                      backgroundColor: Colors.white10,
                      labelStyle: TextStyle(
                        color: active ? Colors.white : Colors.white70,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BouncerGame(difficulty: _selected),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'Start',
                  style: TextStyle(fontSize: 16, letterSpacing: 1.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Power-ups
class PowerUp {
  double x; // centre
  double y;
  final double radius;
  final PowerUpType type;
  double vY = 80;

  PowerUp({
    required this.x,
    required this.y,
    required this.radius,
    required this.type,
  });
}

enum PowerUpType { widenPaddle, slowBall }

class BouncerGame extends StatefulWidget {
  final Difficulty difficulty;

  const BouncerGame({super.key, required this.difficulty});

  @override
  State<BouncerGame> createState() => _BouncerGameState();
}

class _BouncerGameState extends State<BouncerGame>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late final AudioPlayer _sfx;

  // Size screen
  late double screenWidth;
  late double screenHeight;

  // Ball
  double ballX = 0;
  double ballY = 0;
  final double ballRadius = 10;
  double ballVX = 150;
  double ballVY = -150;

  // Paddle
  double paddleWidth = 80;
  final double paddleHeight = 16;
  double paddleY = 0;
  double paddleX = 0;

  // Accelerometer
  StreamSubscription<AccelerometerEvent>? _accelSub;
  AccelerometerEvent? _lastAccel; // как в примере: храним последнее событие
  double accelX = 0;

  // Blocks
  final int rows = 4;
  final int cols = 6;
  final double blockHeight = 20;
  final double blockGap = 6;
  late double blockWidth;
  late List<List<bool>> blocksAlive;

  bool isRunning = true;
  bool isSoundOn = true;
  String? statusText;
  int score = 0;

  // Power-ups
  final List<PowerUp> powerUps = [];
  final double powerUpFallSpeed = 120; // px / s
  final double powerUpRadius = 10;
  final Random _rng = Random();
  bool hasWidenPaddle = false;
  bool hasSlowBall = false;
  double widenPaddleTimeLeft = 0; // в секундах
  double slowBallTimeLeft = 0;

  // Base values 
  double baseBallVX = 150;
  double baseBallVY = -150;
  double basePaddleWidth = 80;

  void _applyDifficulty() {
    switch (widget.difficulty) {
      case Difficulty.easy:
        baseBallVX = 120;
        baseBallVY = -120;
        basePaddleWidth = 100;
        break;
      case Difficulty.normal:
        baseBallVX = 150;
        baseBallVY = -150;
        basePaddleWidth = 80;
        break;
      case Difficulty.hard:
        baseBallVX = 190;
        baseBallVY = -190;
        basePaddleWidth = 65;
        break;
    }

    // If power-ups are active, keep their effects on top of the difficulty
    if (widenPaddleTimeLeft <= 0) {
      paddleWidth = basePaddleWidth;
    }
    if (slowBallTimeLeft <= 0) {
      ballVX = baseBallVX;
      ballVY = baseBallVY;
    }
  }

  Future<void> _playHit() async {
    if (!isSoundOn) return;
    await _sfx.play(AssetSource('sounds/hit.wav'));
  }

  Future<void> _playLose() async {
    if (!isSoundOn) return;
    await _sfx.play(AssetSource('sounds/lose.wav'));
  }

  Future<void> _playWin() async {
    if (!isSoundOn) return;
    await _sfx.play(AssetSource('sounds/win.wav'));
  }

  @override
  void initState() {
    super.initState();
    _applyDifficulty();
    _sfx = AudioPlayer();

    // Blocks 
    blocksAlive = List.generate(rows, (_) => List.generate(cols, (_) => true));

    // Size screen (пока так, потом будет в LayoutBuilder) — нужно для начальных позиций и расчёта коллизий
    screenWidth = 400;
    screenHeight = 800;
    ballX = 200;
    ballY = 400;
    paddleX = 200;

    // Animation for game loop
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1),
    )..addListener(_onTick);
    _controller.repeat();

    // Stream for accelerometer
    _accelSub = accelerometerEventStream().listen((event) {
      // не вызываем setState каждый раз, чтобы не лагало UI
      _lastAccel = event;
      accelX = event.x;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _accelSub?.cancel();
    _sfx.dispose();
    super.dispose();
  }

  void _onTick() {
    if (!mounted || !isRunning) return;

    const double dt = 1 / 60;

    setState(() {
      // Paddle
      const double paddleSpeed = 300;
      paddleX += -accelX * paddleSpeed * dt;

      final double half = paddleWidth / 2;
      paddleX = paddleX.clamp(half, screenWidth - half);

      // Ball
      ballX += ballVX * dt;
      ballY += ballVY * dt;

      // Walls
      if (ballX - ballRadius <= 0 && ballVX < 0) {
        ballX = ballRadius;
        ballVX = -ballVX;
      }
      if (ballX + ballRadius >= screenWidth && ballVX > 0) {
        ballX = screenWidth - ballRadius;
        ballVX = -ballVX;
      }
      if (ballY - ballRadius <= 0 && ballVY < 0) {
        ballY = ballRadius;
        ballVY = -ballVY;
      }

      // Down - lose
      if (ballY - ballRadius > screenHeight) {
        isRunning = false;
        statusText = 'You lost!';
        _playLose();
      }

      // Paddle collision
      final double paddleTop = paddleY;
      final double halfPaddle = paddleWidth / 2;
      final double paddleLeft = paddleX - halfPaddle;
      final double paddleRight = paddleX + halfPaddle;

      final bool hitPaddle =
          ballY + ballRadius >= paddleTop &&
          ballY - ballRadius <= paddleTop + paddleHeight &&
          ballX >= paddleLeft &&
          ballX <= paddleRight &&
          ballVY > 0;

      if (hitPaddle) {
        final double relative =
            (ballX - paddleX) / (paddleWidth / 2); // [-1, 1]
        final double speed = sqrt(ballVX * ballVX + ballVY * ballVY);
        const double maxAngle = pi / 3; // 60°
        final double angle = relative * maxAngle;

        ballVY = -speed * cos(angle);
        ballVX = speed * sin(angle);
        ballY = paddleTop - ballRadius - 1;
      }

      _handleBlocksCollision();

      if (blocksAlive.every((row) => row.every((b) => !b))) {
        isRunning = false;
        statusText = 'You Won!';
        _playWin();
      }

      // Update power-ups
      for (int i = powerUps.length - 1; i >= 0; i--) {
        final p = powerUps[i];

        // down
        p.y += powerUpFallSpeed * dt;

        // If power-up fell down the screen, remove it
        if (p.y - p.radius > screenHeight) {
          powerUps.removeAt(i);
          continue;
        }

        // Check collision with paddle
        final double halfPaddle = paddleWidth / 2;
        final double paddleLeft = paddleX - halfPaddle;
        final double paddleRight = paddleX + halfPaddle;
        final double paddleTop = paddleY;
        final double paddleBottom = paddleY + paddleHeight;

        final bool hitPaddle =
            p.x + p.radius >= paddleLeft &&
            p.x - p.radius <= paddleRight &&
            p.y + p.radius >= paddleTop &&
            p.y - p.radius <= paddleBottom;

        if (hitPaddle) {
          _applyPowerUp(p.type);
          powerUps.removeAt(i);
        }
      }

      // Timers for power-ups
      if (widenPaddleTimeLeft > 0) {
        widenPaddleTimeLeft -= dt;
        if (widenPaddleTimeLeft <= 0) {
          // effect ended, return to base paddle width for difficulty
          _applyDifficulty();
        }
      }

      if (slowBallTimeLeft > 0) {
        slowBallTimeLeft -= dt;
        if (slowBallTimeLeft <= 0) {
          // return to base ball speed for difficulty
          _applyDifficulty();
        }
      }
    });
  }

  // Color for blocks based on row (можно потом расширить, добавить градиент или что-то ещё)  
  Color _blockColorForRow(int r) {
    switch (r) {
      case 0:
        return const Color(0xFFFFD166); // yellow
      case 1:
        return const Color(0xFF06D6A0); // green
      case 2:
        return const Color(0xFF118AB2); // blue
      default:
        return const Color(0xFFEF476F); // red
    }
  }

  void _handleBlocksCollision() {
    const double hudHeight = 165;
    const double topOffset = hudHeight;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (!blocksAlive[r][c]) continue;

        final double left = c * (blockWidth + blockGap) + blockGap;
        final double top = topOffset + r * (blockHeight + blockGap);
        final double right = left + blockWidth;
        final double bottom = top + blockHeight;

        final bool overlap =
            ballX + ballRadius >= left &&
            ballX - ballRadius <= right &&
            ballY + ballRadius >= top &&
            ballY - ballRadius <= bottom;

        if (overlap) {
          blocksAlive[r][c] = false;
          score += 10;
          _playHit();

          if (_rng.nextDouble() < 0.25) {
            // 25% шанс
            // Centre of the block
            final double centerX = (left + right) / 2;
            final double centerY = (top + bottom) / 2;

            // Randomly choose power-up type
            final PowerUpType type = _rng.nextBool()
                ? PowerUpType.widenPaddle
                : PowerUpType.slowBall;

            powerUps.add(
              PowerUp(
                x: centerX,
                y: centerY,
                radius: powerUpRadius,
                type: type,
              ),
            );
          }

          final double overlapLeft = (ballX + ballRadius) - left;
          final double overlapRight = right - (ballX - ballRadius);
          final double overlapTop = (ballY + ballRadius) - top;
          final double overlapBottom = bottom - (ballY - ballRadius);

          final double minOverlap = [
            overlapLeft,
            overlapRight,
            overlapTop,
            overlapBottom,
          ].reduce(min);

          if (minOverlap == overlapLeft || minOverlap == overlapRight) {
            ballVX = -ballVX;
          } else {
            ballVY = -ballVY;
          }

          return;
        }
      }
    }
  }

  void _resetGame() {
    setState(() {
      isRunning = true;
      statusText = null;
      blocksAlive = List.generate(
        rows,
        (_) => List.generate(cols, (_) => true),
      );

      ballX = screenWidth / 2;
      ballY = screenHeight * 0.6;
      _applyDifficulty();
      paddleX = screenWidth / 2;
      score = 0;
      powerUps.clear();
      hasWidenPaddle = false;
      hasSlowBall = false;
    });
  }

  void _applyPowerUp(PowerUpType type) {
    switch (type) {
      case PowerUpType.widenPaddle:
        setState(() {
          // add 30 pixels to current width, but don't exceed 60% of screen width
          paddleWidth = min(paddleWidth + 30, screenWidth * 0.6);
          widenPaddleTimeLeft = 5; // 5 секунд действия
        });
        break;

      case PowerUpType.slowBall:
        setState(() {
          ballVX *= 0.7;
          ballVY *= 0.7;
          slowBallTimeLeft = 5; // 5 seconds duration
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        screenWidth = constraints.maxWidth;
        screenHeight = constraints.maxHeight;

        blockWidth = (screenWidth - (cols + 1) * blockGap) / cols;
        paddleY = screenHeight - 160;

        const double hudHeight = 165;
        final accelText = _lastAccel == null
            ? 'No accelerometer data'
            : 'X: ${_lastAccel!.x.toStringAsFixed(2)}, '
                  'Y: ${_lastAccel!.y.toStringAsFixed(2)}, '
                  'Z: ${_lastAccel!.z.toStringAsFixed(2)}';

        return Scaffold(
          body: Stack(
            children: [
              // Blocks
              for (int r = 0; r < rows; r++)
                for (int c = 0; c < cols; c++)
                  if (blocksAlive[r][c])
                    Positioned(
                      left: c * (blockWidth + blockGap) + blockGap,
                      top: hudHeight + r * (blockHeight + blockGap),
                      width: blockWidth,
                      height: blockHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              _blockColorForRow(
                                r,
                              ).withAlpha((0.9 * 255).toInt()),
                              _blockColorForRow(r),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(
                                (0.4 * 255).toInt(),
                              ),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),

              // Power-ups
              for (final p in powerUps)
                Positioned(
                  left: p.x - p.radius,
                  top: p.y - p.radius,
                  width: p.radius * 2,
                  height: p.radius * 2,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withAlpha((0.4 * 255).toInt()),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((0.5 * 255).toInt()),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      p.type == PowerUpType.widenPaddle ? '⬅️➡️' : '🐌',
                      style: TextStyle(fontSize: p.radius + 6),
                    ),
                  ),
                ),

              // Ball
              Positioned(
                left: ballX - ballRadius,
                top: ballY - ballRadius,
                width: ballRadius * 2,
                height: ballRadius * 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withAlpha((0.7 * 255).toInt()),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),

              // Paddle
              Positioned(
                left: paddleX - paddleWidth / 2,
                top: paddleY,
                width: paddleWidth,
                height: paddleHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3366),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(
                          0xFFFF3366,
                        ).withAlpha((0.6 * 255).toInt()),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),

              // Game over / win overlay
              if (statusText != null)
                Container(
                  color: Colors.black.withAlpha((0.5 * 255).toInt()),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          statusText!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _resetGame,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF3366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text('Play again'),
                        ),
                      ],
                    ),
                  ),
                ),

              // HUD
              Positioned(
                left: 16,
                top: 16,
                right: 16,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. The first row: Title + pause/play + sound icons
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'BOUNCER',
                            style: TextStyle(
                              color: Colors.white.withAlpha(
                                (0.9 * 255).toInt(),
                              ),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(
                              isRunning ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                isRunning = !isRunning;
                              });
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              isSoundOn ? Icons.volume_up : Icons.volume_off,
                              color: Colors.white,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                isSoundOn = !isSoundOn;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // 2. The second row: Score (можно потом добавить количество жизней или что-то ещё)
                      Row(
                        children: [
                          Text(
                            'Score: $score',
                            style: TextStyle(
                              color: Colors.white.withAlpha(
                                (0.9 * 255).toInt(),
                              ),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // 3. The third row: Instructions + accelerometer data (можно потом убрать, или сделать более лаконично, или добавить там что-то ещё)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tilt to move',
                            style: TextStyle(
                              color: Colors.white.withAlpha(
                                (0.7 * 255).toInt(),
                              ),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            accelText,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: Colors.white.withAlpha(
                                (0.5 * 255).toInt(),
                              ),
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
