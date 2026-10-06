import Foundation

/// Every free/legal catalog the app can search, in priority order (full songs first, previews last).
enum TrackSource: String, CaseIterable, Identifiable {
    case audius = "Audius"
    case jamendo = "Jamendo"
    case openverse = "Openverse"
    case archive = "Internet Archive"
    case deezer = "Deezer preview"
    case itunes = "iTunes preview"

    var id: String { rawValue }
    var isPreview: Bool { self == .deezer || self == .itunes }
    var needsKey: Bool { self == .jamendo }

    var blurb: String {
        switch self {
        case .audius:    return "Full songs · indie artists · no key"
        case .jamendo:   return "Full songs · Creative Commons · needs a free key"
        case .openverse: return "Full songs · Creative Commons from many sites · no key"
        case .archive:   return "Full songs · live recordings, netlabels, old music · no key"
        case .deezer:    return "30-second previews · mainstream songs · no key"
        case .itunes:    return "30-second previews · mainstream songs · no key"
        }
    }
}

struct Track: Identifiable {
    let id = UUID()
    var title: String
    var artist: String
    var duration: Double?          // seconds, nil when unknown (pasted text)
    var guessedOrder = false       // "A - B" lines: we don't know which side is the artist
    var streamURL: URL?            // nil = not found in any enabled catalog
    var source: TrackSource?
}

struct ImportedPlaylist: Identifiable {
    let id = UUID()
    let name: String
    let tracks: [Track]
}
