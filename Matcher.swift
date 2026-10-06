import Foundation

/// Fuzzy matching between a wanted song and a catalog result.
enum Matcher {
    static func normalize(_ s: String) -> String {
        var t = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        let rules = [
            #"[\(\[][^\)\]]*[\)\]]"#,                                                   // (feat. X) [Remastered]
            #"\s-\s.*\b(remaster\w*|live|edit|version|mix|mono|stereo|single)\b.*$"#,    // - Remastered 2011
            #"\b(feat|ft|featuring)\b.*$"#
        ]
        for r in rules { t = t.replacingOccurrences(of: r, with: " ", options: .regularExpression) }
        t = t.replacingOccurrences(of: #"[^\p{L}\p{N}\s]"#, with: " ", options: .regularExpression)
        return t.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func query(for track: Track) -> String {
        "\(normalize(track.title)) \(normalize(track.artist))".trimmingCharacters(in: .whitespaces)
    }

    private static func similarity(_ a: String, _ b: String) -> Double {
        let x = Set(a.split(separator: " ")), y = Set(b.split(separator: " "))
        guard !x.isEmpty, !y.isEmpty else { return 0 }
        return Double(x.intersection(y).count) / Double(x.union(y).count)
    }

    static func matches(_ want: Track, title: String, artist: String, duration: Double?) -> Bool {
        let wt = normalize(want.title), ct = normalize(title)
        guard !wt.isEmpty, !ct.isEmpty else { return false }
        guard wt == ct || similarity(wt, ct) >= 0.75 else { return false }

        let wa = normalize(want.artist), ca = normalize(artist)
        if !wa.isEmpty {
            guard !ca.isEmpty else { return false }
            let shorter = wa.count < ca.count ? wa : ca
            let longer = wa.count < ca.count ? ca : wa
            let artistOK = wa == ca
                || (shorter.count >= 3 && longer.contains(shorter))
                || similarity(wa, ca) >= 0.5
            guard artistOK else { return false }
        }

        if let a = want.duration, let b = duration, abs(a - b) > 12 { return false }
        return true
    }
}
