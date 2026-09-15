# PosterFrameDemo

A small macOS SwiftUI app for developing and inspecting PosterFrameKit without
embedding diagnostic UI or comparison tooling in a consuming application.

The current demo:

- imports a movie using the system file importer;
- keeps video selection, profile switching, and a direct manual refresh action
  in a compact centered header beneath the standard macOS title bar;
- starts the complete comparison immediately after a movie is selected and
  automatically refreshes it after an analysis setting changes;
- keeps candidate count and all four selection preferences in a persistent
  settings bar above navigation; the bar switches from labeled chips to compact
  icon controls when the window narrows;
- extracts and displays the frame at 50% of the video as a neutral baseline;
- runs the real PosterFrameKit selection with the `general` or `animation`
  profile, a measured 24-candidate default, and a configurable candidate limit;
- can omit the normalized 46–54% midroll area to avoid common anime
  eyecatches and title cards;
- can request best-effort subtitle avoidance for the leading candidates and
  inspect the selected frame's base score, subtitle penalty, and ranking score;
- can request best-effort face preference for at most eight leading candidates
  and inspect the selected frame's bounded composition bonus;
- on macOS 15+, offers an opt-in Vision-first aesthetic preference over at
  most 24 leading PosterFrameKit candidates and exposes the raw score, utility
  classification, and signed adjustment;
- runs PosterFrameKit through its optimized URL API and displays the true
  end-to-end selection time;
- on macOS 15+, separately captures the same deterministic candidate plan,
  then ranks that set with Apple Vision's
  `CalculateImageAestheticsScoresRequest` and a transparent 50/50 hybrid score;
- presents PosterFrameKit as the primary 16:9 result and compares the baseline,
  Apple Vision, and the hybrid in a top-aligned adaptive grid;
- accepts a movie dropped onto the empty primary result and keeps the candidate
  browser and comparisons hidden until a video has been selected;
- exposes every captured candidate as a selectable score bar, using bounded
  display thumbnails and loading a larger preview only when a candidate is
  inspected; the compact strip fits and resizes up to 32 candidates before
  enabling horizontal scrolling for larger sets; selecting or hovering a
  candidate exposes its brightness, contrast, entropy, sharpness, color, and
  visual-noise measurements without expanding the score strip;
- keeps the Results tab focused on thumbnails, timestamps, scores, and timing,
  while a dedicated **Metrics** tab visualizes the PosterFrameKit base metrics
  and the complete refinement breakdown;
- provides a bottom **Analytics** tab with a visual end-to-end timing comparison,
  the measured winner, speed factor, percentage of time saved, and a breakdown
  of candidate capture versus Vision-only ranking;
- keeps every preview in a fixed 16:9 surface with a neutral background so
  different source aspect ratios do not move the surrounding layout;
- shows native high-contrast animated progress indicators inside each preview
  while baseline, PosterFrameKit, Vision, or hybrid results are still loading;
- saves any available result thumbnail as PNG from its right-click context
  menu; and
- displays the actual timestamp and normalized score on Results, with
  brightness, luma deviation, entropy, sharpness, colorfulness, and visual
  noise shown as labeled range-aware bars on Metrics.

Each result card labels its essential values explicitly. The Metrics tab keeps
the base score, optional face bonus, subtitle penalty, aesthetics adjustment,
final ranking score, and raw image measurements together without crowding the
thumbnail comparison. The score is PosterFrameKit's normalized ranking value,
the timestamp is the actual decoded time formatted as `HH:MM:SS.mmm`, and the
video position is that timestamp divided by the full video duration. Complete
selection time includes duration
loading, bounded parallel candidate seek and decode, analysis, and ranking.
Candidate Capture is a second, serialized decode used only to provide Vision
and the hybrid with a shared comparison set. Vision time covers ranking only.
The Analytics headline compares PosterFrameKit's complete optimized URL run
with the complete Vision demo workflow (`Candidate Capture + Vision Ranking`).
This makes the displayed speed factor meaningful for the two workflows that
the app actually executes, while the breakdown remains explicit that it is not
a microbenchmark of PosterFrameKit's ranker against the raw Vision request.
The complete demo interface, including errors, help text, and accessibility
labels, is presented in English.
Right-click any populated preview and choose **Save Thumbnail…** to export the
displayed image as a PNG for inspection or comparison.

Longer analyses can be cancelled from the video header. Changing the profile,
candidate limit, midroll exclusion, subtitle preference, face preference, or
aesthetic preference schedules a debounced
automatic refresh. The previous result remains visible beneath a progress
indicator until the replacement is ready. The direct refresh button is useful
for repeated timing measurements without changing a setting. PosterFrameKit
first completes through `bestFrame(in:options:)`, allowing its result and timing
to appear before the comparison work. The demo then records the same planned
timestamps through the serialized custom-source contract. This second pass
disables candidate refinements because it must
retain the complete comparison set; the user's preference still applies to the
real PosterFrameKit selection. Vision's displayed duration intentionally
excludes the separately displayed capture time.
Vision selects the highest raw aesthetics score. The hybrid normalizes that
score from `-1...1` to `0...1` and averages it equally with PosterFrameKit's
normalized score. Vision's `isUtility` flag is displayed for inspection but is
not an additional hidden penalty. Feature-print diversity is unnecessary here
because the demo asks each ranker for one winner, not a thumbnail set.

Subtitle avoidance is also disabled by default. When enabled, PosterFrameKit
checks the bottom third of at most eight leading candidates with local Vision
text recognition, using fast mode first and an accurate fallback only when a
cheap edge-band check remains suspicious. Text outside that region—including
most signs—does not receive a penalty. Lower-third signs or credits can still
look subtitle-like, so this remains a manual quality experiment rather than a
general text-removal guarantee. The option adds no network or external runtime
dependency.

Face preference is disabled by default. When enabled, PosterFrameKit runs local
Vision face detection on at most eight leading candidates and adds at most
`0.04` to the ranking score for useful face size and placement. Frames without
faces receive no penalty. The demo exposes the applied bonus separately so the
effect is visible rather than hidden. Strongly stylized animation faces can
still be missed; this is a best-effort quality experiment, not a face-presence
guarantee.

Aesthetic preference is disabled by default in the demo and unavailable before
macOS 15. When enabled, PosterFrameKit runs Apple Vision image-aesthetics
revision 1 on at most 24 leading candidates and aligns the deterministic base
score with Vision's normalized aesthetic score. The result card keeps the raw
score, utility classification, base score, and applied adjustment separate.

## Run

From the PosterFrameKit repository root:

```bash
swift run --package-path Examples/PosterFrameDemo
```

The executable bundles a dedicated PosterFrameDemo icon using the standard
macOS rounded-square presentation, transparent outer corners, and a restrained
drop shadow. It explicitly requests the regular macOS activation policy. Once
launch finishes, it activates itself and brings its window forward, so a
SwiftPM-launched process behaves like a regular foreground app in the Dock and
app switcher.

Alternatively, open `Package.swift` from this directory in Xcode and run the
`PosterFrameDemo` scheme. The demo resolves PosterFrameKit from `../..`, so
local package changes are available immediately.

AVFoundation determines which containers and codecs the baseline, optimized
selection, and comparison-capture paths can decode. Additional production
container support belongs in a separate `PosterFrameSource` adapter.
