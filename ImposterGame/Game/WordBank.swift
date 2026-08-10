import Foundation

/// Loads `categories.json` from the app bundle and hands out words, avoiding
/// immediate repeats within a session.
final class WordBank {
    private(set) var categories: [WordCategory] = []
    /// Words used in the last `recentWindow` rounds, to avoid repeats.
    private var recentWords: [String] = []
    private let recentWindow = 8

    /// Category names for the picker (does not include the "Random" sentinel).
    var categoryNames: [String] { categories.map { $0.name } }

    init(bundle: Bundle = .main) {
        load(from: bundle)
    }

    /// Rebuild the category list = bundled categories + user categories. Custom
    /// categories override a bundled one of the same name. Call before a round
    /// so freshly added categories are available.
    func reload(bundle: Bundle = .main) {
        load(from: bundle)
    }

    private func load(from bundle: Bundle) {
        var bundled: [WordCategory] = []
        if let url = bundle.url(forResource: "categories", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let file = try? JSONDecoder().decode(CategoryFile.self, from: data) {
            bundled = file.categories.filter { !$0.words.isEmpty }
        } else {
            assertionFailure("categories.json missing or malformed")
            bundled = [WordCategory(name: "Animals", words: ["Elephant", "Penguin", "Giraffe", "Tiger"])]
        }

        let custom = CustomCategoryStore.load().filter { !$0.words.isEmpty }
        let customNames = Set(custom.map { $0.name.lowercased() })
        // Custom categories win on name clash; then append the rest.
        categories = custom + bundled.filter { !customNames.contains($0.name.lowercased()) }
    }

    func randomCategoryName() -> String {
        categories.randomElement()?.name ?? "Animals"
    }

    private func words(in categoryName: String) -> [String] {
        if categoryName == LobbySettings.randomCategory {
            return categories.flatMap { $0.words }
        }
        return categories.first { $0.name == categoryName }?.words ?? categories.flatMap { $0.words }
    }

    /// A random word from the category, preferring words not seen recently.
    func pickWord(category: String) -> String {
        let pool = words(in: category)
        guard !pool.isEmpty else { return "Mystery" }
        let fresh = pool.filter { !recentWords.contains($0) }
        let chosen = (fresh.isEmpty ? pool : fresh).randomElement()!
        recentWords.append(chosen)
        if recentWords.count > recentWindow { recentWords.removeFirst(recentWords.count - recentWindow) }
        return chosen
    }

    /// A decoy word from the same category, different from `secret`.
    func pickDecoy(category: String, excluding secret: String) -> String? {
        let pool = words(in: category).filter { $0 != secret }
        return pool.randomElement()
    }
}
