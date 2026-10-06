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

    @Published var pendingChoices: [ImportedPlaylist] = []
    @Published var loop: LoopMode = .off

    enum LoopMode { case off, all, one }

    func cycleLoop() {
        switch loop {
        case .off: loop = .all
        case .all: loop = .one
        case .one: loop = .off
        }
    }

    /// Called when a song finishes on its own.
    private func trackEnded() {
        switch loop {
        case .one:
            player.seek(to: .zero)
            player.play()
        case .all:
            next()
        case .off:
            let cur = currentIndex ?? -1
            if shuffle || playable.contains(where: { $0 > cur }) {
                next()
            } else {
                player.pause()
                player.seek(to: .zero)
                isPlaying = false
                progress = 0
            }
        }
    }

    /// Entry point for pasted text or an imported file.
    func importText(_ text: String, name: String = "Pasted list") {
        let lists = PlaylistImporter.parse(text, fallbackName: name).filter { !$0.tracks.isEmpty }
        switch lists.count {
        case 0:  status = "No songs found in that text."
        case 1:  Task { await load(lists[0]) }
        default: pendingChoices = lists   // Spotify export with several playlists: let the user pick
        }
    }

    func load(_ playlist: ImportedPlaylist) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        pendingChoices = []
        player.pause()
        isPlaying = false
        currentIndex = nil
        progress = 0
        tracks = playlist.tracks

        let snapshot = tracks
        var done = 0
        await withTaskGroup(of: (Int, CatalogResolver.Result?).self) { group in
            var pending = snapshot.indices.makeIterator()
            for _ in 0..<6 {
                guard let i = pending.next() else { break }
                group.addTask { (i, await CatalogResolver.resolve(snapshot[i])) }
            }
            while let (i, res) = await group.next() {
                done += 1
                if let res {
                    tracks[i].streamURL = res.url
                    tracks[i].source = res.source
                    if res.swapped {
                        let t = tracks[i].title
                        tracks[i].title = tracks[i].artist
                        tracks[i].artist = t
                    }
                }
                status = "Searching \(done) of \(snapshot.count)…"
                if let j = pending.next() {
                    group.addTask { (j, await CatalogResolver.resolve(snapshot[j])) }
                }
            }
        }
        let full = tracks.filter { $0.streamURL != nil && $0.source?.isPreview == false }.count
        let prev = tracks.filter { $0.source?.isPreview == true }.count
        let missing = tracks.count - full - prev
        status = "\(full) full songs, \(prev) previews, \(missing) not found"
    }

    func play(_ index: Int) {
        guard tracks.indices.contains(index), let url = tracks[index].streamURL else { return }
        currentIndex = index
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        if let o = endObserver { NotificationCenter.default.removeObserver(o) }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.trackEnded() }
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
