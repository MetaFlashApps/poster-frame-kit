# Heiter Integration

This document tracks integration work for Heiter, the first PosterFrameKit
consumer. It is deliberately separate from the public package roadmap: Heiter
may depend on FFmpeg, application-specific media identity, and queue behavior,
while PosterFrameKit remains a decoder-independent Swift package.

## Boundary

PosterFrameKit owns:

- candidate planning, analysis, scoring, and deterministic ranking;
- the optimized AVFoundation URL path for supported local media;
- the serialized `PosterFrameSource` contract for caller-provided frames; and
- public results expressed only with Swift and Apple system types.

Heiter owns:

- deciding whether AVFoundation or its existing decoder stack opens a file;
- MKV, AVI, FFmpeg, and codec-specific integration;
- media identity, thumbnail persistence, invalidation, eviction, and queue
  lifecycle; and
- mapping PosterFrameKit results into Heiter's own models and UI.

Before generating a frame, Heiter may prefer deliberate media artwork. For
AVFoundation-supported files it can call
`PosterFrameKit.embeddedArtwork(in:)`; for Matroska and other custom containers,
its container layer remains responsible for reading image attachments. A
missing or undecodable attachment falls through to normal frame selection.

No Heiter type, FFmpeg header, static library, or application assumption belongs
in PosterFrameKit.

## Container and Codec Strategy

For containers and codecs supported by AVFoundation, Heiter should call
`PosterFrameKit.bestFrame(in:options:)` directly and receive the optimized
bounded macOS decoder path.

For MKV, AVI, or unsupported codec combinations, Heiter should implement
`PosterFrameSource` around its decoder integration and call
`PosterFrameKit.bestFrame(from:options:)`. Container support and codec
acceleration are separate concerns: an H.264 or HEVC stream inside Matroska may
still use VideoToolbox, while legacy codecs may require software decoding.

The current custom-source contract is intentionally serialized. FFmpeg format
and codec contexts are stateful and must not be shared across concurrent random
seeks. If profiling shows that custom decoding blocks queue loading, benchmark
a Heiter-owned bounded pool in which each lane has independent demuxer, decoder,
seek, and flush state. Compare one through four lanes, peak memory,
cancellation, actual timestamps, and deterministic winners before proposing any
new public concurrent-source contract.

## Thumbnail Cache

Heiter should cache the final thumbnail rather than ask PosterFrameKit to own a
second persistent cache. A cache key should account for at least:

- canonical media identity;
- file size and modification date or another reliable content revision;
- normalized PosterFrameKit options;
- an application-managed selection revision that changes with the package or
  ranking policy; and
- the requested output dimensions.

Heiter remains responsible for storage limits, eviction, invalidation, and the
relationship between cached images and its media library. PosterFrameKit may
reuse transient implementation resources, but it does not persist selections.

## Rollout Plan

1. Integrate tagged PosterFrameKit builds for AVFoundation-supported files.
2. Compare the selected frame with Heiter's current first-non-black behavior on
   a documented local test set.
3. Map Heiter's optional face mode to `PosterFrameFaceOptions`; after quality
   validation, remove Heiter's separate first-detected-face ranking so both
   container paths use the same bounded composition policy.
4. Add a serialized Heiter-owned `PosterFrameSource` adapter for MKV and AVI.
5. Verify actual timestamps, transforms, cancellation, decoding failures, and
   identical ranking behavior across both paths.
6. Profile queue-loading runtime and peak memory before considering decoder
   concurrency.
7. Store final thumbnails in Heiter's cache using the normalized selection
   configuration as part of the key.

## Poster Timestamp Interoperability Proposal

Heiter may eventually persist both the selected cover image and the actual
`PosterFrameResult.time` in its output container. The timestamp would let a
consumer regenerate the same poster at an appropriate resolution when an
embedded cover is absent, while the cover remains the exact visual result.

There is no assumed cross-container standard for this value. Before shipping
one, define and version a namespaced metadata key with unambiguous semantics:

- time is measured from the media presentation timeline in seconds;
- the serialized value has a documented precision and locale-independent
  representation;
- edits, remuxing, timeline offsets, and duration changes define invalidation;
- the embedded image remains authoritative when both image and timestamp are
  present; and
- unsupported readers safely ignore the custom key.

PosterFrameKit must not write Matroska metadata or learn Heiter types. Heiter's
container layer writes and reads the proposed key, then either returns its
embedded image, decodes the referenced timestamp, or falls back to ordinary
PosterFrameKit selection. A public PosterFrameKit timestamp-metadata API should
be considered only after the key has real cross-application adoption and a
container-neutral contract.

## Integration Acceptance

- [ ] AVFoundation-supported files use the URL API
- [ ] MKV and AVI use a Heiter-owned custom source
- [ ] No Heiter or FFmpeg types leak into PosterFrameKit
- [ ] Heiter face preference delegates to PosterFrameKit instead of running a
      second Vision ranking pass
- [ ] Selection can be cancelled when queue work is cancelled
- [ ] Decoder failures surface as useful Heiter errors
- [ ] Thumbnail cache invalidation covers media and option changes
- [ ] Embedded artwork is preferred explicitly and falls back to frame
      selection when missing or invalid
- [ ] Any persisted poster timestamp uses a versioned, documented namespaced
      key and survives a remux round trip before rollout
- [ ] The trial set is at least as reliable as the existing first-non-black
      approach without noticeably blocking queue loading
- [ ] Shared branches use a tagged remote package version rather than a sibling
      checkout

For local development with both repositories next to each other, Heiter may
temporarily use:

```swift
.package(path: "../poster-frame-kit")
```

Release branches should use the tagged remote dependency instead.
