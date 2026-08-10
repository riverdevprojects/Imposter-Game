import Foundation

/// A named list of words. Used both for the bundled `categories.json` and for
/// user-created / imported categories.
struct WordCategory: Codable, Identifiable, Equatable {
    let name: String
    let words: [String]
    var id: String { name }
}

/// A `Codable` wrapper matching the on-disk / bundled JSON shape:
/// `{ "categories": [ { "name": ..., "words": [...] } ] }`.
struct CategoryFile: Codable {
    let categories: [WordCategory]
}

/// Persists user-added categories locally (survives launches; no server).
enum CustomCategoryStore {
    private static let key = "imposter.customCategories"

    static func load() -> [WordCategory] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let cats = try? JSONDecoder().decode([WordCategory].self, from: data) else {
            return []
        }
        return cats
    }

    static func save(_ categories: [WordCategory]) {
        if let data = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Add or replace (by name, case-insensitive) a category. Returns the new list.
    @discardableResult
    static func upsert(_ category: WordCategory) -> [WordCategory] {
        var all = load()
        all.removeAll { $0.name.caseInsensitiveCompare(category.name) == .orderedSame }
        all.append(category)
        save(all)
        return all
    }

    @discardableResult
    static func delete(named name: String) -> [WordCategory] {
        var all = load()
        all.removeAll { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        save(all)
        return all
    }

    /// Decode a categories JSON file's contents into categories, tolerating
    /// either the wrapped `{ "categories": [...] }` form or a bare array.
    static func decodeImport(_ data: Data) -> [WordCategory] {
        if let file = try? JSONDecoder().decode(CategoryFile.self, from: data) {
            return file.categories.filter { !$0.words.isEmpty }
        }
        if let bare = try? JSONDecoder().decode([WordCategory].self, from: data) {
            return bare.filter { !$0.words.isEmpty }
        }
        return []
    }
}
