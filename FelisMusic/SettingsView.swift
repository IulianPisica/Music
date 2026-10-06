import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("jamendoKey") private var jamendoKey = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(TrackSource.allCases) { SourceRow(source: $0) }
                } header: {
                    Text("Catalogs, searched top to bottom")
                } footer: {
                    Text("Full-length catalogs are tried first. Previews are only used when no full song is found.")
                }

                Section {
                    TextField("Jamendo client ID", text: $jamendoKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Link("Open devportal.jamendo.com",
                         destination: URL(string: "https://devportal.jamendo.com")!)
                } header: {
                    Text("Jamendo key (only key needed)")
                } footer: {
                    Text("1. Open the link above and create a free account.\n2. Create an application.\n3. Copy its Client ID and paste it here.\nIt works right away, no rebuild. Leave it empty to skip Jamendo. Every other catalog needs no key.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
        .tint(felisRed)
    }
}

private struct SourceRow: View {
    let source: TrackSource
    @AppStorage private var on: Bool

    init(source: TrackSource) {
        self.source = source
        _on = AppStorage(wrappedValue: true, "enabled.\(source.rawValue)")
    }

    var body: some View {
        Toggle(isOn: $on) {
            VStack(alignment: .leading, spacing: 2) {
                Text(source.rawValue)
                Text(source.blurb).font(.caption).foregroundStyle(.gray)
            }
        }
    }
}
