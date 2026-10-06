import SwiftUI

struct ScriptEditorView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var confirmClear = false
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Paste or type your script. Changes save automatically on this iPhone.")
                    .font(.callout).foregroundStyle(.secondary)
                TextEditor(text: $settings.script)
                    .font(.system(size: 20))
                    .scrollContentBackground(.hidden)
                    .background(.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("Script editor")
            }
            .padding()
            .navigationTitle("Script")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Clear", role: .destructive) { confirmClear = true } }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog("Clear the saved script?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear script", role: .destructive) { settings.script = "" }
            }
        }
    }
}
