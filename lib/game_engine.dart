
import 'dart:math';

enum ShootGameMode {
  powersOfTwo,
  evenMultiples,
}

class BoardTile {
  final int id;
  final int value;
  final int row;
  final int col;

  const BoardTile({
    required this.id,
    required this.value,
    required this.row,
    required this.col,
  });

  BoardTile copyWith({
    int? value,
    int? row,
    int? col,
  }) {
    return BoardTile(
      id: id,
      value: value ?? this.value,
      row: row ?? this.row,
      col: col ?? this.col,
    );
  }
}

class MergeStepResult {
  final int mergedRow;
  final int mergedCol;
  final int newValue;
  final int absorbedCount;

  const MergeStepResult({
    required this.mergedRow,
    required this.mergedCol,
    required this.newValue,
    required this.absorbedCount,
  });
}

class ShootMergeEngine {
  static const int rows = 7;
  static const int cols = 5;

  final Random _random = Random();
  int _nextId = 1;

  ShootGameMode _mode = ShootGameMode.powersOfTwo;
  late List<List<BoardTile?>> _grid;

  int _currentValue = 2;
  int _nextValue = 4;
  int _score = 0;
  int _bestScore = 0;
  int _maxTile = 0;
  int _hammers = 3;
  int _nextHammerMilestone = 64;
  bool _isGameOver = false;

  (int, int)? _priorityCell;

  ShootMergeEngine() {
    reset();
  }

  ShootGameMode get mode => _mode;
  int get currentValue => _currentValue;
  int get nextValue => _nextValue;
  int get score => _score;
  int get bestScore => _bestScore;
  int get maxTile => _maxTile;
  int get hammers => _hammers;
  bool get isGameOver => _isGameOver;

  List<BoardTile> get allTiles {
    final List<BoardTile> list = [];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final BoardTile? tile = _grid[r][c];
        if (tile != null) list.add(tile);
      }
    }
    return list;
  }

  BoardTile? tileAt(int row, int col) {
    if (row < 0 || row >= rows || col < 0 || col >= cols) return null;
    return _grid[row][col];
  }

  void switchMode(ShootGameMode newMode) {
    if (_mode == newMode) return;
    _mode = newMode;
    reset();
  }

  void reset() {
    _grid = List.generate(rows, (_) => List<BoardTile?>.filled(cols, null));
    _score = 0;
    _maxTile = 0;
    _hammers = 3;
    _nextHammerMilestone = _mode == ShootGameMode.powersOfTwo ? 64 : 48;
    _isGameOver = false;
    _priorityCell = null;
    _currentValue = _generateSpawnValue();
    _nextValue = _generateSpawnValue();
  }

  /// ردیف فرود مکعب در ستون مشخص؛ اگر ستون پر و غیرقابل ادغام باشد null برمی‌گرداند.
  int? previewLandingRow(int col) {
    if (col < 0 || col >= cols) return null;
    for (int r = 0; r < rows; r++) {
      if (_grid[r][col] == null) {
        return r;
      }
    }
    // اگر ستون کاملاً پر بود ولی آخرین خانه هم‌عدد مکعب شلیکی بود، اجازه ادغام مستقیم می‌دهیم
    final BoardTile? bottom = _grid[rows - 1][col];
    if (bottom != null && bottom.value == _currentValue) {
      return rows - 1;
    }
    return null;
  }

  /// قرار دادن مکعب شلیک‌شده در ستون و آماده کردن نوبت بعدی
  bool placeShotTile(int col) {
    final int? targetRow = previewLandingRow(col);
    if (targetRow == null) return false;

    final BoardTile? existing = _grid[targetRow][col];
    if (existing != null && existing.value == _currentValue) {
      final int doubled = existing.value * 2;
      _grid[targetRow][col] = existing.copyWith(value: doubled);
      _registerScore(doubled);
      _priorityCell = (targetRow, col);
    } else {
      _grid[targetRow][col] = BoardTile(
        id: _nextId++,
        value: _currentValue,
        row: targetRow,
        col: col,
      );
      _updateMaxTile(_currentValue);
      _priorityCell = (targetRow, col);
    }

    _currentValue = _nextValue;
    _nextValue = _generateSpawnValue();
    return true;
  }

  /// اجرای یک گام از ادغام (اولویت با آخرین مکعب جابه‌جاشده برای حس کمبوی طبیعی)
  MergeStepResult? resolveNextMergeStep() {
    if (_priorityCell != null) {
      final (int pr, int pc) = _priorityCell!;
      final MergeStepResult? priorityResult = _tryMergeAt(pr, pc);
      if (priorityResult != null) {
        _priorityCell = (priorityResult.mergedRow, priorityResult.mergedCol);
        return priorityResult;
      }
    }

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final MergeStepResult? res = _tryMergeAt(r, c);
        if (res != null) {
          _priorityCell = (res.mergedRow, res.mergedCol);
          return res;
        }
      }
    }

    _priorityCell = null;
    return null;
  }

  MergeStepResult? _tryMergeAt(int r, int c) {
    final BoardTile? center = _grid[r][c];
    if (center == null) return null;

    final List<(int, int)> matches = [];
    const List<(int, int)> dirs = [
      (-1, 0), // بالا
      (0, -1), // چپ
      (0, 1), // راست
      (1, 0), // پایین
    ];

    for (final (int dr, int dc) in dirs) {
      final int nr = r + dr;
      final int nc = c + dc;
      if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
        final BoardTile? neighbor = _grid[nr][nc];
        if (neighbor != null && neighbor.value == center.value) {
          matches.add((nr, nc));
        }
      }
    }

    if (matches.isEmpty) return null;

    // 1 همسایه -> 2 برابر، 2 همسایه همزمان -> 4 برابر، 3 همسایه -> 8 برابر
    final int multiplier = 1 << matches.length;
    final int newValue = center.value * multiplier;

    // اگر همسایه بالایی در ادغام بود، نتیجه در خانه بالایی بنشیند تا حرکت رو به بالا طبیعی‌تر شود
    final bool hasTopMatch = matches.any((m) => m.$1 == r - 1 && m.$2 == c);
    final int destRow = hasTopMatch ? r - 1 : r;
    final int destCol = c;
    final int keepId = hasTopMatch ? _grid[r - 1][c]!.id : center.id;

    _grid[r][c] = null;
    for (final (int mr, int mc) in matches) {
      _grid[mr][mc] = null;
    }

    _grid[destRow][destCol] = BoardTile(
      id: keepId,
      value: newValue,
      row: destRow,
      col: destCol,
    );

    _registerScore(newValue);

    return MergeStepResult(
      mergedRow: destRow,
      mergedCol: destCol,
      newValue: newValue,
      absorbedCount: matches.length,
    );
  }

  /// جاذبه به سمت بالای صفحه (در سبک Shoot & Merge مکعب‌ها به سقف می‌چسبند)
  bool applyUpwardGravity() {
    bool moved = false;
    for (int c = 0; c < cols; c++) {
      int writeRow = 0;
      for (int r = 0; r < rows; r++) {
        final BoardTile? tile = _grid[r][c];
        if (tile != null) {
          if (r != writeRow) {
            _grid[writeRow][c] = tile.copyWith(row: writeRow, col: c);
            _grid[r][c] = null;
            moved = true;
            if (_priorityCell == (r, c)) {
              _priorityCell = (writeRow, c);
            }
          }
          writeRow++;
        }
      }
    }
    return moved;
  }

  /// استفاده از چکش برای حذف یک مکعب مزاحم
  bool useHammerAt(int row, int col) {
    if (_hammers <= 0) return false;
    if (row < 0 || row >= rows || col < 0 || col >= cols) return false;
    if (_grid[row][col] == null) return false;

    _grid[row][col] = null;
    _hammers--;
    _isGameOver = false;
    _priorityCell = null;
    return true;
  }

  void refreshGameOverState() {
    for (int c = 0; c < cols; c++) {
      if (previewLandingRow(c) != null) {
        _isGameOver = false;
        return;
      }
    }
    _isGameOver = true;
  }

  void _registerScore(int points) {
    _score += points;
    if (_score > _bestScore) {
      _bestScore = _score;
    }
    _updateMaxTile(points);
  }

  void _updateMaxTile(int val) {
    if (val > _maxTile) {
      _maxTile = val;
      if (_maxTile >= _nextHammerMilestone) {
        if (_hammers < 5) _hammers++;
        _nextHammerMilestone *= 2;
      }
    }
  }

  int _generateSpawnValue() {
    if (_mode == ShootGameMode.powersOfTwo) {
      final List<int> pool;
      if (_maxTile < 32) {
        pool = const [2, 2, 4, 4, 8];
      } else if (_maxTile < 128) {
        pool = const [2, 4, 4, 8, 8, 16];
      } else if (_maxTile < 512) {
        pool = const [2, 4, 8, 8, 16, 16, 32];
      } else if (_maxTile < 2048) {
        pool = const [4, 8, 16, 16, 32, 32, 64];
      } else {
        pool = const [8, 16, 32, 32, 64, 64, 128];
      }
      return pool[_random.nextInt(pool.length)];
    } else {
      // حالت مضرب‌های ۲ (شامل اعداد زوج زیر ۱۰ مثل ۶ و سپس ۱۰، ۱۲، ۲۰، ۲۴ و بالاتر)
      final List<int> pool;
      if (_maxTile < 24) {
        pool = const [2, 4, 6, 8];
      } else if (_maxTile < 64) {
        pool = const [2, 4, 6, 8, 10, 12];
      } else if (_maxTile < 160) {
        pool = const [2, 4, 6, 8, 10, 12, 16, 20, 24];
      } else {
        pool = const [4, 6, 8, 10, 12, 16, 20, 24, 32, 48];
      }
      return pool[_random.nextInt(pool.length)];
    }
  }
}
