import SwiftUI

private let felisRed = Color(red: 0.90, green: 0.10, blue: 0.15)

struct ContentView: View {
    @StateObject private var vm = PlayerViewModel()
    @State private var songList = ""
    @State private var showInput = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                playlist
                player
            }
        }
        .preferredColorScheme(.dark)
        .tint(felisRed)
    }

    // MARK: Header + song list input
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("FELIS")
                    .font(.system(size: 28, weight: .heavy))
                    .tracking(6)
                    .foregroundStyle(felisRed)
                Spacer()
                if !vm.tracks.isEmpty {
                    Button { withAnimation { showInput.toggle() } } label: {
                        Image(systemName: showInput ? "chevron.up" : "text.badge.plus")
                            .foregroundStyle(.gray)
                    }
                }
            }
            if showInput {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $songList)
                        .scrollContentBackground(.hidden)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .frame(height: 120)
                        .padding(6)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    if songList.isEmpty {
                        Text("Paste a public Spotify playlist link,\nor songs one per line: Title - Artist")
                            .foregroundStyle(.gray)
                            .padding(14)
                            .allowsHitTesting(false)
                    }
                }
                Button {
                    showInput = false
                    Task { await vm.load(songList) }
                } label: {
                    Text("Load").bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(felisRed, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.white)
                }
                .disabled(vm.isLoading || songList.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if !vm.status.isEmpty {
                Text(vm.status).font(.caption).foregroundStyle(.gray)
            }
        }
        .padding()
    }

    private var playlist: some View {
        List(Array(vm.tracks.enumerated()), id: \.element.id) { index, track in
            Button { vm.play(index) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title).lineLimit(1)
                            .foregroundStyle(vm.currentIndex == index ? felisRed : .white)
                        Text(track.artist).font(.caption).foregroundStyle(.gray)
                    }
                    Spacer()
                    if track.streamURL == nil {
                        Text(vm.isLoading ? "…" : "unavailable")
                            .font(.caption2).foregroundStyle(.gray)
                    }
                }
            }
            .disabled(track.streamURL == nil)
            .opacity(track.streamURL == nil ? 0.4 : 1)
            .listRowBackground(Color.black)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: Player controls
    private var player: some View {
        VStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(vm.current?.title ?? "Nothing playing").font(.headline).lineLimit(1)
                Text(vm.current?.artist ?? " ").font(.caption).foregroundStyle(.gray)
            }
            Slider(value: Binding(get: { vm.progress }, set: { vm.seek($0) }))

            HStack(spacing: 34) {
                Button { vm.shuffle.toggle() } label: {
                    Image(systemName: "shuffle")
                        .foregroundStyle(vm.shuffle ? felisRed : .gray)
                }
                Button { vm.previous() } label: { Image(systemName: "backward.fill") }
                Button { vm.togglePlay() } label: {
                    Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .frame(width: 58, height: 58)
                        .background(felisRed, in: Circle())
                        .foregroundStyle(.white)
                }
                Button { vm.next() } label: { Image(systemName: "forward.fill") }
            }
            .font(.title3)
            .foregroundStyle(.white)

            HStack {
                Image(systemName: "speaker.fill").foregroundStyle(.gray)
                Slider(value: Binding(get: { Double(vm.volume) }, set: { vm.volume = Float($0) }))
                Image(systemName: "speaker.wave.3.fill").foregroundStyle(.gray)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
    }
}
