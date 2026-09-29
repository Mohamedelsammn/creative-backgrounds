# Video Wallpaper Encoding Spec

**For:** backend / transcoding pipeline (the `TRANSCODE` job)
**Status:** required — current output does not play on a large share of Android devices
**Date:** 2026-08-26

---

## The problem

A published clip fails to decode on a real device. Verified on an **OPPO CPH1823
(Android 10, MediaTek)** with the wallpaper titled `hevc`:

```
MtkACodec: setMTKParameters, width: 1080  height: 1920
ACodec:    setting nBufferCountActual to 14 failed: -22
ACodec:    setting nBufferCountActual to 13 failed: -22
ACodec:    setting nBufferCountActual to 12 failed: -22
ACodec:    setting nBufferCountActual to 11 failed: -22
ACodec:    Failed to allocate buffers after transitioning to IDLE state (0xffffffea)
MediaCodec: Codec reported err 0xffffffea
```

`-22` is `EINVAL`: the hardware decoder rejected the configuration outright. It
never produced a single frame.

### Why

The clip's `avcC` box was parsed directly from the MP4:

| field | current value |
|---|---|
| codec | H.264 (AVC) |
| **profile** | **High (100)** |
| **level** | **4.0** |
| resolution | 1080 × 1920 |
| duration | 5 s |
| size | 1.26 MB |

**H.264 High Profile @ Level 4.0 at 1080×1920** is too demanding for many
mid-range and older Android chipsets. High Profile uses CABAC entropy coding and
8×8 transforms, which a number of MediaTek/Spreadtrum decoders only support at
lower levels — or not at all in combination with this buffer count.

The asset name (`hevc`) suggests the source was HEVC and the transcode targeted
quality rather than device reach.

---

## Required output

```
Container      : MP4  (faststart / moov atom at the front)
Video codec    : H.264 (AVC)
Profile        : baseline   ← widest support
                 main       ← acceptable
Level          : 3.1  (do not exceed)
Resolution     : 720 × 1280   (portrait)
Frame rate     : 30 fps max
Bitrate        : 1.5 – 2.5 Mbps  (VBR)
Keyframe (GOP) : every 1–2 s
Pixel format   : yuv420p        ← mandatory
Audio          : none (strip it — wallpapers are silent)
B-frames       : 0  (baseline forbids them anyway)
```

### Why these values

- **Baseline/Main @ 3.1** decodes on essentially every Android device from 2015
  onward. High @ 4.0 does not.
- **720×1280** is more than enough for a wallpaper — it is scaled to the screen
  and sits behind icons. It also roughly quarters the decoder's memory need,
  which is what actually failed here.
- **yuv420p** — some encoders default to `yuv444p` or `yuv420p10le`, which no
  consumer Android hardware decoder accepts.
- **No audio** — the app mutes playback anyway; the track is wasted bytes.
- **faststart** lets playback begin before the whole file arrives.

---

## Reference command (ffmpeg)

```bash
ffmpeg -i input.mp4 \
  -c:v libx264 \
  -profile:v baseline \
  -level:v 3.1 \
  -pix_fmt yuv420p \
  -vf "scale=720:1280:force_original_aspect_ratio=increase,crop=720:1280" \
  -r 30 \
  -b:v 2M -maxrate 2.5M -bufsize 4M \
  -g 60 -keyint_min 30 \
  -an \
  -movflags +faststart \
  output.mp4
```

For a **Main profile** variant (slightly better quality, still broadly safe),
swap `-profile:v baseline` for `-profile:v main`.

---

## How to verify before publishing

```bash
ffprobe -v error \
  -select_streams v:0 \
  -show_entries stream=codec_name,profile,level,width,height,pix_fmt \
  -of default=noprint_wrappers=1 \
  output.mp4
```

Expected:

```
codec_name=h264
profile=Constrained Baseline   (or Baseline / Main)
level=31
width=720
height=1280
pix_fmt=yuv420p
```

**Reject the asset if `profile=High` or `level>31`.** Worth adding as an
automated gate in the `TRANSCODE` job so an unplayable clip can never be
published.

---

## App-side status

No app change is needed once the encoding is fixed — the player already:

- resolves the clip URL and streams it (range requests confirmed working,
  `HTTP 206`);
- plays looping and muted;
- **falls back to the poster image when the decoder fails**, so an unsupported
  clip degrades to a still image with a `LIVE` badge instead of a black
  rectangle.

That fallback is a safety net, not a fix: users on affected devices still see a
static image instead of a live wallpaper until the clips are re-encoded.

---

## One separate backend issue

Unrelated to encoding, found while testing:

**`GET /wallpapers` (the feed) does not return the `video` object.** It is only
present on `GET /wallpapers/{idOrSlug}`. No query parameter changes this —
`include` accepts only `depth`, and `type=VIDEO` / `includeVideo=true` do not
add it.

The app works around this by lazily fetching the detail for each visible live
card. **Including `video` in feed rows (ideally behind `include=video`) would
remove one request per live wallpaper.**

Similarly, published `standard` wallpapers currently expose only a `THUMBNAIL`
asset — no `ORIGINAL` or `PREVIEW` — so the details screen has nothing better
than a 360×640 image to show for a 941×1672 wallpaper.
