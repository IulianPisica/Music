import AVFoundation
import SwiftUI

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published var tracks: [Track] = []
    @Published var currentIndex: Int?
    @Published var isPlaying = false
    @Published var shuffle = false
    @Published var volume: Float = 0.8 { didSet { player.volume = volume } }
    @Published var progress: Double = 0
    @Published var status = ""
    @Published var isLoading = false

    private let player = AVPlayer()
    private var endObserver: NSObjectProtocol?

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        player.volume = volume
        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
                                       queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self,
                      let d = self.player.currentItem?.duration.seconds,
                      d.isFinite, d > 0 else { return }
                self.progress = time.seconds / d
            }
        }
    }

    var current: Track? { currentIndex.map { tracks[$0] } }

    func load(_ link: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            status = "Reading playlist…"
            tracks = try await SpotifyService.fetchTracks(link: link)
            for i in tracks.indices {
                status = "Matching \(i + 1) of \(tracks.count)…"
                tracks[i].streamURL = await AudiusService.match(tracks[i])
            }
            let found = tracks.filter { $0.streamURL != nil }.count
            status = "\(found) of \(tracks.count) tracks found"
        } catch {
            status = "Error: \(error.localizedDescription)"
        }
    }

    func play(_ index: Int) {
        guard tracks.indices.contains(index), let url = tracks[index].streamURL else { return }
        currentIndex = index
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        if let o = endObserver { NotificationCenter.default.removeObserver(o) }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.next() }
        }
        player.play()
        isPlaying = true
    }

    func togglePlay() {
        guard currentIndex != nil else { next(); return }
        isPlaying ? player.pause() : player.play()
        isPlaying.toggle()
    }

    private var playable: [Int] { tracks.indices.filter { tracks[$0].streamURL != nil } }

    func next() {
        guard !playable.isEmpty else { return }
        if shuffle {
            play(playable.filter { $0 != currentIndex }.randomElement() ?? playable[0])
        } else {
            let cur = currentIndex ?? -1
            play(playable.first { $0 > cur } ?? playable[0])
        }
    }

    func previous() {
        guard !playable.isEmpty else { return }
        if player.currentTime().seconds > 3 { player.seek(to: .zero); return }
        let cur = currentIndex ?? 0
        play(playable.last { $0 < cur } ?? playable[playable.count - 1])
    }

    func seek(_ fraction: Double) {
        guard let d = player.currentItem?.duration.seconds, d.isFinite else { return }
        progress = fraction
        player.seek(to: CMTime(seconds: d * fraction, preferredTimescale: 600))
    }
}
