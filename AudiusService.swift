import Foundation

/// Matches a Spotify track against Audius (artist-uploaded, free, no ads).
enum AudiusService {
    private struct Response: Decodable {
        struct Item: Decodable {
            struct User: Decodable { let name: String }
            let id: String
            let title: String
            let duration: Int
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

        let wanted = track.artist.lowercased()
        let hit = res.data.first { t in
            let name = t.user.name.lowercased()
            let sameLength = abs(Double(t.duration) - track.duration) <= 5
            let sameArtist = name.contains(wanted) || wanted.contains(name)
            return sameLength && sameArtist
        }
        guard let hit else { return nil }
        return URL(string: "https://api.audius.co/v1/tracks/\(hit.id)/stream?app_name=\(app)")
    }
}
