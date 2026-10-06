import Foundation

/// Openverse (WordPress): search engine over openly licensed audio from Jamendo, Wikimedia,
/// Freesound and more. Anonymous access, no key. Duration comes back in milliseconds.
enum OpenverseService {
    private struct Response: Decodable {
        struct Item: Decodable {
            let title: String?
            let creator: String?
            let url: String?
            let duration: Int?
        }
        let results: [Item]
    }

    static func match(_ track: Track) async -> URL? {
        var c = URLComponents(string: "https://api.openverse.org/v1/audio/")!
        c.queryItems = [
            .init(name: "q", value: Matcher.query(for: track)),
            .init(name: "category", value: "music"),
            .init(name: "page_size", value: "10")
        ]
        guard let url = c.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let res = try? JSONDecoder().decode(Response.self, from: data)
        else { return nil }

        let hit = res.results.first {
            ($0.url ?? "").hasPrefix("https") &&
            Matcher.matches(track, title: $0.title ?? "", artist: $0.creator ?? "",
                            duration: $0.duration.map { Double($0) / 1000 })
        }
        return hit?.url.flatMap { URL(string: $0) }
    }
}
