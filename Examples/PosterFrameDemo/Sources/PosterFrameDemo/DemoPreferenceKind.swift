enum DemoPreferenceKind: CaseIterable, Identifiable {
  case midrollExclusion
  case subtitleAvoidance
  case facePreference
  case aestheticPreference

  var id: Self { self }

  var title: String {
    switch self {
    case .midrollExclusion:
      "Midroll"
    case .subtitleAvoidance:
      "Subtitle-free"
    case .facePreference:
      "Faces"
    case .aestheticPreference:
      "Aesthetics"
    }
  }

  var systemImage: String {
    switch self {
    case .midrollExclusion:
      "rectangle.split.3x1"
    case .subtitleAvoidance:
      "captions.bubble"
    case .facePreference:
      "face.smiling"
    case .aestheticPreference:
      "sparkles"
    }
  }

  var helpText: String {
    switch self {
    case .midrollExclusion:
      "Excludes the 46–54% range from candidate sampling to avoid common eyecatches and title cards."
    case .subtitleAvoidance:
      "Best effort: prefers candidates without subtitle-like lower-third text. Signs elsewhere remain valid."
    case .facePreference:
      "Best effort: applies a small bounded bonus for strong face composition among leading candidates."
    case .aestheticPreference:
      "Opt in to Apple Vision aesthetics on macOS 15 or newer. PosterFrameKit remains the fallback."
    }
  }
}
