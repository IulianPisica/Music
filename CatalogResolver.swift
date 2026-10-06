import Foundation

/// Walks every enabled catalog in TrackSource order: full-length sources first, previews last.
enum CatalogResolver {
    struct Result {
        let url: URL
        let source: TrackSource
        let swapped: Bool   // true if "A - B" turned out to be "Artist - Title"
    }

    static func resolve(_ track: Track) async -> Result? {
        if let r = await lookup(track) { return r }
        if track.guessedOrder {
            var flipped = track
            flipped.title = track.artist
            flipped.artist = track.title
            if let r = await lookup(flipped) {
                return Result(url: r.url, source: r.source, swapped: true)
            }
        }
        return nil
    }

    private static func lookup(_ t: Track) async -> Result? {
        for source in TrackSource.allCases where Settings.isEnabled(source) {
            if let url = await search(source, t) {
                return Result(url: url, source: source, swapped: false)
            }
        }
        return nil
    }

    private static func search(_ source: TrackSource, _ t: Track) async -> URL? {
        switch source {
        case .audius:    return await AudiusService.match(t)
        case .jamendo:   return await JamendoService.match(t)
        case .openverse: return await OpenverseService.match(t)
        case .archive:   return await ArchiveService.match(t)
        case .deezer:    return await DeezerService.match(t)
        case .itunes:    return await ITunesService.match(t)
        }
    }
}
