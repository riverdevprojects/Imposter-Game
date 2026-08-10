import SwiftUI
import UniformTypeIdentifiers

/// Lets the user create, import, and delete custom categories. These are stored
/// on-device and merged into the word bank whenever a game is hosted.
struct CategoryManagerView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var categories: [WordCategory] = CustomCategoryStore.load()
    @State private var showingEditor = false
    @State private var importing = false
    @State private var importMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Add your own categories. Each needs a name and at least two words. Custom categories with the same name as a built-in one replace it.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                if categories.isEmpty {
                    Section {
                        Text("No custom categories yet.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Your categories") {
                        ForEach(categories) { category in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.name).font(.headline)
                                Text("\(category.words.count) words · \(category.words.prefix(4).joined(separator: ", "))\(category.words.count > 4 ? "…" : "")")
                                    .font(.caption).foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }

                Section {
                    Button {
                        showingEditor = true
                    } label: {
                        Label("New Category", systemImage: "plus.circle.fill")
                    }
                    Button {
                        importing = true
                    } label: {
                        Label("Import from JSON File", systemImage: "square.and.arrow.down")
                    }
                } footer: {
                    Text("JSON format: { \"categories\": [ { \"name\": \"Snacks\", \"words\": [\"Chips\", \"Candy\"] } ] }")
                        .font(.caption2)
                }
            }
            .navigationTitle("Custom Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingEditor) {
                CategoryEditorView { newCategory in
                    categories = CustomCategoryStore.upsert(newCategory)
                }
            }
            .fileImporter(isPresented: $importing,
                          allowedContentTypes: [.json],
                          allowsMultipleSelection: false) { result in
                handleImport(result)
            }
            .alert("Import", isPresented: Binding(
                get: { importMessage != nil },
                set: { if !$0 { importMessage = nil } }
            )) {
                Button("OK") { importMessage = nil }
            } message: {
                Text(importMessage ?? "")
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            categories = CustomCategoryStore.delete(named: categories[index].name)
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importMessage = "Couldn't import: \(error.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else { return }
            let needsScope = url.startAccessingSecurityScopedResource()
            defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                importMessage = "Couldn't read that file."
                return
            }
            let imported = CustomCategoryStore.decodeImport(data).filter { $0.words.count >= 2 }
            guard !imported.isEmpty else {
                importMessage = "No valid categories found in that file."
                return
            }
            for category in imported { categories = CustomCategoryStore.upsert(category) }
            importMessage = "Imported \(imported.count) categor\(imported.count == 1 ? "y" : "ies")."
        }
    }
}

/// Form for entering a single category: a name and a list of words.
struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (WordCategory) -> Void

    @State private var name = ""
    @State private var wordsText = ""

    private var parsedWords: [String] {
        wordsText
            .split(whereSeparator: { $0 == "\n" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && parsedWords.count >= 2
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Snacks", text: $name)
                        .autocorrectionDisabled()
                }
                Section("Words") {
                    TextEditor(text: $wordsText)
                        .frame(minHeight: 160)
                    Text("One per line, or separated by commas. \(parsedWords.count) word\(parsedWords.count == 1 ? "" : "s") so far.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(WordCategory(name: name.trimmingCharacters(in: .whitespaces),
                                            words: parsedWords))
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
