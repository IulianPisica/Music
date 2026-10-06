import Foundation

enum SpotifyService {
    private struct TokenResponse: Decodable {
        let access_token: String
    }
    private struct Page: Decodable {
        struct Item: Decodable { let track: T? }
        struct T: Decodable {
            let name: String
            let duration_ms: Int
            let artists: [A]
        }
        struct A: Decodable { let name: String }
        let items: [Item]
        let next: String?
    }

    static func fetchTracks(link: String) async throws -> [Track] {
        guard let id = playlistID(from: link) else { throw URLError(.badURL) }
        let token = try await accessToken()
        var next = URL(string: "https://api.spotify.com/v1/playlists/\(id)/tracks?limit=100&fields=next,items(track(name,duration_ms,artists(name)))")
        var out: [Track] = []
        while let url = next {
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, _) = try await URLSession.shared.data(for: req)
            let page = try JSONDecoder().decode(Page.self, from: data)
            out += page.items.compactMap { $0.track }.map {
                Track(title: $0.name,
                      artist: $0.artists.first?.name ?? "",
                      duration: Double($0.duration_ms) / 1000)
            }
            next = page.next.flatMap { URL(string: $0) }
        }
        return out
    }

    private static func playlistID(from link: String) -> String? {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        if let u = URL(string: trimmed),
           let i = u.pathComponents.firstIndex(of: "playlist"),
           u.pathComponents.indices.contains(i + 1) {
            return u.pathComponents[i + 1]
        }
        return trimmed.count == 22 ? trimmed : nil
    }

    private static func accessToken() async throws -> String {
        let creds = Data("\(Secrets.spotifyClientID):\(Secrets.spotifyClientSecret)".utf8).base64EncodedString()
        var req = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        req.httpMethod = "POST"
        req.setValue("Basic \(creds)", forHTTPHeaderField: "Authorization")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = Data("grant_type=client_credentials".utf8)
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(TokenResponse.self, from: data).access_token
    }
}
