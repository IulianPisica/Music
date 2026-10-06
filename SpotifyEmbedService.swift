import Foundation

/// Reads a PUBLIC Spotify playlist from its embed page (no API keys, no Premium).
/// Unofficial: Spotify can change the page at any time, and it returns ~100 tracks max.
enum SpotifyEmbedService {
    static func fetchTracks(link: String) async throws -> [Track] {
        guard let id = playlistID(from: link),
              let url = URL(string: "https://open.spotify.com/embed/playlist/\(id)")
        else { throw URLError(.badURL) }

        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: req)

        guard let html = String(data: data, encoding: .utf8),
              let start = html.range(of: "<script id=\"__NEXT_DATA__\" type=\"application/json\">"),
              let end = html.range(of: "</script>", range: start.upperBound..<html.endIndex)
        else { throw URLError(.cannotParseResponse) }

        let json = try JSONSerialization.jsonObject(with: Data(html[start.upperBound..<end.lowerBound].utf8))
        guard let list = find("trackList", in: json) as? [[String: Any]] else {
            throw URLError(.cannotParseResponse)
        }

        let tracks: [Track] = list.compactMap { item in
            guard let title = item["title"] as? String else { return nil }
            let subtitle = item["subtitle"] as? String ?? ""
            let artist = subtitle.components(separatedBy: ",").first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return Track(title: title, artist: artist)
        }
        if tracks.isEmpty { throw URLError(.cannotParseResponse) }
        return tracks
    }

    private static func playlistID(from link: String) -> String? {
        guard let u = URL(string: link.trimmingCharacters(in: .whitespacesAndNewlines)),
              let i = u.pathComponents.firstIndex(of: "playlist"),
              u.pathComponents.indices.contains(i + 1)
        else { return nil }
        return u.pathComponents[i + 1]
    }

    /// Finds the first value stored under `key` anywhere in the JSON tree.
    private static func find(_ key: String, in node: Any) -> Any? {
        if let d = node as? [String: Any] {
            if let v = d[key] { return v }
            for v in d.values { if let f = find(key, in: v) { return f } }
        } else if let a = node as? [Any] {
            for v in a { if let f = find(key, in: v) { return f } }
        }
        return nil
    }
}
