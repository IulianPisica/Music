import Foundation

/// Internet Archive audio: live recordings, netlabel releases, public-domain music. No key.
/// Two steps: find candidate items, then look through each item's mp3 files for the song.
enum ArchiveService {
    private struct Flex: Decodable {
        let value: String
        init(from d: Decoder) throws {
            let c = try d.singleValueContainer()
            if let s = try? c.decode(String.self) { value = s }
            else if let a = try? c.decode([String].self) { value = a.joined(separator: " ") }
            else { value = "" }
        }
    }
    private struct Search: Decodable {
        struct Resp: Decodable {
            struct Doc: Decodable { let identifier: String }
            let docs: [Doc]
        }
        let response: Resp
    }
    private struct Meta: Decodable {
        struct File: Decodable {
            let name: String
            let title: Flex?
            let creator: Flex?
            let format: String?
            let length: Flex?
        }
        struct Info: Decodable { let creator: Flex? }
        let files: [File]?
        let metadata: Info?
    }

    static func match(_ track: Track) async -> URL? {
        var c = URLComponents(string: "https://archive.org/advancedsearch.php")!
        c.queryItems = [
            .init(name: "q", value: "(\(Matcher.query(for: track))) AND mediatype:audio"),
            .init(name: "fl[]", value: "identifier"),
            .init(name: "rows", value: "4"),
            .init(name: "output", value: "json")
        ]
        guard let url = c.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let search = try? JSONDecoder().decode(Search.self, from: data)
        else { return nil }

        for doc in search.response.docs.prefix(3) {
            guard let mURL = URL(string: "https://archive.org/metadata/\(doc.identifier)"),
                  let (mData, _) = try? await URLSession.shared.data(from: mURL),
                  let meta = try? JSONDecoder().decode(Meta.self, from: mData)
            else { continue }

            let itemArtist = meta.metadata?.creator?.value ?? ""
            for f in meta.files ?? [] where f.name.lowercased().hasSuffix(".mp3") {
                let fileTitle = f.title?.value.isEmpty == false
                    ? f.title!.value
                    : stripExtension(f.name)
                let artist = f.creator?.value.isEmpty == false ? f.creator!.value : itemArtist
                if Matcher.matches(track, title: fileTitle, artist: artist, duration: seconds(f.length?.value)) {
                    let path = f.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? f.name
                    return URL(string: "https://archive.org/download/\(doc.identifier)/\(path)")
                }
            }
        }
        return nil
    }

    private static func stripExtension(_ name: String) -> String {
        var n = (name as NSString).lastPathComponent
        n = (n as NSString).deletingPathExtension
        return n.replacingOccurrences(of: #"^\d+[\s\.\-_]+"#, with: "", options: .regularExpression)
    }

    private static func seconds(_ s: String?) -> Double? {
        guard let s, !s.isEmpty else { return nil }
        if let d = Double(s) { return d }
        let parts = s.split(separator: ":").compactMap { Double($0) }
        guard !parts.isEmpty else { return nil }
        return parts.reduce(0) { $0 * 60 + $1 }
    }
}
