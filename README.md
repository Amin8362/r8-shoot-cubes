# R8Force Shoot Cubes

A fast, neon-styled **Shoot & Merge** puzzle game for Android built with **Flutter & Dart**, featuring two distinct mathematical game modes and a real-time procedural WAV sound engine with zero external audio assets.

[![Download APK](https://img.shields.io/badge/Download-Latest_APK-6366F1?style=for-the-badge&logo=android&logoColor=white)](https://github.com/Amin8362/r8-shoot-cubes/releases/latest)

---

## Features

- **Dual Math Modes:**
  - **Powers of 2 (Classic):** Smooth exponential chain merges (`2 → 4 → 8 → ... → 2048+`).
  - **Even Multiples (Challenge):** Introduces additional even chains (`6, 10, 12, 20, 24...`) for higher strategic difficulty.
- **Laser Aim & Chain Combos:** Drag to preview the exact landing cell, trigger multi-neighbor merges (`2x / 4x / 8x`), and earn hammer power-ups at milestones.
- **Zero-Asset Sound Synthesizer:** Generates PCM `.wav` sound effects programmatically at startup (shoot, ascending combo pitch, hammer impact, game over) with low-latency playback.

## Project Structure

- `lib/game_engine.dart` — 5×7 grid logic, upward gravity, multi-direction chain merges, and hammer tool.
- `lib/sound_engine.dart` — Procedural PCM/WAV audio synthesizer and player pool.
- `lib/main.dart` — Interactive board, shooting animation, combo HUD, and color palette engine.

## Installation (Android)

1. Open the [**Releases**](https://github.com/Amin8362/r8-shoot-cubes/releases/latest) page.
2. Download **`app-arm64-v8a-release.apk`** and install it on your Android device.

---

<div dir="rtl">

### معرفی فارسی

**بازی شلیک مکعب‌های R8Force** یک بازی پازلی سریع به سبک Shoot & Merge است که دو حالت متفاوت «توان‌های ۲» و «مضرب‌های ۲ (شامل ۶، ۱۰ و ۱۲)»، خط نشانه‌گیری لیزری، کمبوی چندجهته، ابزار چکش و یک موتور تولید صدای زنده (سنتز WAV بدون نیاز به فایل صوتی خارجی) دارد. فایل نصب اندروید در بخش **Releases** قرار دارد.

</div>

---

**Author:** Amin Shirdeli (`R8Force`) • **License:** MIT
