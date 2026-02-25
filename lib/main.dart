import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  runApp(const BouncerApp());
}

class BouncerApp extends StatelessWidget {
  const BouncerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BouncerGame(),
    );
  }
}

class BouncerGame extends StatefulWidget {
  const BouncerGame({super.key});

  @override
  State<BouncerGame> createState() => _BouncerGameState();
}

class _BouncerGameState extends State<BouncerGame>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Игровое поле
  late double screenWidth;
  late double screenHeight;

  // Мяч
  double ballX = 0;
  double ballY = 0;
  double ballRadius = 10;
  double ballVX = 150;
  double ballVY = -150;

  // Платформа
  double paddleWidth = 80;
  double paddleHeight = 16;
  double paddleY = 0;
  double paddleX = 0;

  // Акселерометр
  StreamSubscription<AccelerometerEvent>? _accelSub;
  double accelX = 0;

  // Блоки
  final int rows = 4;
  final int cols = 6;
  final double blockHeight = 20;
  final double blockGap = 6;
  late double blockWidth;
  late List<List<bool>> blocksAlive;

  bool isRunning = true;
  String? statusText;

  @override
  void initState() {
    super.initState();

    blocksAlive = List.generate(rows, (_) => List.generate(cols, (_) => true));

    // Стартовые значения
    screenWidth = 400;
    screenHeight = 800;
    ballX = 200;
    ballY = 400;
    paddleX = 200;

    // Контроллер анимации, ~60 fps
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1),
    )..addListener(_onTick);
    _controller.repeat();

    _accelSub =
        accelerometerEventStream().listen((AccelerometerEvent event) {
      accelX = event.x;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _accelSub?.cancel();
    super.dispose();
  }

  void _onTick() {
    if (!mounted || !isRunning) return;

    const double dt = 1 / 60;

    setState(() {
      // Платформа
      const double paddleSpeed = 300;
      paddleX += -accelX * paddleSpeed * dt;

      final double half = paddleWidth / 2;
      paddleX = paddleX.clamp(half, screenWidth - half);

      // Мяч
      ballX += ballVX * dt;
      ballY += ballVY * dt;

      // Стены
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

      // Низ — проигрыш
      if (ballY - ballRadius > screenHeight) {
        isRunning = false;
        statusText = 'You lost!';
      }

      // Платформа
      final double paddleTop = paddleY;
      final double paddleLeft = paddleX - half;
      final double paddleRight = paddleX + half;

      final bool hitPaddle = ballY + ballRadius >= paddleTop &&
          ballY - ballRadius <= paddleTop + paddleHeight &&
          ballX >= paddleLeft &&
          ballX <= paddleRight &&
          ballVY > 0;

      if (hitPaddle) {
        final double relative =
            (ballX - paddleX) / (paddleWidth / 2);
        final double speed = sqrt(ballVX * ballVX + ballVY * ballVY);
        final double maxAngle = pi / 3;
        final double angle = relative * maxAngle;

        ballVY = -speed * cos(angle);
        ballVX = speed * sin(angle);
        ballY = paddleTop - ballRadius - 1;
      }

      _handleBlocksCollision();

      if (blocksAlive.every((row) => row.every((b) => !b))) {
        isRunning = false;
        statusText = 'You Won!';
      }
    });
  }

  void _handleBlocksCollision() {
    const double topOffset = 40;
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

          final double overlapLeft = (ballX + ballRadius) - left;
          final double overlapRight = right - (ballX - ballRadius);
          final double overlapTop = (ballY + ballRadius) - top;
          final double overlapBottom = bottom - (ballY - ballRadius);

          final double minOverlap =
              [overlapLeft, overlapRight, overlapTop, overlapBottom].reduce(min);

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
      blocksAlive =
          List.generate(rows, (_) => List.generate(cols, (_) => true));

      ballX = screenWidth / 2;
      ballY = screenHeight * 0.6;
      ballVX = 150;
      ballVY = -150;

      paddleX = screenWidth / 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        screenWidth = constraints.maxWidth;
        screenHeight = constraints.maxHeight;

        blockWidth = (screenWidth - (cols + 1) * blockGap) / cols;
        paddleY = screenHeight - 60;

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              for (int r = 0; r < rows; r++)
                for (int c = 0; c < cols; c++)
                  if (blocksAlive[r][c])
                    Positioned(
                      left: c * (blockWidth + blockGap) + blockGap,
                      top: 40 + r * (blockHeight + blockGap),
                      width: blockWidth,
                      height: blockHeight,
                      child: Container(color: Colors.blueAccent),
                    ),
              Positioned(
                left: ballX - ballRadius,
                top: ballY - ballRadius,
                width: ballRadius * 2,
                height: ballRadius * 2,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: paddleX - paddleWidth / 2,
                top: paddleY,
                width: paddleWidth,
                height: paddleHeight,
                child: Container(color: Colors.redAccent),
              ),
              if (statusText != null)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        statusText!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _resetGame,
                        child: const Text('Restart'),
                      ),
                    ],
                  ),
                ),
              Positioned(
                left: 12,
                top: 32,
                child: Text(
                  'tilt to move | accelX: ${accelX.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
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
