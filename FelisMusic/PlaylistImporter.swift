import Foundation

/// Turns pasted text or an exported file into a list of songs. No Spotify API involved.
/// Understands: Spotify "Download your data" JSON (Playlist1.json / YourLibrary.json),
/// Exportify CSV, and plain text lines ("Title - Artist").
enum PlaylistImporter {
    static func parse(_ raw: String, fallbackName: String = "Pasted list") -> [ImportedPlaylist] {
        let text = raw.replacingOccurrences(of: "\u{FEFF}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("{") || text.hasPrefix("["), let lists = parseSpotifyJSON(text), !lists.isEmpty {
            return lists
        }
        if let csv = parseCSV(text), !csv.isEmpty {
            return [ImportedPlaylist(name: fallbackName, tracks: csv)]
        }
        return [ImportedPlaylist(name: fallbackName, tracks: parseLines(text))]
    }

    // MARK: Spotify data export
    private struct Export: Decodable {
        struct PL: Decodable {
            struct Item: Decodable {
                struct T: Decodable { let trackName: String?; let artistName: String? }
                let track: T?
            }
            let name: String
            let items: [Item]
        }
        let playlists: [PL]
    }
    private struct Library: Decodable {
        struct T: Decodable { let artist: String?; let track: String? }
        let tracks: [T]
    }

    private static func parseSpotifyJSON(_ text: String) -> [ImportedPlaylist]? {
        let data = Data(text.utf8)
        if let e = try? JSONDecoder().decode(Export.self, from: data) {
            return e.playlists.map { pl in
                ImportedPlaylist(name: pl.name, tracks: pl.items.compactMap { i in
                    guard let t = i.track, let name = t.trackName, !name.isEmpty else { return nil }
                    return Track(title: name, artist: t.artistName ?? "", duration: nil)
                })
            }
        }
        if let l = try? JSONDecoder().decode(Library.self, from: data) {
            let tracks = l.tracks.compactMap { t -> Track? in
                guard let name = t.track, !name.isEmpty else { return nil }
                return Track(title: name, artist: t.artist ?? "", duration: nil)
            }
            return [ImportedPlaylist(name: "Liked songs", tracks: tracks)]
        }
        return nil
    }

    // MARK: Exportify CSV
    private static func parseCSV(_ text: String) -> [Track]? {
        let rows = csvRows(text).filter { !($0.count == 1 && $0[0].isEmpty) }
        guard let header = rows.first else { return nil }
        let h = header.map { $0.lowercased() }
        guard let ti = h.firstIndex(where: { $0.contains("track name") }),
              let ai = h.firstIndex(where: { $0.contains("artist name") }) else { return nil }
        let di = h.firstIndex(where: { $0.contains("duration") })
        return rows.dropFirst().compactMap { r in
            guard r.indices.contains(ti), r.indices.contains(ai), !r[ti].isEmpty else { return nil }
            let artist = r[ai].components(separatedBy: ";").first?
                .trimmingCharacters(in: .whitespaces) ?? ""
            let dur = di.flatMap { r.indices.contains($0) ? Double(r[$0]) : nil }.map { $0 / 1000 }
            return Track(title: r[ti], artist: artist, duration: dur)
        }
    }

    private static func csvRows(_ text: String) -> [[String]] {
        var rows: [[String]] = [], row: [String] = [], field = ""
        var inQuotes = false
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" { field.append("\""); i += 1 }
                    else { inQuotes = false }
                } else { field.append(c) }
            } else {
                switch c {
                case "\"": inQuotes = true
                case ",": row.append(field); field = ""
                case "\n", "\r", "\r\n": row.append(field); field = ""; rows.append(row); row = []
                default: field.append(c)
                }
            }
            i += 1
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows
    }

    // MARK: Plain lines
    private static func parseLines(_ text: String) -> [Track] {
        text.split(whereSeparator: \.isNewline).compactMap { line in
            var s = line.trimmingCharacters(in: .whitespaces)
            s = s.replacingOccurrences(of: #"^\d+[\.\)]\s+"#, with: "", options: .regularExpression)
            guard !s.isEmpty, !s.contains("open.spotify.com") else { return nil }
            for sep in [" - ", " – ", " — "] {
                if let r = s.range(of: sep) {
                    let left = String(s[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
                    let right = String(s[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if !left.isEmpty, !right.isEmpty {
                        return Track(title: left, artist: right, duration: nil, guessedOrder: true)
                    }
                }
            }
            return Track(title: s, artist: "", duration: nil)
        }
    }
}
