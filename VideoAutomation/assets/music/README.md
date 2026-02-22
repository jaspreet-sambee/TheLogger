# Background Music

Place a royalty-free lo-fi / gym track here as `gym-lofi.mp3`.

The `add-effects.sh` script looks for this file when `music: true` is set in a
workflow YAML. If the file is missing, the script skips music and prints a warning.

## Sources (CC0 / royalty-free)

- **Pixabay** — https://pixabay.com/music/
  Search "lofi", "gym", or "workout". Filter by CC0.

- **Free Music Archive** — https://freemusicarchive.org
  Filter by license → "CC0 1.0 Universal".

## Recommended specs

| Property   | Target          |
|------------|-----------------|
| Format     | MP3             |
| Length     | 30–60 seconds   |
| Tempo      | 85–100 BPM      |
| Style      | Lo-fi / chill gym beat |

## Placement

Save the file as:

```
VideoAutomation/assets/music/gym-lofi.mp3
```

The effects pipeline mixes it in at the volume specified by `music_volume` in
each workflow YAML (default: 0.25) and applies a 2-second fade-out at the end.

> **Note**: `gym-lofi.mp3` is listed in `.gitignore` to avoid committing
> large binary audio files to the repository.
