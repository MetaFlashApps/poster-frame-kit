# Results Gallery Assets

These eleven JPEGs are the published output of PosterFrameKit's reviewed
five-file quality baseline. Each row compares an independently decoded fixed
50% frame with PosterFrameKit's recommended 24-candidate quality configuration.
The additional Morevna comparison is an unmodified side-by-side composition of
that fixture's two published frames. The actual decoded times and complete
score evidence are stored in
`Benchmarks/Reports/m1-pro-macos-15.7.4-quality.json`.

Regenerate the ignored PNG evidence, schema-3 report, and 80%-quality gallery
JPEGs from the checksum-locked local fixtures with:

```bash
Scripts/fetch-benchmark-fixtures.py --verify-only
arch -arm64 swift run -c release PosterFrameKitQualityBenchmark \
  --candidates 24 \
  --gallery-directory docs/assets/results-gallery \
  --report Benchmarks/Reports/m1-pro-macos-15.7.4-quality.json
```

The checked-in run used an Apple M1 Pro, macOS 15.7.4 (24G517), native ARM64,
24 planned candidates, each fixture's declared profile, the `46...54%` midroll
exclusion, face preference, and Vision-first aesthetic preference. The source
clips are silent 120-second H.264 normalizations at no more than 1280×720.

## Attribution and licenses

The gallery frames remain under their source works' Creative Commons licenses;
they are not relicensed under PosterFrameKit's MIT license.

Changes from the source works: the benchmark pipeline removes audio, trims a
120-second segment, scales it within 1280×720, encodes the working clip as
H.264/yuv420p, extracts the two displayed stills, and JPEG-compresses them at
quality `0.8`. The README hero places the two Morevna JPEGs side by side without
cropping or retouching:

```bash
magick \
  docs/assets/results-gallery/morevna-demo/midpoint.jpg \
  docs/assets/results-gallery/morevna-demo/posterframekit.jpg \
  +append -sampling-factor 4:2:0 -strip -quality 80 \
  docs/assets/results-gallery/morevna-demo/comparison.jpg
```

| Fixture | Source and attribution | License |
| --- | --- | --- |
| `morevna-demo` | [Project page](https://morevnaproject.org/anime/demo/) — Morevna Project, The Beautiful Queen Marya Morevna Demo | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) |
| `big-buck-bunny` | [Project page](https://peach.blender.org/) — (c) 2008 Blender Foundation \| peach.blender.org | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) |
| `sintel` | [Project page](https://durian.blender.org/) — (c) Blender Foundation \| durian.blender.org | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) |
| `tears-of-steel` | [Project page](https://mango.blender.org/) — (c) Blender Foundation \| mango.blender.org | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) |
| `cosmos-laundromat` | [Project page](https://opencontent.netflix.com/) — Cosmos Laundromat by Blender Foundation; Netflix Open Content SDR encode | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |

The authoritative download URLs, source checksums, normalization recipes, and
license notes remain in `Benchmarks/Fixtures/manifest.json`.
