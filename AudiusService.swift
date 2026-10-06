import Foundation

/// Matches a song against Audius (artist-uploaded, free, no ads).
enum AudiusService {
    private struct Response: Decodable {
        struct Item: Decodable {
            struct User: Decodable { let name: String }
            let id: String
            let title: String
            let user: User
        }
        let data: [Item]
    }

    private static let app = "FelisMusic"

    static func match(_ track: Track) async -> URL? {
        var c = URLComponents(string: "https://api.audius.co/v1/tracks/search")!
        c.queryItems = [
            .init(name: "query", value: "\(track.title) \(track.artist)"),
            .init(name: "app_name", value: app)
        ]
        guard let url = c.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let res = try? JSONDecoder().decode(Response.self, from: data)
        else { return nil }

        let t = track.title.lowercased()
        let a = track.artist.lowercased()
        func like(_ x: String, _ y: String) -> Bool {
            !x.isEmpty && !y.isEmpty && (x.contains(y) || y.contains(x))
        }

        let hit = res.data.first { item in
            let name = item.user.name.lowercased()
            let title = item.title.lowercased()
            let normal = like(name, a) && like(title, t)
            let swapped = like(name, t) && like(title, a)      // "Artist - Title" lists
            let titleOnly = a.isEmpty && like(title, t)         // line had no artist
            return normal || swapped || titleOnly
        }
        guard let hit else { return nil }
        return URL(string: "https://api.audius.co/v1/tracks/\(hit.id)/stream?app_name=\(app)")
    }
}
