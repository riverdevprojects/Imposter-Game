import Foundation

/// Loads `categories.json` from the app bundle and hands out words, avoiding
/// immediate repeats within a session.
final class WordBank {
    struct Category: Codable {
        let name: String
        let words: [String]
    }
    private struct Bank: Codable {
        let categories: [Category]
    }

    private(set) var categories: [Category] = []
    /// Words used in the last `recentWindow` rounds, to avoid repeats.
    private var recentWords: [String] = []
    private let recentWindow = 8

    /// Category names for the picker (does not include the "Random" sentinel).
    var categoryNames: [String] { categories.map { $0.name } }

    init(bundle: Bundle = .main) {
        load(from: bundle)
    }

    private func load(from bundle: Bundle) {
        guard let url = bundle.url(forResource: "categories", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let bank = try? JSONDecoder().decode(Bank.self, from: data) else {
            assertionFailure("categories.json missing or malformed")
            categories = [Category(name: "Animals", words: ["Elephant", "Penguin", "Giraffe", "Tiger"])]
            return
        }
        categories = bank.categories.filter { !$0.words.isEmpty }
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
