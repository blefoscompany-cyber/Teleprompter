import SwiftUI

struct KeptRecordingsView: View {
    @ObservedObject var store: RecordingStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("These files stay on your iPhone until Photos saving succeeds. Export a copy if you need to recover an interrupted take. Do not delete this app while it holds videos you need.")
                        .font(.callout)
                }
                ForEach(store.pending, id: \.self) { url in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(dateLabel(url)).font(.headline)
                        Text(url.lastPathComponent).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        HStack {
                            Button(store.saving.contains(url) ? "Saving…" : "Save to Photos") { store.save(url) }
                                .buttonStyle(.borderedProminent)
                            ShareLink(item: url) { Label("Export", systemImage: "square.and.arrow.up") }
                                .buttonStyle(.bordered)
                        }.disabled(store.saving.contains(url))
                    }.padding(.vertical, 6)
                }
                if store.pending.isEmpty { Text("No videos waiting to save.") }
            }
            .navigationTitle("Kept videos")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
    private func dateLabel(_ url: URL) -> String {
        let date = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate
        return date?.formatted(date: .abbreviated, time: .shortened) ?? "Kept recording"
    }
}
