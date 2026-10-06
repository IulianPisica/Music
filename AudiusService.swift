import Foundation

/// Audius: artist-uploaded, free, no ads. Mostly indie, but full songs.
enum AudiusService {
    private struct Response: Decodable {
        struct Item: Decodable {
            struct User: Decodable { let name: String }
            let id: String
            let title: String
            let duration: Int?
            let user: User
            let is_streamable: Bool?
        }
        let data: [Item]
    }

    private static let app = "FelisMusic"

    static func match(_ track: Track) async -> URL? {
        var c = URLComponents(string: "https://api.audius.co/v1/tracks/search")!
        c.queryItems = [
            .init(name: "query", value: Matcher.query(for: track)),
            .init(name: "app_name", value: app)
        ]
        guard let url = c.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let res = try? JSONDecoder().decode(Response.self, from: data)
        else { return nil }

        let hit = res.data.first {
            $0.is_streamable != false &&
            Matcher.matches(track, title: $0.title, artist: $0.user.name,
                            duration: $0.duration.map(Double.init))
        }
        guard let hit else { return nil }
        return URL(string: "https://api.audius.co/v1/tracks/\(hit.id)/stream?app_name=\(app)")
    }
}
