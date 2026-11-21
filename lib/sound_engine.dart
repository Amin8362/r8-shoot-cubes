import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

class GameSoundEngine {
  static const int _sampleRate = 22050;
  static const List<double> _comboNotesHz = [
    523.25, // C5
    587.33, // D5
    659.25, // E5
    783.99, // G5
    880.00, // A5
    1046.50, // C6
  ];

  final List<AudioPlayer> _pool = List.generate(6, (_) => AudioPlayer());
  int _poolIndex = 0;

  bool _enabled = true;
  bool _ready = false;

  Source? _shootSrc;
  Source? _hammerSrc;
  Source? _blockedSrc;
  Source? _clickSrc;
  Source? _gameOverSrc;
  final List<Source> _comboSrcs = [];

  bool get enabled => _enabled;

  void setEnabled(bool value) {
    _enabled = value;
  }

  Future<void> init() async {
    if (_ready) return;
    try {
      for (final AudioPlayer player in _pool) {
        await player.setReleaseMode(ReleaseMode.stop);
      }

      _shootSrc = await _prepareSource('shoot', _buildShootWav());
      _hammerSrc = await _prepareSource('hammer', _buildHammerWav());
      _blockedSrc = await _prepareSource('blocked', _buildBlockedWav());
      _clickSrc = await _prepareSource('click', _buildClickWav());
      _gameOverSrc = await _prepareSource('gameover', _buildGameOverWav());

      _comboSrcs.clear();
      for (int i = 0; i < _comboNotesHz.length; i++) {
        _comboSrcs.add(
          await _prepareSource(
            'merge_$i',
            _buildMergeWav(_comboNotesHz[i]),
          ),
        );
      }
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> dispose() async {
    for (final AudioPlayer player in _pool) {
      try {
        await player.dispose();
      } catch (_) {}
    }
  }

  void playShoot() => _play(_shootSrc, volume: 0.65);

  void playMerge(int comboStep) {
    if (_comboSrcs.isEmpty) return;
    final int idx = (comboStep - 1).clamp(0, _comboSrcs.length - 1);
    _play(_comboSrcs[idx], volume: 0.85);
  }

  void playHammer() => _play(_hammerSrc, volume: 0.9);
  void playBlocked() => _play(_blockedSrc, volume: 0.55);
  void playClick() => _play(_clickSrc, volume: 0.45);
  void playGameOver() => _play(_gameOverSrc, volume: 0.8);

  Future<void> _play(Source? source, {double volume = 0.75}) async {
    if (!_enabled || !_ready || source == null) return;
    try {
      final AudioPlayer player = _pool[_poolIndex];
      _poolIndex = (_poolIndex + 1) % _pool.length;
      final PlayerMode mode = source is DeviceFileSource
          ? PlayerMode.lowLatency
          : PlayerMode.mediaPlayer;
      await player.stop();
      await player.play(source, volume: volume, mode: mode);
    } catch (_) {}
  }

  Future<Source> _prepareSource(String name, Uint8List wavBytes) async {
    try {
      final File file = File('${Directory.systemTemp.path}/r8_sfx_$name.wav');
      await file.writeAsBytes(wavBytes, flush: true);
      return DeviceFileSource(file.path);
    } catch (_) {
      return BytesSource(wavBytes);
    }
  }

  Uint8List _buildShootWav() {
    return _synthesize(0.095, (double t, double dur) {
      final double progress = t / dur;
      final double freq = 230.0 + (340.0 * progress);
      final double env = math.sin(math.pi * progress) * (1.0 - 0.3 * progress);
      return math.sin(2.0 * math.pi * freq * t) * env * 0.55;
    });
  }

  Uint8List _buildMergeWav(double baseFreq) {
    return _synthesize(0.18, (double t, double dur) {
      final double progress = t / dur;
      final double attack = (t / 0.008).clamp(0.0, 1.0);
      final double decay = math.exp(-7.0 * progress);
      final double env = attack * decay;
      final double wave =
          0.72 * math.sin(2.0 * math.pi * baseFreq * t) +
          0.28 * math.sin(2.0 * math.pi * (baseFreq * 1.5) * t);
      return wave * env * 0.65;
    });
  }

  Uint8List _buildHammerWav() {
    final math.Random rng = math.Random(42);
    return _synthesize(0.16, (double t, double dur) {
      final double progress = t / dur;
      final double thudFreq = 160.0 * (1.0 - 0.65 * progress);
      final double thud =
          math.sin(2.0 * math.pi * thudFreq * t) * math.exp(-10.0 * progress);
      final double crack =
          (rng.nextDouble() * 2.0 - 1.0) * math.exp(-18.0 * progress) * 0.45;
      return (thud * 0.75 + crack) * 0.7;
    });
  }

  Uint8List _buildBlockedWav() {
    return _synthesize(0.11, (double t, double dur) {
      final double progress = t / dur;
      final double env = math.exp(-9.0 * progress);
      return math.sin(2.0 * math.pi * 135.0 * t) * env * 0.55;
    });
  }

  Uint8List _buildClickWav() {
    return _synthesize(0.045, (double t, double dur) {
      final double progress = t / dur;
      final double env = math.exp(-22.0 * progress);
      return math.sin(2.0 * math.pi * 760.0 * t) * env * 0.4;
    });
  }

  Uint8List _buildGameOverWav() {
    return _synthesize(0.45, (double t, double dur) {
      final double progress = t / dur;
      final double freq = progress < 0.33
          ? 440.0
          : (progress < 0.66 ? 349.23 : 261.63);
      final double localT = (progress % 0.33) / 0.33;
      final double env =
          (localT / 0.08).clamp(0.0, 1.0) * math.exp(-3.2 * localT);
      return math.sin(2.0 * math.pi * freq * t) * env * 0.6;
    });
  }

  Uint8List _synthesize(
    double durationSec,
    double Function(double t, double dur) sampleAt,
  ) {
    final int numSamples = (_sampleRate * durationSec).round();
    final int dataSize = numSamples * 2;
    final ByteData bytes = ByteData(44 + dataSize);

    // RIFF header
    bytes.setUint8(0, 0x52); // R
    bytes.setUint8(1, 0x49); // I
    bytes.setUint8(2, 0x46); // F
    bytes.setUint8(3, 0x46); // F
    bytes.setUint32(4, 36 + dataSize, Endian.little);
    bytes.setUint8(8, 0x57); // W
    bytes.setUint8(9, 0x41); // A
    bytes.setUint8(10, 0x56); // V
    bytes.setUint8(11, 0x45); // E

    // fmt chunk
    bytes.setUint8(12, 0x66); // f
    bytes.setUint8(13, 0x6D); // m
    bytes.setUint8(14, 0x74); // t
    bytes.setUint8(15, 0x20); // space
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little); // PCM
    bytes.setUint16(22, 1, Endian.little); // Mono
    bytes.setUint32(24, _sampleRate, Endian.little);
    bytes.setUint32(28, _sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);

    // data chunk
    bytes.setUint8(36, 0x64); // d
    bytes.setUint8(37, 0x61); // a
    bytes.setUint8(38, 0x74); // t
    bytes.setUint8(39, 0x61); // a
    bytes.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < numSamples; i++) {
      final double t = i / _sampleRate;
      final double clamped = sampleAt(t, durationSec).clamp(-1.0, 1.0);
      bytes.setInt16(44 + i * 2, (clamped * 32767).round(), Endian.little);
    }

    return bytes.buffer.asUint8List();
  }
}
