import Flutter
import CoreMIDI
import AVFAudio
import AVFoundation
import CoreAudio

public class FlutterMidiProPlugin: NSObject, FlutterPlugin {
  var audioEngines: [Int: [AVAudioEngine]] = [:]
  var soundfontIndex = 1
  var soundfontSamplers: [Int: [AVAudioUnitSampler]] = [:]
  var soundfontURLs: [Int: URL] = [:]

  // Effect nodes per soundfont per channel
  var reverbNodes: [Int: [AVAudioUnitReverb]] = [:]
  var delayNodes: [Int: [AVAudioUnitDelay]] = [:]

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_midi_pro", binaryMessenger: registrar.messenger())
    let instance = FlutterMidiProPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "loadSoundfont":
        let args = call.arguments as! [String: Any]
        let path = args["path"] as! String
        let bank = args["bank"] as! Int
        let program = args["program"] as! Int
        let url = URL(fileURLWithPath: path)
        var chSamplers: [AVAudioUnitSampler] = []
        var chAudioEngines: [AVAudioEngine] = []
        var chReverbNodes: [AVAudioUnitReverb] = []
        var chDelayNodes: [AVAudioUnitDelay] = []

        for _ in 0...15 {
            let sampler = AVAudioUnitSampler()
            let audioEngine = AVAudioEngine()
            let reverb = AVAudioUnitReverb()
            let delay = AVAudioUnitDelay()

            audioEngine.attach(sampler)
            audioEngine.attach(delay)
            audioEngine.attach(reverb)

            audioEngine.connect(sampler, to: delay, format: nil)
            audioEngine.connect(delay, to: reverb, format: nil)
            audioEngine.connect(reverb, to: audioEngine.mainMixerNode, format:nil)

            reverb.wetDryMix = 0.0
            delay.wetDryMix = 0.0
            delay.delayTime = 0.5
            delay.feedback = 50.0

            do {
                try audioEngine.start()
            } catch {
                result(FlutterError(code: "AUDIO_ENGINE_START_FAILED", message: "Failed to start audio engine", details: nil))
                return
            }
            do {
                let isPercussion = (bank == 128)
                let bankMSB: UInt8 = isPercussion ? UInt8(kAUSampler_DefaultPercussionBankMSB) : UInt8(kAUSampler_DefaultMelodicBankMSB)
                let bankLSB: UInt8 = isPercussion ? 0 : UInt8(bank)

                try sampler.loadSoundBankInstrument(at: url, program: UInt8(program), bankMSB: bankMSB, bankLSB: bankLSB)
            } catch {
                result(FlutterError(code: "SOUND_FONT_LOAD_FAILED1", message: "Failed to load soundfont", details: nil))
                return
            }
            chSamplers.append(sampler)
            chAudioEngines.append(audioEngine)
            chReverbNodes.append(reverb)
            chDelayNodes.append(delay)
        }
        soundfontSamplers[soundfontIndex] = chSamplers
        soundfontURLs[soundfontIndex] = url
        audioEngines[soundfontIndex] = chAudioEngines
        reverbNodes[soundfontIndex] = chReverbNodes
        delayNodes[soundfontIndex] = chDelayNodes
        soundfontIndex += 1
        result(soundfontIndex-1)
    case "stopAllNotes":
        let args = call.arguments as! [String: Any]
        let sfId = args["sfId"] as! Int
        let soundfontSampler = soundfontSamplers[sfId]
        if soundfontSampler == nil {
            result(FlutterError(code: "SOUND_FONT_NOT_FOUND", message: "Soundfont not found", details: nil))
            return
        }
        soundfontSampler!.enumerated().forEach { (channel, sampler) in
            for note in 0...127 {
                sampler.stopNote(UInt8(note), onChannel: UInt8(channel))
            }
        }
        result(nil)
    case "selectInstrument":
        let args = call.arguments as! [String: Any]
        let sfId = args["sfId"] as! Int
        let channel = args["channel"] as! Int
        let bank = args["bank"] as! Int
        let program = args["program"] as! Int
        let soundfontSampler = soundfontSamplers[sfId]![channel]
        let soundfontUrl = soundfontURLs[sfId]!
        do {
            let isPercussion = (bank == 128)
            let bankMSB: UInt8 = isPercussion ? UInt8(kAUSampler_DefaultPercussionBankMSB) : UInt8(kAUSampler_DefaultMelodicBankMSB)
            let bankLSB: UInt8 = isPercussion ? 0 : UInt8(bank)

            try soundfontSampler.loadSoundBankInstrument(at: soundfontUrl, program: UInt8(program), bankMSB: bankMSB, bankLSB: bankLSB)
        } catch {
            result(FlutterError(code: "SOUND_FONT_LOAD_FAILED2", message: "Failed to load soundfont", details: nil))
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
        reverbNodes.removeValue(forKey: sfId)
        delayNodes.removeValue(forKey: sfId)
        result(nil)
    case "dispose":
        audioEngines.forEach { (key, value) in
            value.forEach { (audioEngine) in
                audioEngine.stop()
            }
        }
        audioEngines = [:]
        soundfontSamplers = [:]
        reverbNodes = [:]
        delayNodes = [:]
        result(nil)

    case "setReverbEnabled":
        let args = call.arguments as! [String: Any]
        let enabled = args["enabled"] as! Bool
        reverbNodes.values.forEach { nodes in
            nodes.forEach { reverb in
                if enabled {
                    reverb.loadFactoryPreset(.mediumHall)
                    reverb.wetDryMix = 40.0
                } else {
                    reverb.wetDryMix = 0.0
                }
            }
        }
        result(nil)

    case "setReverbLevel":
        let args = call.arguments as! [String: Any]
        let level = args["level"] as! Double
        reverbNodes.values.forEach { nodes in
            nodes.forEach { reverb in
                reverb.wetDryMix = Float(level * 100.0)
            }
        }
        result(nil)

    case "setReverbRoomSize":
        let args = call.arguments as! [String: Any]
        let size = args["size"] as! Double
        reverbNodes.values.forEach { nodes in
            nodes.forEach { reverb in
                if size < 0.3 {
                    reverb.loadFactoryPreset(.smallRoom)
                } else if size < 0.6 {
                    reverb.loadFactoryPreset(.mediumRoom)
                } else {
                    reverb.loadFactoryPreset(.largeHall)
                }
            }
        }
        result(nil)

    case "setReverbDamping":
        // AVAudioUnitReverb doesn't have direct damping control
        result(nil)

    case "setReverbWidth":
        // AVAudioUnitReverb doesn't have direct width control
        result(nil)
    
    // Delay controls
    case "setDelayEnabled":
        let args = call.arguments as! [String: Any]
        let enabled = args["enabled"] as! Bool
        // Apply to all delay nodes
        delayNodes.values.forEach { nodes in
            nodes.forEach { delay in
                delay.wetDryMix = enabled ? 50.0 : 0.0
            }
        }
        result(nil)

    case "setDelayTime":
        let args = call.arguments as! [String: Any]
        let seconds = args["seconds"] as! Double
        delayNodes.values.forEach { nodes in
            nodes.forEach { delay in
                delay.delayTime = min(max(seconds, 0.0), 2.0)
            }
        }
        result(nil)

    case "setDelayFeedback":
        let args = call.arguments as! [String: Any]
        let feedback = args["feedback"] as! Double
        delayNodes.values.forEach { nodes in
            nodes.forEach { delay in
                delay.feedback = Float(feedback * 100.0)
            }
        }
        result(nil)

    case "setDelayMix":
        let args = call.arguments as! [String: Any]
        let mix = args["mix"] as! Double
        delayNodes.values.forEach { nodes in
            nodes.forEach { delay in
                delay.wetDryMix = Float(mix * 100.0)
            }
        }
        result(nil)

    default:
      result(FlutterMethodNotImplemented)
        break
    }
  }
}
