import 'package:flutter_midi_pro/flutter_midi_pro_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

abstract class FlutterMidiProPlatform extends PlatformInterface {
  FlutterMidiProPlatform() : super(token: _token);
  static final Object _token = Object();
  static FlutterMidiProPlatform _instance = MethodChannelFlutterMidiPro();
  static FlutterMidiProPlatform get instance => _instance;

  static set instance(FlutterMidiProPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<int> loadSoundfont(String path, int bank, int program) {
    throw UnimplementedError('loadSoundfont() has not been implemented.');
  }

  Future<void> selectInstrument(int sfId, int channel, int bank, int program) {
    throw UnimplementedError('selectInstrument() has not been implemented.');
  }

  Future<void> playNote(int channel, int key, int velocity, int sfId) {
    throw UnimplementedError('playNote() has not been implemented.');
  }

  Future<void> stopNote(int channel, int key, int sfId) {
    throw UnimplementedError('stopNote() has not been implemented.');
  }

  Future<void> stopAllNotes(int sfId) {
    throw UnimplementedError('stopAllNotes() has not been implemented.');
  }

  Future<void> unloadSoundfont(int sfId) {
    throw UnimplementedError('unloadSoundfont() has not been implemented.');
  }

  Future<void> dispose() {
    throw UnimplementedError('dispose() has not been implemented.');
  }

  // ===== REVERB CONTROLS =====

  Future<void> setReverbEnabled(bool enabled) {
    throw UnimplementedError('setReverbEnabled() has not been implemented.');
  }

  Future<void> setReverbLevel(double level) {
    throw UnimplementedError('setReverbLevel() has not been implemented.');
  }

  Future<void> setReverbRoomSize(double size) {
    throw UnimplementedError('setReverbRoomSize() has not been implemented.');
  }

  Future<void> setReverbDamping(double damping) {
    throw UnimplementedError('setReverbDamping() has not been implemented.');
  }

  Future<void> setReverbWidth(double width) {
    throw UnimplementedError('setReverbWidth() has not been implemented.');
  }

  // ===== DELAY CONTROLS =====

  Future<void> setDelayEnabled(bool enabled) {
    throw UnimplementedError('setDelayEnabled() has not been implemented.');
  }

  Future<void> setDelayTime(double seconds) {
    throw UnimplementedError('setDelayTime() has not been implemented.');
  }

  Future<void> setDelayFeedback(double feedback) {
    throw UnimplementedError('setDelayFeedback() has not been implemented.');
  }

  Future<void> setDelayMix(double mix) {
    throw UnimplementedError('setDelayMix() has not been implemented.');
  }
}
