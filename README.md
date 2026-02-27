# BOUNCER

BOUNCER is a small arcade **breakout-style** game built with Flutter: the ball bounces off the paddle, breaks blocks, and the player controls the paddle by tilting the phone. The game has difficulty levels and falling power-ups with limited duration. 

---

## 🧩 Features

- 3 difficulty levels: **Easy**, **Normal**, **Hard** (affect ball speed and paddle width).
- Tilt controls using `sensors_plus`: tilt the device left/right to move the paddle.
- Simple but satisfying collision logic:
  - bouncing off walls;
  - bouncing off the paddle with an angle based on hit position;
  - block collisions with side detection.
- Falling power-ups:
  - `⬅️➡️` — temporarily widens the paddle;
  - `🐌` — temporarily slows down the ball.
- Audio feedback via `audioplayers`:
  - block hit;
  - win;
  - lose.
- Clean HUD:
  - back button and `BOUNCER` title;
  - score and `Tilt to move` hint;
  - pause and sound on/off buttons.

---

## 🛠 Tech Stack

- Flutter (Material 3, dark theme).
- [`sensors_plus`](https://pub.dev/packages/sensors_plus) — accelerometer access.
- [`audioplayers`](https://pub.dev/packages/audioplayers) — sound effects.
- A simple `AnimationController` used as a ~60 FPS game loop. 

---

## 🚀 Getting Started

1. Install dependencies:

   ```bash
   flutter pub get


2. Run on an emulator or a physical device:
   
   ```bash
   flutter run -d 00008110-000655862110401E
