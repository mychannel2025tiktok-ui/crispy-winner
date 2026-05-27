import Foundation

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var entries: [MealEntry] = []

    private let entriesKey = "plateLens.entries.v1"

    init() {
        load()
    }

    var todayEntries: [MealEntry] {
        entries
            .filter { Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
    }

    var todayTotals: DailyTotals {
        totals(for: todayEntries)
    }

    func add(_ entry: MealEntry) {
        entries.insert(entry, at: 0)
        save()
    }

    func update(_ entry: MealEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else {
            return
        }

        entries[index] = entry
        entries.sort { $0.date > $1.date }
        save()
    }

    func delete(at offsets: IndexSet) {
        let sorted = entries.sorted { $0.date > $1.date }
        let idsToDelete = offsets.map { sorted[$0].id }
        delete(ids: idsToDelete)
    }

    func delete(ids: [UUID]) {
        entries.removeAll { ids.contains($0.id) }
        save()
    }

    func clearEntries() {
        entries = []
        save()
    }

    func totals(for meals: [MealEntry]) -> DailyTotals {
        meals.reduce(DailyTotals(calories: 0, protein: 0, carbs: 0, fat: 0)) { partial, entry in
            DailyTotals(
                calories: partial.calories + entry.estimate.calories,
                protein: partial.protein + entry.estimate.protein,
                carbs: partial.carbs + entry.estimate.carbs,
                fat: partial.fat + entry.estimate.fat
            )
        }
    }

    func writeCSVExport() throws -> URL {
        let formatter = ISO8601DateFormatter()
        let header = [
            "date",
            "title",
            "calories",
            "protein_g",
            "carbs_g",
            "fat_g",
            "confidence",
            "portion",
            "assumptions",
            "ingredients"
        ].joined(separator: ",")

        let rows = entries
            .sorted { $0.date > $1.date }
            .map { entry in
                [
                    formatter.string(from: entry.date),
                    csvEscape(entry.estimate.title),
                    "\(entry.estimate.calories)",
                    entry.estimate.protein.clean,
                    entry.estimate.carbs.clean,
                    entry.estimate.fat.clean,
                    entry.estimate.confidence.clean,
                    csvEscape(entry.estimate.portionDescription),
                    csvEscape(entry.estimate.assumptions.joined(separator: "; ")),
                    csvEscape(entry.estimate.ingredients.map { "\($0.name) \($0.amount)" }.joined(separator: "; "))
                ].joined(separator: ",")
            }

        let csv = ([header] + rows).joined(separator: "\n")
        let filename = "PlateLens-\(Self.exportTimestamp()).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: entriesKey) else {
            entries = []
            return
        }

        do {
            entries = try JSONDecoder().decode([MealEntry].self, from: data)
                .sorted { $0.date > $1.date }
        } catch {
            entries = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            UserDefaults.standard.set(data, forKey: entriesKey)
        } catch {
            assertionFailure("Could not save entries: \(error.localizedDescription)")
        }
    }

    private func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private static func exportTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}
