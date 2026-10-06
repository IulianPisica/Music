import Foundation

struct Track: Identifiable {
    let id = UUID()
    let title: String
    let artist: String
    var streamURL: URL?       // nil = not found in the free catalog
}
