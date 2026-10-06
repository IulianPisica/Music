import Foundation

/// Deezer public search: no key, mainstream catalog, 30-second previews only.
enum DeezerService {
    private struct Response: Decodable {
        struct Item: Decodable {
            struct Artist: Decodable { let name: String }
            let title: String
            let duration: Int?
            let preview: String?
            let artist: Artist
        }
        let data: [Item]
    }

    static func match(_ track: Track) async -> URL? {
        var c = URLComponents(string: "https://api.deezer.com/search")!
        c.queryItems = [
            .init(name: "q", value: Matcher.query(for: track)),
            .init(name: "limit", value: "10")
        ]
        guard let url = c.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let res = try? JSONDecoder().decode(Response.self, from: data)
        else { return nil }

        let hit = res.data.first {
            !($0.preview ?? "").isEmpty &&
            Matcher.matches(track, title: $0.title, artist: $0.artist.name,
                            duration: $0.duration.map(Double.init))
        }
        return hit?.preview.flatMap { URL(string: $0) }
    }
}
