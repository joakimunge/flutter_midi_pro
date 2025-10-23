import FlutterMacOS
import CoreMIDI
import AVFAudio
import AVFoundation
import CoreAudio

public class FlutterMidiProPlugin: NSObject, FlutterPlugin {
  var audioEngines: [Int: [AVAudioEngine]] = [:]
  var soundfontIndex = 1
  var soundfontSamplers: [Int: [AVAudioUnitSampler]] = [:]
  var soundfontURLs: [Int: URL] = [:]

  // Global effect nodes (shared across all soundfonts)
  var reverbNode = AVAudioUnitReverb()
  var delayNode = AVAudioUnitDelay()
  var effectsEngine = AVAudioEngine()
  var effectsInitialized = false

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_midi_pro", binaryMessenger: registrar.messenger)
    let instance = FlutterMidiProPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  private func initializeEffects() {
    if !effectsInitialized {
      effectsEngine.attach(reverbNode)
      effectsEngine.attach(delayNode)

      // Initialize with effects bypassed
      reverbNode.wetDryMix = 0.0
      delayNode.wetDryMix = 0.0
      delayNode.delayTime = 0.5
      delayNode.feedback = 50.0

      effectsInitialized = true
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "loadSoundfont":
        initializeEffects()
        let args = call.arguments as! [String: Any]
        let path = args["path"] as! String
        let bank = args["bank"] as! Int
        let program = args["program"] as! Int
        let url = URL(fileURLWithPath: path)
        var chSamplers: [AVAudioUnitSampler] = []
        var chAudioEngines: [AVAudioEngine] = []
        for _ in 0...15 {
            let sampler = AVAudioUnitSampler()
            let audioEngine = AVAudioEngine()
            audioEngine.attach(sampler)

            // Connect: sampler -> delay -> reverb -> output
            audioEngine.attach(delayNode)
            audioEngine.attach(reverbNode)
            audioEngine.connect(sampler, to: delayNode, format: nil)
            audioEngine.connect(delayNode, to: reverbNode, format: nil)
            audioEngine.connect(reverbNode, to: audioEngine.mainMixerNode, format:nil)

            do {
                try audioEngine.start()
            } catch {
                result(FlutterError(code: "AUDIO_ENGINE_START_FAILED", message: "Failed to start audio engine", details: nil))
                return
            }
            do {
                try sampler.loadSoundBankInstrument(at: url, program: UInt8(program), bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB), bankLSB: UInt8(bank))
            } catch {
                result(FlutterError(code: "SOUND_FONT_LOAD_FAILED", message: "Failed to load soundfont", details: nil))
                return
            }
            chSamplers.append(sampler)
            chAudioEngines.append(audioEngine)
        }
        soundfontSamplers[soundfontIndex] = chSamplers
        soundfontURLs[soundfontIndex] = url
        audioEngines[soundfontIndex] = chAudioEngines
        soundfontIndex += 1
        result(soundfontIndex-1)
    case "selectInstrument":
        let args = call.arguments as! [String: Any]
        let sfId = args["sfId"] as! Int
        let channel = args["channel"] as! Int
        let bank = args["bank"] as! Int
        let program = args["program"] as! Int
        let soundfontSampler = soundfontSamplers[sfId]![channel]
        let soundfontUrl = soundfontURLs[sfId]!
        do {
            try soundfontSampler.loadSoundBankInstrument(at: soundfontUrl, program: UInt8(program), bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB), bankLSB: UInt8(bank))
        } catch {
            result(FlutterError(code: "SOUND_FONT_LOAD_FAILED", message: "Failed to load soundfont", details: nil))
            return
        }
        soundfontSampler.sendProgramChange(UInt8(program), bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB), bankLSB: UInt8(bank), onChannel: UInt8(channel))
        result(nil)
    case "playNote":
        let args = call.arguments as! [String: Any]
        let channel = args["channel"] as! Int
        let note = args["key"] as! Int
        let velocity = args["velocity"] as! Int
        let sfId = args["sfId"] as! Int
        let soundfontSampler = soundfontSamplers[sfId]![channel]
        soundfontSampler.startNote(UInt8(note), withVelocity: UInt8(velocity), onChannel: UInt8(channel))
        result(nil)
    case "stopNote":
        let args = call.arguments as! [String: Any]
        let channel = args["channel"] as! Int
        let note = args["key"] as! Int
        let sfId = args["sfId"] as! Int
        let soundfontSampler = soundfontSamplers[sfId]![channel]
        soundfontSampler.stopNote(UInt8(note), onChannel: UInt8(channel))
        result(nil)
    case "stopAllNotes":
        let args = call.arguments as! [String: Any]
        let sfId = args["sfId"] as! Int
        let soundfontSampler = soundfontSamplers[sfId]
        if soundfontSampler == nil {
            result(FlutterError(code: "SOUND_FONT_NOT_FOUND", message: "Soundfont not found", details: nil))
            return
        }
        soundfontSampler!.forEach { (sampler) in
            sampler.stopAllNotes()
        }
        result(nil)
    case "unloadSoundfont":
        let args = call.arguments as! [String:Any]
        let sfId = args["sfId"] as! Int
        let soundfontSampler = soundfontSamplers[sfId]
        if soundfontSampler == nil {
            result(FlutterError(code: "SOUND_FONT_NOT_FOUND", message: "Soundfont not found", details: nil))
            return
        }
        audioEngines[sfId]?.forEach { (audioEngine) in
            audioEngine.stop()
        }
        audioEngines.removeValue(forKey: sfId)
        soundfontSamplers.removeValue(forKey: sfId)
        soundfontURLs.removeValue(forKey: sfId)
        result(nil)
    case "dispose":
        audioEngines.forEach { (key, value) in
            value.forEach { (audioEngine) in
                audioEngine.stop()
            }
        }
        audioEngines = [:]
        soundfontSamplers = [:]
        result(nil)

    // ===== REVERB CONTROLS =====

    case "setReverbEnabled":
        let args = call.arguments as! [String: Any]
        let enabled = args["enabled"] as! Bool
        if enabled {
            reverbNode.loadFactoryPreset(.mediumHall)
            reverbNode.wetDryMix = 40.0 // Default 40% wet
        } else {
            reverbNode.wetDryMix = 0.0
        }
        result(nil)

    case "setReverbLevel":
        let args = call.arguments as! [String: Any]
        let level = args["level"] as! Double
        // Convert 0.0-1.0 to 0-100 for wetDryMix
        reverbNode.wetDryMix = Float(level * 100.0)
        result(nil)

    case "setReverbRoomSize":
        // Note: AVAudioUnitReverb uses presets, so we switch presets based on room size
        let args = call.arguments as! [String: Any]
        let size = args["size"] as! Double
        if size < 0.3 {
            reverbNode.loadFactoryPreset(.smallRoom)
        } else if size < 0.6 {
            reverbNode.loadFactoryPreset(.mediumRoom)
        } else {
            reverbNode.loadFactoryPreset(.largeHall)
        }
        result(nil)

    case "setReverbDamping":
        // AVAudioUnitReverb doesn't have direct damping control
        // This is handled by the preset selection
        result(nil)

    case "setReverbWidth":
        // AVAudioUnitReverb doesn't have direct width control
        // This is handled by the preset selection
        result(nil)

    // ===== DELAY CONTROLS =====

    case "setDelayEnabled":
        let args = call.arguments as! [String: Any]
        let enabled = args["enabled"] as! Bool
        if enabled {
            delayNode.wetDryMix = 50.0 // Default 50% wet
        } else {
            delayNode.wetDryMix = 0.0
        }
        result(nil)

    case "setDelayTime":
        let args = call.arguments as! [String: Any]
        let seconds = args["seconds"] as! Double
        // Clamp to valid range (0.0 - 2.0 seconds)
        delayNode.delayTime = min(max(seconds, 0.0), 2.0)
        result(nil)

    case "setDelayFeedback":
        let args = call.arguments as! [String: Any]
        let feedback = args["feedback"] as! Double
        // Convert 0.0-1.0 to -100.0 to 100.0 range
        delayNode.feedback = Float(feedback * 100.0)
        result(nil)

    case "setDelayMix":
        let args = call.arguments as! [String: Any]
        let mix = args["mix"] as! Double
        // Convert 0.0-1.0 to 0-100 for wetDryMix
        delayNode.wetDryMix = Float(mix * 100.0)
        result(nil)

    default:
      result(FlutterMethodNotImplemented)
        break
    }
  }
}
