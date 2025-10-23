#include <jni.h>
#include <fluidsynth.h>
#include <unistd.h>
#include <map>

std::map<int, fluid_synth_t*> synths = {};
std::map<int, fluid_audio_driver_t*> drivers = {};
std::map<int, fluid_settings_t*> settings = {};
std::map<int, int> soundfonts = {};
int nextSfId = 1;

extern "C" JNIEXPORT int JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_loadSoundfont(JNIEnv* env, jclass clazz, jstring path, jint bank, jint program) {
    settings[nextSfId] = new_fluid_settings();
    fluid_settings_setnum(settings[nextSfId], "synth.gain", 1.0);
    // sayısal değerleri uygun setter ile ayarla
    fluid_settings_setint(settings[nextSfId], "audio.period-size", 64);
    fluid_settings_setint(settings[nextSfId], "audio.periods", 4);
    fluid_settings_setint(settings[nextSfId], "audio.realtime-prio", 99);
    fluid_settings_setnum(settings[nextSfId], "synth.sample-rate", 44100.0);
    fluid_settings_setint(settings[nextSfId], "synth.polyphony", 32);

    const char *nativePath = env->GetStringUTFChars(path, nullptr);
    synths[nextSfId] = new_fluid_synth(settings[nextSfId]);
    int sfId = fluid_synth_sfload(synths[nextSfId], nativePath, 0);
    for (int i = 0; i < 16; i++) {
        fluid_synth_program_select(synths[nextSfId], i, sfId, bank, program);
    }
    env->ReleaseStringUTFChars(path, nativePath);
    // Audio driver'ı en son oluştur
    drivers[nextSfId] = new_fluid_audio_driver(settings[nextSfId], synths[nextSfId]);
    soundfonts[nextSfId] = sfId;
    nextSfId++;
    return nextSfId - 1;
}

extern "C" JNIEXPORT void JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_selectInstrument(JNIEnv* env, jclass clazz, jint sfId, jint channel, jint bank, jint program) {
    fluid_synth_program_select(synths[sfId], channel, soundfonts[sfId], bank, program);
}

extern "C" JNIEXPORT void JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_playNote(JNIEnv* env, jclass clazz, jint channel, jint key, jint velocity, jint sfId) {
    fluid_synth_noteon(synths[sfId], channel, key, velocity);
}

extern "C" JNIEXPORT void JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_stopNote(JNIEnv* env, jclass clazz, jint channel, jint key, jint sfId) {
    fluid_synth_noteoff(synths[sfId], channel, key);
}

extern "C" JNIEXPORT void JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_stopAllNotes(JNIEnv* env, jclass clazz, jint sfId) {
    fluid_synth_all_notes_off(synths[sfId], -1);
    fluid_synth_system_reset(synths[sfId]);
}

extern "C" JNIEXPORT void JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_unloadSoundfont(JNIEnv* env, jclass clazz, jint sfId) {
    delete_fluid_audio_driver(drivers[sfId]);
    delete_fluid_synth(synths[sfId]);
    synths.erase(sfId);
    drivers.erase(sfId);
    soundfonts.erase(sfId);
}

extern "C" JNIEXPORT void JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_dispose(JNIEnv* env, jclass clazz) {
    for (auto const& x : synths) {
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
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_setReverbEnabled(JNIEnv* env, jclass clazz, jboolean enabled) {
    // Apply to all synths
    for (auto const& synth : synths) {
        fluid_synth_reverb_on(synth.second, -1, enabled ? 1 : 0);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_setReverbLevel(JNIEnv* env, jclass clazz, jdouble level) {
    // Apply to all synths
    for (auto const& synth : synths) {
        double roomsize = fluid_synth_get_reverb_roomsize(synth.second);
        double damping = fluid_synth_get_reverb_damp(synth.second);
        double width = fluid_synth_get_reverb_width(synth.second);
        // Set with new level (0.0-1.0)
        fluid_synth_set_reverb(synth.second, roomsize, damping, width, level);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_setReverbRoomSize(JNIEnv* env, jclass clazz, jdouble size) {
    // Apply to all synths
    for (auto const& synth : synths) {
        double damping = fluid_synth_get_reverb_damp(synth.second);
        double width = fluid_synth_get_reverb_width(synth.second);
        double level = fluid_synth_get_reverb_level(synth.second);
        // FluidSynth roomsize range is 0.0-1.2, we map 0.0-1.0 to 0.0-1.2
        fluid_synth_set_reverb(synth.second, size * 1.2, damping, width, level);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_setReverbDamping(JNIEnv* env, jclass clazz, jdouble damping) {
    // Apply to all synths
    for (auto const& synth : synths) {
        double roomsize = fluid_synth_get_reverb_roomsize(synth.second);
        double width = fluid_synth_get_reverb_width(synth.second);
        double level = fluid_synth_get_reverb_level(synth.second);
        // Set with new damping (0.0-1.0)
        fluid_synth_set_reverb(synth.second, roomsize, damping, width, level);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_setReverbWidth(JNIEnv* env, jclass clazz, jdouble width) {
    // Apply to all synths
    for (auto const& synth : synths) {
        double roomsize = fluid_synth_get_reverb_roomsize(synth.second);
        double damping = fluid_synth_get_reverb_damp(synth.second);
        double level = fluid_synth_get_reverb_level(synth.second);
        // FluidSynth width range is 0.0-100.0, we map 0.0-1.0 to 0.0-100.0
        fluid_synth_set_reverb(synth.second, roomsize, damping, width * 100.0, level);
    }
}
