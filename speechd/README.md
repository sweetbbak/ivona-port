# speech-dispatcher module

`sd_ivona-port` makes the IVONA engine with the Amy voice (British English) a
speech-dispatcher output module. Screen readers such as Orca and any program using
speech-dispatcher (`spd-say`) can then use it.

## Install

```
speechd/install.sh /path/to/eng.gbr.amy.1.6.101.3          # PREFIX defaults to /usr/local
spd-say -o ivona-port "Hello world"
```

The script fetches and builds the third-party libraries, the engine and the module, then
installs them with `sudo`. The voice directory must hold `vox_en_gb_amy22i` and
`lang_en_gb.dat`; they are copied into the installation and never into the repository. You need
speech-dispatcher's development files (`pkg-config speech-dispatcher`).

To make Amy the default voice, add this to `~/.config/speech-dispatcher/speechd.conf` (or to
`/etc/speech-dispatcher/speechd.conf`):

```
DefaultModule ivona-port
```

The module is named `ivona-port` because speech-dispatcher already has an `ivona` module, for
IVONA's old Linux SDK. speech-dispatcher finds it without any `AddModule` line: it autodetects
binaries named `sd_<module>` that have a `<module>.conf`. If you add the line anyway, it is
`AddModule "ivona-port" "sd_ivona-port" "ivona-port.conf"`.

## Manual steps

```
make && make -C speechd
sudo make -C speechd install VOICE_DIR=/path/to/eng.gbr.amy.1.6.101.3 [PREFIX=/usr]
sudo make -C speechd uninstall
```

Installed files:

| What | Where |
|---|---|
| The module | speech-dispatcher's module directory (`pkg-config --variable=modulebindir speech-dispatcher`) |
| Configuration | `/etc/speech-dispatcher/modules/ivona-port.conf` (`VoiceDir`, `VoiceLib`) |
| Libraries | `$PREFIX/lib/ivona-port` |
| Voice data | `$PREFIX/share/ivona-port/voice` |

## How it works

- **Synthesis.** The module loads the engine and the voice once. It speaks each message
  synchronously, in 0.1 s chunks that speech-dispatcher plays as they arrive, so playback starts
  almost at once.
- **SSML.** The server sends messages as SSML. The module removes the tags and reports each
  `<mark>` as an index mark.
- **Settings.** Rate, pitch and volume (−100…100) map onto the engine's voice parameters.
- **Stop and pause.** These interrupt synthesis between chunks.

Standalone test, without speech-dispatcher:

```
printf 'INIT\nSPEAK\n<speak>Hello world.</speak>\n.\nQUIT\n' | \
    LD_LIBRARY_PATH=build/x86_64-pc-linux-gnu speechd/sd_ivona-port my.conf | grep -av '^705'
```
