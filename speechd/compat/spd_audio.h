/* Some speech-dispatcher packages install spd_module_main.h without the spd_audio.h it includes;
 * the types it needs (AudioTrack, AudioFormat) are in spd_audio_plugin.h. Searched after the
 * system headers (-idirafter), so a complete installation's own header wins. */
#include <spd_audio_plugin.h>
