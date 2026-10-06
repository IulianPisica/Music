import Foundation

/// Jamendo: Creative Commons music, free API key, full-length streams.
enum JamendoService {
    private struct Response: Decodable {
        struct Item: Decodable {
            let name: String
            let artist_name: String
            let duration: Int?
            let audio: String?
        }
        let results: [Item]
    }

    static func match(_ track: Track) async -> URL? {
        let key = Settings.jamendoKey
        guard !key.isEmpty else { return nil }
        var c = URLComponents(string: "https://api.jamendo.com/v3.0/tracks/")!
        c.queryItems = [
            .init(name: "client_id", value: key),
            .init(name: "format", value: "json"),
            .init(name: "limit", value: "10"),
            .init(name: "audioformat", value: "mp32"),
            .init(name: "search", value: Matcher.query(for: track))
        ]
        guard let url = c.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let res = try? JSONDecoder().decode(Response.self, from: data)
        else { return nil }

        let hit = res.results.first {
            $0.audio != nil &&
            Matcher.matches(track, title: $0.name, artist: $0.artist_name,
                            duration: $0.duration.map(Double.init))
        }
        return hit?.audio.flatMap { URL(string: $0) }
    }
}
