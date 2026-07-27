<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Media Privacy Check

Run `bash Scripts/check-media-privacy.sh` before staging any media. It checks
generic file names, forbidden path/email/token patterns, image metadata,
video/audio streams, codecs, dimensions, size and editing-project extensions.
It never prints a detected personal value.

Useful independent inspection:

```sh
mdls media-file
sips -g all image.png
ffprobe -v error -show_streams -show_format video.webm
exiftool -G -a -s media-file
ffmpeg -i video.webm -vf fps=1 review/frame-%04d.png
```

Clean WebP with `cwebp -metadata none`. Re-encode video with
`Scripts/encode-media.sh`, which strips metadata and audio. Do not rely on
blur. If any frame or metadata field is uncertain, reject the file and
re-record it.

Automated output has three states: `PASS`, `FAIL`, and
`HUMAN_REVIEW_REQUIRED`. Only PASS plus completed human frame/corner review is
acceptable.
