import Foundation

struct Track: Identifiable {
    let id = UUID()
    let title: String
    let artist: String
    let duration: Double      // seconds
    var streamURL: URL?       // nil = not found in the free catalog
}
