import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_midi_pro/flutter_midi_pro_platform_interface.dart';

/// An implementation of [FlutterMidiProPlatform] that uses method channels.
class MethodChannelFlutterMidiPro extends FlutterMidiProPlatform {
  static const MethodChannel _channel = MethodChannel('flutter_midi_pro');

  @override
  Future<int> loadSoundfont(String path, int bank, int program) async {
    final int sfId = await _channel
        .invokeMethod('loadSoundfont', {'path': path, 'bank': bank, 'program': program});
    return sfId;
  }

  @override
  Future<void> selectInstrument(int sfId, int channel, int bank, int program) async {
    await _channel.invokeMethod(
        'selectInstrument', {'sfId': sfId, 'channel': channel, 'bank': bank, 'program': program});
  }

  @override
  Future<void> playNote(int channel, int key, int velocity, int sfId) async {
    await _channel.invokeMethod(
        'playNote', {'channel': channel, 'key': key, 'velocity': velocity, 'sfId': sfId});
  }

  @override
  Future<void> stopNote(int channel, int key, int sfId) async {
    await _channel.invokeMethod('stopNote', {'channel': channel, 'key': key, 'sfId': sfId});
  }

  @override
  Future<void> stopAllNotes(int sfId) async {
    await _channel.invokeMethod('stopAllNotes', {'sfId': sfId});
  }

  @override
  Future<void> unloadSoundfont(int sfId) async {
    await _channel.invokeMethod('unloadSoundfont', {'sfId': sfId});
  }

  @override
  Future<void> dispose() async {
    await _channel.invokeMethod('dispose');
  }

  // ===== REVERB CONTROLS =====

  @override
  Future<void> setReverbEnabled(bool enabled) async {
    await _channel.invokeMethod('setReverbEnabled', {'enabled': enabled});
  }

  @override
  Future<void> setReverbLevel(double level) async {
    await _channel.invokeMethod('setReverbLevel', {'level': level});
  }

  @override
  Future<void> setReverbRoomSize(double size) async {
    await _channel.invokeMethod('setReverbRoomSize', {'size': size});
  }

  @override
  Future<void> setReverbDamping(double damping) async {
    await _channel.invokeMethod('setReverbDamping', {'damping': damping});
  }

  @override
  Future<void> setReverbWidth(double width) async {
    await _channel.invokeMethod('setReverbWidth', {'width': width});
  }

  // ===== DELAY CONTROLS =====

  @override
  Future<void> setDelayEnabled(bool enabled) async {
    await _channel.invokeMethod('setDelayEnabled', {'enabled': enabled});
  }

  @override
  Future<void> setDelayTime(double seconds) async {
    await _channel.invokeMethod('setDelayTime', {'seconds': seconds});
  }

  @override
  Future<void> setDelayFeedback(double feedback) async {
    await _channel.invokeMethod('setDelayFeedback', {'feedback': feedback});
  }

  @override
  Future<void> setDelayMix(double mix) async {
    await _channel.invokeMethod('setDelayMix', {'mix': mix});
  }
}
