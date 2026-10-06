import SwiftUI
import UniformTypeIdentifiers

let felisRed = Color(red: 0.90, green: 0.10, blue: 0.15)

struct ContentView: View {
    @StateObject private var vm = PlayerViewModel()
    @State private var showPaste = false
    @State private var showImporter = false
    @State private var showSettings = false
    @State private var pasteText = ""

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
        .sheet(isPresented: $showPaste) { pasteSheet }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: Binding(get: { !vm.pendingChoices.isEmpty },
                                    set: { if !$0 { vm.pendingChoices = [] } })) { choiceSheet }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.json, .commaSeparatedText, .plainText]) { result in
            guard case .success(let url) = result else { return }
            let ok = url.startAccessingSecurityScopedResource()
            defer { if ok { url.stopAccessingSecurityScopedResource() } }
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                vm.importText(text, name: url.deletingPathExtension().lastPathComponent)
            } else {
                vm.status = "Couldn't read that file."
            }
        }
    }

    // MARK: Header + playlist input
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("FELIS")
                    .font(.system(size: 28, weight: .heavy))
                    .tracking(6)
                    .foregroundStyle(felisRed)
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill").font(.title3).foregroundStyle(.gray)
                }
            }
            HStack(spacing: 10) {
                importButton("Paste songs", icon: "doc.on.clipboard") { showPaste = true }
                importButton("Import file", icon: "square.and.arrow.down") { showImporter = true }
            }
            if !vm.status.isEmpty {
                Text(vm.status).font(.caption).foregroundStyle(.gray)
            }
        }
        .padding()
    }

    private func importButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).bold()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(felisRed, in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(.white)
        }
        .disabled(vm.isLoading)
    }

    private var pasteSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("One song per line, like \"Title - Artist\". Exportify CSV text works too.")
                    .font(.caption).foregroundStyle(.gray)
                TextEditor(text: $pasteText)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
            .padding()
            .navigationTitle("Paste songs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showPaste = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Find") { showPaste = false; vm.importText(pasteText) }
                        .disabled(pasteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(felisRed)
    }

    private var choiceSheet: some View {
        NavigationStack {
            List(vm.pendingChoices) { p in
                Button { Task { await vm.load(p) } } label: {
                    HStack {
                        Text(p.name)
                        Spacer()
                        Text("\(p.tracks.count) songs").font(.caption).foregroundStyle(.gray)
                    }
                }
            }
            .navigationTitle("Pick a playlist")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
        .tint(felisRed)
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
                        Text(vm.isLoading ? "…" : "unavailable").font(.caption2).foregroundStyle(.gray)
                    } else if let src = track.source {
                        Text(src.rawValue).font(.caption2)
                            .foregroundStyle(src.isPreview ? Color.orange : Color.gray)
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

            HStack(spacing: 28) {
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
                Button { vm.cycleLoop() } label: {
                    Image(systemName: vm.loop == .one ? "repeat.1" : "repeat")
                        .foregroundStyle(vm.loop == .off ? .gray : felisRed)
                }
                .accessibilityLabel(vm.loop == .off ? "Loop off" : vm.loop == .all ? "Loop playlist" : "Loop song")
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
