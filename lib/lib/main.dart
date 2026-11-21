import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_engine.dart';

const String kBrandName = 'R8Force';
const String kAuthorName = 'امین شیردلی';
const String kGameVersion = '1.0.0';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF070A12),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const R8ShootCubesApp());
}

class R8ShootCubesApp extends StatelessWidget {
  const R8ShootCubesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'R8Force Shoot Cubes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF070A12),
      ),
      home: const ShootCubesScreen(),
    );
  }
}

class ShootCubesScreen extends StatefulWidget {
  const ShootCubesScreen({super.key});

  @override
  State<ShootCubesScreen> createState() => _ShootCubesScreenState();
}

class _ShootCubesScreenState extends State<ShootCubesScreen>
    with SingleTickerProviderStateMixin {
  final ShootMergeEngine _engine = ShootMergeEngine();

  bool _hapticsEnabled = true;
  bool _isAnimating = false;
  bool _hammerMode = false;

  int? _aimCol;
  int _activeCombo = 0;

  // وضعیت مکعب در حال شلیک به بالا
  late final AnimationController _shootController;
  int? _flyingValue;
  int _flyingCol = 2;
  double _flyingFromRow = 6.6;
  double _flyingToRow = 0;

  @override
  void initState() {
    super.initState();
    _shootController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 145),
    );
  }

  @override
  void dispose() {
    _shootController.dispose();
    super.dispose();
  }

  Future<void> _shootToColumn(int col) async {
    if (_isAnimating || _engine.isGameOver) return;

    final int? targetRow = _engine.previewLandingRow(col);
    if (targetRow == null) {
      if (_hapticsEnabled) HapticFeedback.heavyImpact();
      return;
    }

    if (_hapticsEnabled) HapticFeedback.lightImpact();

    setState(() {
      _isAnimating = true;
      _activeCombo = 0;
      _flyingValue = _engine.currentValue;
      _flyingCol = col;
      _flyingFromRow = ShootMergeEngine.rows - 0.35;
      _flyingToRow = targetRow.toDouble();
    });

    final int travelMs = (90 + ((_flyingFromRow - _flyingToRow) * 18)).round();
    _shootController.duration = Duration(milliseconds: travelMs.clamp(85, 200));
    await _shootController.forward(from: 0.0);
    if (!mounted) return;

    _engine.placeShotTile(col);
    setState(() {
      _flyingValue = null;
    });

    await _runChainMergeLoop();

    if (!mounted) return;
    _engine.refreshGameOverState();
    setState(() {
      _isAnimating = false;
    });
  }

  Future<void> _useHammerAt(int row, int col) async {
    if (_isAnimating) return;
    final bool removed = _engine.useHammerAt(row, col);
    if (!removed) return;

    if (_hapticsEnabled) HapticFeedback.mediumImpact();
    setState(() {
      _hammerMode = false;
      _isAnimating = true;
    });

    _engine.applyUpwardGravity();
    setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;

    await _runChainMergeLoop();

    if (!mounted) return;
    _engine.refreshGameOverState();
    setState(() {
      _isAnimating = false;
    });
  }

  Future<void> _runChainMergeLoop() async {
    int combo = 0;
    while (mounted) {
      final MergeStepResult? step = _engine.resolveNextMergeStep();
      if (step == null) break;

      combo++;
      if (_hapticsEnabled) HapticFeedback.mediumImpact();
      setState(() {
        _activeCombo = combo;
      });

      await Future<void>.delayed(const Duration(milliseconds: 165));
      if (!mounted) return;

      final bool shifted = _engine.applyUpwardGravity();
      if (shifted) {
        setState(() {});
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
    }

    if (combo > 0 && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (mounted) {
        setState(() => _activeCombo = 0);
      }
    }
  }

  void _restartGame() {
    if (_isAnimating) return;
    if (_hapticsEnabled) HapticFeedback.mediumImpact();
    setState(() {
      _hammerMode = false;
      _aimCol = null;
      _activeCombo = 0;
      _engine.reset();
    });
  }

  void _switchMode(ShootGameMode mode) {
    if (_isAnimating || _engine.mode == mode) return;
    if (_hapticsEnabled) HapticFeedback.selectionClick();
    setState(() {
      _hammerMode = false;
      _aimCol = null;
      _activeCombo = 0;
      _engine.switchMode(mode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // پس‌زمینه تیره نئونی
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A1020),
                  Color(0xFF060912),
                  Color(0xFF0E1528),
                ],
              ),
            ),
          ),
          Positioned(
            top: -90,
            right: -70,
            child: Container(
              width: 280,
              height: 280,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x556366F1), Color(0x006366F1)],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -110,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x4406B6D4), Color(0x0006B6D4)],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 10),
                  _buildModeSwitcher(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio:
                            ShootMergeEngine.cols / ShootMergeEngine.rows,
                        child: _buildShootBoard(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildBottomLauncherBar(),
                  const SizedBox(height: 8),
                  const Text(
                    '$kBrandName  •  $kAuthorName  •  v$kGameVersion',
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 0.4,
                      color: Color(0x66CBD5E1),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0x1F06B6D4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x5506B6D4)),
              ),
              child: const Text(
                'R8FORCE SHOOT',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                  color: Color(0xFF67E8F9),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'MAX ${_engine.maxTile == 0 ? "-" : _engine.maxTile}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xCCA5B4FC),
                  ),
                ),
                if (_activeCombo >= 2) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEC4899),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'COMBO x$_activeCombo',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        Row(
          children: [
            _ScorePill(label: 'امتیاز', value: _engine.score),
            const SizedBox(width: 8),
            _ScorePill(
              label: 'رکورد',
              value: _engine.bestScore,
              highlight: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeSwitcher() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0x14FFFFFF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x20FFFFFF)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ModeTab(
                      label: 'توان‌های ۲ (کلاسیک)',
                      selected: _engine.mode == ShootGameMode.powersOfTwo,
                      onTap: () => _switchMode(ShootGameMode.powersOfTwo),
                    ),
                  ),
                  Expanded(
                    child: _ModeTab(
                      label: 'مضرب‌های ۲ (۶، ۱۰، ۱۲)',
                      selected: _engine.mode == ShootGameMode.evenMultiples,
                      onTap: () => _switchMode(ShootGameMode.evenMultiples),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _restartGame,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0x16FFFFFF),
                border: Border.all(color: const Color(0x24FFFFFF)),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                size: 20,
                color: Color(0xFF67E8F9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShootBoard() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x1CFFFFFF),
                  Color(0x0BFFFFFF),
                ],
              ),
              border: Border.all(
                color: _hammerMode
                    ? const Color(0xAAF59E0B)
                    : const Color(0x26FFFFFF),
                width: _hammerMode ? 1.8 : 1.1,
              ),
            ),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                const double pad = 10.0;
                const double gap = 7.0;
                final double tileW = (constraints.maxWidth -
                        pad * 2 -
                        gap * (ShootMergeEngine.cols - 1)) /
                    ShootMergeEngine.cols;
                final double tileH = (constraints.maxHeight -
                        pad * 2 -
                        gap * (ShootMergeEngine.rows - 1)) /
                    ShootMergeEngine.rows;
                final double tileSize = math.min(tileW, tileH);
                final double gridW = tileSize * ShootMergeEngine.cols +
                    gap * (ShootMergeEngine.cols - 1);
                final double gridH = tileSize * ShootMergeEngine.rows +
                    gap * (ShootMergeEngine.rows - 1);
                final double offsetX = (constraints.maxWidth - gridW) / 2;
                final double offsetY = (constraints.maxHeight - gridH) / 2;

                int colFromDx(double dx) {
                  final int raw =
                      ((dx - offsetX) / (tileSize + gap)).floor();
                  return raw.clamp(0, ShootMergeEngine.cols - 1);
                }

                int rowFromDy(double dy) {
                  final int raw =
                      ((dy - offsetY) / (tileSize + gap)).floor();
                  return raw.clamp(0, ShootMergeEngine.rows - 1);
                }

                final int? previewRow = (_aimCol != null && !_hammerMode)
                    ? _engine.previewLandingRow(_aimCol!)
                    : null;

                return Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (PointerDownEvent event) {
                    if (_isAnimating || _engine.isGameOver) return;
                    if (_hammerMode) return;
                    setState(() {
                      _aimCol = colFromDx(event.localPosition.dx);
                    });
                  },
                  onPointerMove: (PointerMoveEvent event) {
                    if (_isAnimating || _engine.isGameOver || _hammerMode) {
                      return;
                    }
                    final int newCol = colFromDx(event.localPosition.dx);
                    if (newCol != _aimCol) {
                      if (_hapticsEnabled) HapticFeedback.selectionClick();
                      setState(() => _aimCol = newCol);
                    }
                  },
                  onPointerUp: (PointerUpEvent event) {
                    if (_isAnimating || _engine.isGameOver) return;
                    if (_hammerMode) {
                      final int r = rowFromDy(event.localPosition.dy);
                      final int c = colFromDx(event.localPosition.dx);
                      _useHammerAt(r, c);
                      return;
                    }
                    final int targetCol =
                        _aimCol ?? colFromDx(event.localPosition.dx);
                    setState(() => _aimCol = null);
                    _shootToColumn(targetCol);
                  },
                  onPointerCancel: (_) {
                    if (_aimCol != null) {
                      setState(() => _aimCol = null);
                    }
                  },
                  child: Stack(
                    children: [
                      // خطوط راهنمای ۵ ستون
                      for (int c = 0; c < ShootMergeEngine.cols; c++)
                        Positioned(
                          left: offsetX + c * (tileSize + gap),
                          top: offsetY,
                          width: tileSize,
                          height: gridH,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 90),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: (_aimCol == c && !_hammerMode)
                                  ? const Color(0x2267E8F9)
                                  : (c.isEven
                                      ? const Color(0x16070A12)
                                      : const Color(0x0A070A12)),
                              border: (_aimCol == c && !_hammerMode)
                                  ? Border.all(
                                      color: const Color(0x5567E8F9),
                                      width: 1,
                                    )
                                  : null,
                            ),
                          ),
                        ),

                      // پیش‌نمایش شبح محل فرود مکعب هنگام نشانه‌گیری
                      if (_aimCol != null && previewRow != null && !_hammerMode)
                        Positioned(
                          left: offsetX + _aimCol! * (tileSize + gap),
                          top: offsetY + previewRow * (tileSize + gap),
                          width: tileSize,
                          height: tileSize,
                          child: Opacity(
                            opacity: 0.38,
                            child: _CubeFace(value: _engine.currentValue),
                          ),
                        ),

                      // مکعب‌های روی صفحه با انیمیشن جاذبه به بالا و جهش ادغام
                      for (final BoardTile tile in _engine.allTiles)
                        AnimatedPositioned(
                          key: ValueKey<int>(tile.id),
                          duration: const Duration(milliseconds: 120),
                          curve: Curves.easeOutCubic,
                          left: offsetX + tile.col * (tileSize + gap),
                          top: offsetY + tile.row * (tileSize + gap),
                          width: tileSize,
                          height: tileSize,
                          child: _AnimatedBoardCube(
                            tile: tile,
                            hammerHighlight: _hammerMode,
                          ),
                        ),

                      // انیمیشن شلیک مکعب از پایین به بالا
                      if (_flyingValue != null)
                        AnimatedBuilder(
                          animation: _shootController,
                          builder: (BuildContext context, Widget? child) {
                            final double t = Curves.easeOutCubic
                                .transform(_shootController.value);
                            final double currentRow =
                                lerpDouble(_flyingFromRow, _flyingToRow, t)!;
                            return Positioned(
                              left: offsetX + _flyingCol * (tileSize + gap),
                              top: offsetY + currentRow * (tileSize + gap),
                              width: tileSize,
                              height: tileSize,
                              child: child!,
                            );
                          },
                          child: _CubeFace(value: _flyingValue!),
                        ),

                      // پیام راهنما وقتی صفحه خالی است
                      if (_engine.allTiles.isEmpty && _flyingValue == null)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'روی هر ستون بزنید یا انگشت را بکشید تا مکعب شلیک شود',
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: Color(0x88E2E8F0),
                              ),
                            ),
                          ),
                        ),

                      // حالت فعال بودن چکش
                      if (_hammerMode)
                        Positioned(
                          bottom: 10,
                          left: 14,
                          right: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xDD1E1B18),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xAAF59E0B),
                              ),
                            ),
                            child: const Text(
                              'روی مکعبی که می‌خواهید حذف شود ضربه بزنید',
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFDE68A),
                              ),
                            ),
                          ),
                        ),

                      // صفحه پایان بازی
                      if (_engine.isGameOver) _buildGameOverOverlay(),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomLauncherBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0x16FFFFFF),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // دکمه چکش (حذف مکعب)
          GestureDetector(
            onTap: () {
              if (_isAnimating || _engine.hammers <= 0 || _engine.allTiles.isEmpty) {
                return;
              }
              if (_hapticsEnabled) HapticFeedback.selectionClick();
              setState(() => _hammerMode = !_hammerMode);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: _hammerMode
                    ? const Color(0x44F59E0B)
                    : const Color(0x14FFFFFF),
                border: Border.all(
                  color: _hammerMode
                      ? const Color(0xFFFBBF24)
                      : const Color(0x24FFFFFF),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.hardware_rounded,
                    size: 19,
                    color: _engine.hammers > 0
                        ? const Color(0xFFFBBF24)
                        : const Color(0x55FFFFFF),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_engine.hammers}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _engine.hammers > 0
                          ? Colors.white
                          : const Color(0x55FFFFFF),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // مکعب فعلی آماده شلیک (بزرگ و درخشان در وسط)
          Row(
            children: [
              Column(
                children: [
                  const Text(
                    'آماده شلیک',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xAA67E8F9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: Opacity(
                      opacity: _flyingValue != null ? 0.25 : 1.0,
                      child: _CubeFace(value: _engine.currentValue),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              // مکعب بعدی (پیش‌نمایش کوچک)
              Column(
                children: [
                  const Text(
                    'بعدی',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0x88E2E8F0),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 42,
                    height: 42,
                    child: Opacity(
                      opacity: 0.85,
                      child: _CubeFace(
                        value: _engine.nextValue,
                        compact: true,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // دکمه ویبره
          GestureDetector(
            onTap: () {
              setState(() => _hapticsEnabled = !_hapticsEnabled);
              if (_hapticsEnabled) HapticFeedback.lightImpact();
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: _hapticsEnabled
                    ? const Color(0x286366F1)
                    : const Color(0x12FFFFFF),
                border: Border.all(
                  color: _hapticsEnabled
                      ? const Color(0x66818CF8)
                      : const Color(0x22FFFFFF),
                ),
              ),
              child: Icon(
                _hapticsEnabled
                    ? Icons.vibration_rounded
                    : Icons.mobile_off_rounded,
                size: 19,
                color: _hapticsEnabled
                    ? const Color(0xFFA5B4FC)
                    : const Color(0x77FFFFFF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    return Positioned.fill(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          color: const Color(0xCC070A12),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.grid_off_rounded,
                size: 50,
                color: Color(0xFFF87171),
              ),
              const SizedBox(height: 12),
              const Text(
                'تمام ستون‌ها پر شد!',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'امتیاز: ${_engine.score}  •  بزرگ‌ترین مکعب: ${_engine.maxTile}',
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xCCE2E8F0),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _restartGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'شروع بازی جدید',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedBoardCube extends StatefulWidget {
  final BoardTile tile;
  final bool hammerHighlight;

  const _AnimatedBoardCube({
    required this.tile,
    required this.hammerHighlight,
  });

  @override
  State<_AnimatedBoardCube> createState() => _AnimatedBoardCubeState();
}

class _AnimatedBoardCubeState extends State<_AnimatedBoardCube>
    with SingleTickerProviderStateMixin {
  late final AnimationController _popController;
  late final Animation<double> _popScale;

  @override
  void initState() {
    super.initState();
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _popScale = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.0, end: 1.18)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.18, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 55,
      ),
    ]).animate(_popController);
  }

  @override
  void didUpdateWidget(covariant _AnimatedBoardCube oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tile.value != oldWidget.tile.value) {
      _popController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _popController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _popScale,
      child: _CubeFace(
        value: widget.tile.value,
        hammerHighlight: widget.hammerHighlight,
      ),
    );
  }
}

class _CubeFace extends StatelessWidget {
  final int value;
  final bool compact;
  final bool hammerHighlight;

  const _CubeFace({
    required this.value,
    this.compact = false,
    this.hammerHighlight = false,
  });

  static _CubePalette _paletteFor(int value) {
    // رنگ اختصاصی و ثابت برای توان‌های ۲ و اعداد زوج پرکاربرد
    const Map<int, Color> baseColors = {
      2: Color(0xFF3B82F6), // آبی
      4: Color(0xFF06B6D4), // فیروزه‌ای
      6: Color(0xFF10B981), // زمردی
      8: Color(0xFF8B5CF6), // بنفش
      10: Color(0xFFEC4899), // سرخابی
      12: Color(0xFF14B8A6), // سبزآبی
      16: Color(0xFFF59E0B), // کهربایی
      20: Color(0xFFF43F5E), // قرمز مرجانی
      24: Color(0xFF84CC16), // سبز لیمویی
      32: Color(0xFFEF4444), // قرمز
      40: Color(0xFFD946EF), // ارغوانی
      48: Color(0xFF22C55E), // سبز درخشان
      64: Color(0xFFE11D48), // یاقوتی
      128: Color(0xFF6366F1), // نیلی
      256: Color(0xFFEA580C), // نارنجی آتشین
      512: Color(0xFFA855F7), // بنفش روشن
      1024: Color(0xFF0EA5E9), // آبی آسمانی
      2048: Color(0xFFFACC15), // طلایی
    };

    final Color seed = baseColors[value] ??
        HSLColor.fromAHSL(
          1.0,
          (value * 47.0) % 360.0,
          0.74,
          0.52,
        ).toColor();

    final HSLColor hsl = HSLColor.fromColor(seed);
    final Color top = hsl.withLightness((hsl.lightness + 0.08).clamp(0.0, 0.85)).toColor();
    final Color bottom = hsl.withLightness((hsl.lightness - 0.14).clamp(0.15, 1.0)).toColor();
    final Color textColor =
        value == 2048 ? const Color(0xFF090D16) : Colors.white;

    return _CubePalette(
      top: top,
      bottom: bottom,
      glow: seed.withAlpha(115),
      border: top.withAlpha(200),
      text: textColor,
    );
  }

  String _formatLabel(int val) {
    if (val >= 1000000) {
      return '${(val / 1000000).toStringAsFixed(1)}M';
    }
    if (val >= 10000) {
      return '${(val / 1000).toStringAsFixed(1)}K';
    }
    return '$val';
  }

  @override
  Widget build(BuildContext context) {
    final _CubePalette palette = _paletteFor(value);
    final String label = _formatLabel(value);
    final double fontSize = compact
        ? (label.length <= 2 ? 16 : 13)
        : (label.length <= 2
            ? 24
            : label.length == 3
                ? 20
                : 16);

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.top, palette.bottom],
        ),
        border: Border.all(
          color: hammerHighlight ? const Color(0xFFFDE047) : palette.border,
          width: hammerHighlight ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.glow,
            blurRadius: compact ? 6 : 11,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: palette.text,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

class _CubePalette {
  final Color top;
  final Color bottom;
  final Color glow;
  final Color border;
  final Color text;

  const _CubePalette({
    required this.top,
    required this.bottom,
    required this.glow,
    required this.border,
    required this.text,
  });
}

class _ScorePill extends StatelessWidget {
  final String label;
  final int value;
  final bool highlight;

  const _ScorePill({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 74),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: highlight ? const Color(0x286366F1) : const Color(0x14FFFFFF),
        border: Border.all(
          color: highlight ? const Color(0x55818CF8) : const Color(0x22FFFFFF),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: highlight
                  ? const Color(0xFFA5B4FC)
                  : const Color(0x99E2E8F0),
            ),
          ),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? const Color(0x3D6366F1) : Colors.transparent,
          border: Border.all(
            color: selected ? const Color(0x77818CF8) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? Colors.white : const Color(0x99E2E8F0),
          ),
        ),
      ),
    );
  }
}
