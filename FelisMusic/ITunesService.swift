import Foundation

/// iTunes Search API: no key, mainstream catalog, 30-second previews only.
enum ITunesService {
    private struct Response: Decodable {
        struct Item: Decodable {
            let trackName: String?
            let artistName: String?
            let trackTimeMillis: Int?
            let previewUrl: String?
        }
        let results: [Item]
    }

    static func match(_ track: Track) async -> URL? {
        var c = URLComponents(string: "https://itunes.apple.com/search")!
        c.queryItems = [
            .init(name: "term", value: Matcher.query(for: track)),
            .init(name: "media", value: "music"),
            .init(name: "entity", value: "song"),
            .init(name: "limit", value: "10")
        ]
        guard let url = c.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let res = try? JSONDecoder().decode(Response.self, from: data)
        else { return nil }

        let hit = res.results.first {
            $0.previewUrl != nil &&
            Matcher.matches(track, title: $0.trackName ?? "", artist: $0.artistName ?? "",
                            duration: $0.trackTimeMillis.map { Double($0) / 1000 })
        }
        return hit?.previewUrl.flatMap { URL(string: $0) }
    }
}
