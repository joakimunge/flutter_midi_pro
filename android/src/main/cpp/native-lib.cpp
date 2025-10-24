#include <jni.h>
#include <fluidsynth.h>
#include <fluidsynth/gen.h>
#include <unistd.h>
#include <map>
#include <android/log.h>

#define LOG_TAG "FlutterMidiPro"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

std::map<int, fluid_synth_t *> synths = {};
std::map<int, fluid_audio_driver_t *> drivers = {};
std::map<int, fluid_settings_t *> settings = {};
std::map<int, int> soundfonts = {};
int nextSfId = 1;

// Reverb state tracking - stored in user input range (0.0-1.0)
bool reverbEnabled = true;
double reverbRoomSize = 0.2; // Maps to FluidSynth 0.24 (0.2 * 1.2)
double reverbDamping = 0.5; // Default damping (was 0.0, which may be too dry)
double reverbWidth = 0.5; // Maps to FluidSynth 50.0 (0.5 * 100)
double reverbLevel = 0.9;

extern "C" JNIEXPORT int JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_loadSoundfont(JNIEnv *env, jclass clazz, jstring path, jint bank, jint program)
{
    settings[nextSfId] = new_fluid_settings();
    fluid_settings_setnum(settings[nextSfId], "synth.gain", 1.0);
    // sayısal değerleri uygun setter ile ayarla
    fluid_settings_setint(settings[nextSfId], "audio.period-size", 64);
    fluid_settings_setint(settings[nextSfId], "audio.periods", 4);
    fluid_settings_setint(settings[nextSfId], "audio.realtime-prio", 99);
    fluid_settings_setnum(settings[nextSfId], "synth.sample-rate", 44100.0);
    fluid_settings_setint(settings[nextSfId], "synth.polyphony", 32);

    // Enable reverb and chorus in settings
    fluid_settings_setint(settings[nextSfId], "synth.reverb.active", 1);
    fluid_settings_setint(settings[nextSfId], "synth.chorus.active", 1);

    const char *nativePath = env->GetStringUTFChars(path, nullptr);
    synths[nextSfId] = new_fluid_synth(settings[nextSfId]);
    int sfId = fluid_synth_sfload(synths[nextSfId], nativePath, 0);
    for (int i = 0; i < 16; i++)
    {
        fluid_synth_program_select(synths[nextSfId], i, sfId, bank, program);
        // Set reverb send level for each channel (200 centibels = moderate reverb)
        fluid_synth_set_gen(synths[nextSfId], i, GEN_REVERBSEND, 200.0f);
    }
    env->ReleaseStringUTFChars(path, nativePath);

    LOGD("Reverb send levels set to 200.0 for all 16 channels");

    // Initialize reverb BEFORE creating audio driver using modern group-based API
    // fx_group = -1 applies to all effect groups
    int reverbRoomResult = fluid_synth_set_reverb_group_roomsize(synths[nextSfId], -1, reverbRoomSize * 1.2);
    int reverbDampResult = fluid_synth_set_reverb_group_damp(synths[nextSfId], -1, reverbDamping);
    int reverbWidthResult = fluid_synth_set_reverb_group_width(synths[nextSfId], -1, reverbWidth * 100.0);
    int reverbLevelResult = fluid_synth_set_reverb_group_level(synths[nextSfId], -1, reverbLevel);
    // Then enable/disable reverb
    int reverbOnResult = fluid_synth_reverb_on(synths[nextSfId], -1, reverbEnabled ? 1 : 0);

    LOGD("Reverb initialization - Room: %d, Damp: %d, Width: %d, Level: %d, On: %d",
         reverbRoomResult, reverbDampResult, reverbWidthResult, reverbLevelResult, reverbOnResult);
    LOGD("Reverb parameters - Room: %.2f, Damp: %.2f, Width: %.2f, Level: %.2f, Enabled: %d",
         reverbRoomSize * 1.2, reverbDamping, reverbWidth * 100.0, reverbLevel, reverbEnabled);

    // Audio driver'ı en son oluştur
    drivers[nextSfId] = new_fluid_audio_driver(settings[nextSfId], synths[nextSfId]);
    soundfonts[nextSfId] = sfId;
    nextSfId++;
    return nextSfId - 1;
}

extern "C" JNIEXPORT void JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_selectInstrument(JNIEnv *env, jclass clazz, jint sfId, jint channel, jint bank, jint program)
{
    fluid_synth_program_select(synths[sfId], channel, soundfonts[sfId], bank, program);
    // Set reverb send level for the channel (200 centibels = moderate reverb)
    fluid_synth_set_gen(synths[sfId], channel, GEN_REVERBSEND, 200.0f);
    LOGD("Reverb send level set to 200.0 for channel %d", channel);
}

extern "C" JNIEXPORT void JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_playNote(JNIEnv *env, jclass clazz, jint channel, jint key, jint velocity, jint sfId)
{
    fluid_synth_noteon(synths[sfId], channel, key, velocity);
}

extern "C" JNIEXPORT void JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_stopNote(JNIEnv *env, jclass clazz, jint channel, jint key, jint sfId)
{
    fluid_synth_noteoff(synths[sfId], channel, key);
}

extern "C" JNIEXPORT void JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_stopAllNotes(JNIEnv *env, jclass clazz, jint sfId)
{
    fluid_synth_all_notes_off(synths[sfId], -1);
    fluid_synth_system_reset(synths[sfId]);
}

extern "C" JNIEXPORT void JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_unloadSoundfont(JNIEnv *env, jclass clazz, jint sfId)
{
    delete_fluid_audio_driver(drivers[sfId]);
    delete_fluid_synth(synths[sfId]);
    synths.erase(sfId);
    drivers.erase(sfId);
    soundfonts.erase(sfId);
}

extern "C" JNIEXPORT void JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_dispose(JNIEnv *env, jclass clazz)
{
    for (auto const &x : synths)
    {
        delete_fluid_audio_driver(drivers[x.first]);
        delete_fluid_synth(synths[x.first]);
        delete_fluid_settings(settings[x.first]);
    }
    synths.clear();
    drivers.clear();
    soundfonts.clear();
}

// ===== REVERB CONTROLS =====

extern "C" JNIEXPORT void JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_setReverbEnabled(JNIEnv *env, jclass clazz, jboolean enabled)
{
    // Update state
    reverbEnabled = enabled;

    LOGD("setReverbEnabled called: %d", enabled);

    // Apply to all synths
    for (auto const &synth : synths)
    {
        int result = fluid_synth_reverb_on(synth.second, -1, enabled ? 1 : 0);
        LOGD("  Synth %d: reverb_on result = %d", synth.first, result);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_setReverbLevel(JNIEnv *env, jclass clazz, jdouble level)
{
    // Update state
    reverbLevel = level;

    LOGD("setReverbLevel called: %.2f", level);

    // Apply to all synths using modern group-based API
    for (auto const &synth : synths)
    {
        int result = fluid_synth_set_reverb_group_level(synth.second, -1, reverbLevel);
        LOGD("  Synth %d: set_reverb_group_level result = %d", synth.first, result);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_setReverbRoomSize(JNIEnv *env, jclass clazz, jdouble size)
{
    // Update state (store unscaled user input 0.0-1.0)
    reverbRoomSize = size;

    LOGD("setReverbRoomSize called: %.2f", size);

    // Apply to all synths using modern group-based API (scale for FluidSynth: 0.0-1.2)
    for (auto const &synth : synths)
    {
        int result = fluid_synth_set_reverb_group_roomsize(synth.second, -1, reverbRoomSize * 1.2);
        LOGD("  Synth %d: set_reverb_group_roomsize result = %d", synth.first, result);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_setReverbDamping(JNIEnv *env, jclass clazz, jdouble damping)
{
    // Update state
    reverbDamping = damping;

    LOGD("setReverbDamping called: %.2f", damping);

    // Apply to all synths using modern group-based API
    for (auto const &synth : synths)
    {
        int result = fluid_synth_set_reverb_group_damp(synth.second, -1, reverbDamping);
        LOGD("  Synth %d: set_reverb_group_damp result = %d", synth.first, result);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_setReverbWidth(JNIEnv *env, jclass clazz, jdouble width)
{
    // Update state
    reverbWidth = width;

    LOGD("setReverbWidth called: %.2f", width);

    // Apply to all synths using modern group-based API (scale for FluidSynth: 0.0-100.0)
    for (auto const &synth : synths)
    {
        int result = fluid_synth_set_reverb_group_width(synth.second, -1, reverbWidth * 100.0);
        LOGD("  Synth %d: set_reverb_group_width result = %d", synth.first, result);
    }
}
