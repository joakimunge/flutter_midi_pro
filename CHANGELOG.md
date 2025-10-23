## 1.0.0

- Initial release.

## 1.0.1

- Readme added.

## 1.0.3

- Minor fix.

## 1.0.4

- Class name FlutterMidiPro to MidiPro

## 1.0.6

- Instance error fixed.

## 2.0.0

- Instrument change added.
- Faster and more stable especially for Android.

## 2.0.1

- Stop all notes added.

## 3.0.0

- Stop all notes deleted.
- Init method deleted.
- Android sythesizer method changed to fluidsynth for better performance, stability and sound quality.
- iOS method equalizated with Android methods.

## 3.0.1

- Readme updated.

## 3.1.0

- Click sound when loading sf2 file was fixed.

## 3.1.1

- Low sound level on Android was fixed.

## 3.1.2

- 1 second delay added when loading sf2 file.

## 3.1.3

- Sound level fix.

## 3.1.4

- Cmake minsdkversion fix

## 3.1.5

- Support for 16kb page size
- Version bump for android side

## 3.2.0

- Added reverb audio effect controls:
  - `setReverbEnabled()` - Enable or disable reverb
  - `setReverbLevel()` - Control reverb wet/dry mix (0.0-1.0)
  - `setReverbRoomSize()` - Control room size (0.0-1.0)
  - `setReverbDamping()` - Control damping amount (0.0-1.0)
  - `setReverbWidth()` - Control stereo width (0.0-1.0)
- Added delay audio effect controls:
  - `setDelayEnabled()` - Enable or disable delay
  - `setDelayTime()` - Control delay time in seconds (0.0-2.0)
  - `setDelayFeedback()` - Control feedback/repeats (0.0-1.0)
  - `setDelayMix()` - Control delay wet/dry mix (0.0-1.0)
- Implemented FluidSynth reverb for Android platform
- Fixed initialization of audio effects
