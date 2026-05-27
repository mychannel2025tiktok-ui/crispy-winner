import SwiftUI
import UIKit

struct DiaryView: View {
    @EnvironmentObject private var store: AppStore
    @AppStorage("plateLens.goalCalories") private var goalCalories = NutritionGoals.standard.calories
    @AppStorage("plateLens.goalProtein") private var goalProtein = NutritionGoals.standard.protein
    @AppStorage("plateLens.goalCarbs") private var goalCarbs = NutritionGoals.standard.carbs
    @AppStorage("plateLens.goalFat") private var goalFat = NutritionGoals.standard.fat

    @State private var editorSheet: DiaryEditorSheet?

    private var goals: NutritionGoals {
        NutritionGoals(calories: goalCalories, protein: goalProtein, carbs: goalCarbs, fat: goalFat)
    }

    var body: some View {
        NavigationStack {
            List {
                totalsSection
                weekSection

                if store.entries.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No meals yet",
                            systemImage: "fork.knife",
                            description: Text("Scanned meals will appear here.")
                        )
                    }
                } else {
                    ForEach(entryGroups) { group in
                        Section {
                            ForEach(group.entries) { entry in
                                MealRow(entry: entry)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        editorSheet = .edit(entry)
                                    }
                            }
                            .onDelete { offsets in
                                let ids = offsets.map { group.entries[$0].id }
                                store.delete(ids: ids)
                            }
                        } header: {
                            HStack {
                                Text(group.day, format: .dateTime.weekday(.wide).month(.abbreviated).day(.defaultDigits))
                                Spacer()
                                Text("\(group.totals.calories) kcal")
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Diary")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editorSheet = .manual(.manualDraft)
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editorSheet) { sheet in
                switch sheet {
                case .manual(let estimate):
                    MealEditorView(estimate: estimate, image: nil) { edited in
                        store.add(MealEntry(estimate: edited, imageJPEG: nil))
                        editorSheet = nil
                    }
                case .edit(let entry):
                    MealEditorView(estimate: entry.estimate, image: entry.uiImage) { edited in
                        var updated = entry
                        updated.estimate = edited
                        store.update(updated)
                        editorSheet = nil
                    }
                }
            }
        }
    }

    private var totalsSection: some View {
        let totals = store.todayTotals

        return Section("Today") {
            MacroProgressTile(
                title: "Calories",
                value: "\(totals.calories)",
                target: "\(goals.calories)",
                unit: "kcal",
                progress: goals.progress(for: totals, macro: .calories),
                color: .green
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
            .listRowBackground(Color.clear)

            HStack(spacing: 10) {
                MacroProgressTile(
                    title: "Protein",
                    value: totals.protein.clean,
                    target: goals.protein.clean,
                    unit: "g",
                    progress: goals.progress(for: totals, macro: .protein),
                    color: .blue
                )
                MacroProgressTile(
                    title: "Carbs",
                    value: totals.carbs.clean,
                    target: goals.carbs.clean,
                    unit: "g",
                    progress: goals.progress(for: totals, macro: .carbs),
                    color: .orange
                )
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowBackground(Color.clear)

            MacroProgressTile(
                title: "Fat",
                value: totals.fat.clean,
                target: goals.fat.clean,
                unit: "g",
                progress: goals.progress(for: totals, macro: .fat),
                color: .pink
            )
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
        }
    }

    private var weekSection: some View {
        Section("Last 7 days") {
            HStack(spacing: 8) {
                ForEach(lastSevenDays, id: \.day) { item in
                    VStack(spacing: 6) {
                        GeometryReader { proxy in
                            let height = proxy.size.height
                            let ratio = min(Double(item.totals.calories) / Double(max(goalCalories, 1)), 1)

                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color(.tertiarySystemGroupedBackground))
                                .overlay(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(item.isToday ? Color.green : Color.green.opacity(0.55))
                                        .frame(height: height * ratio)
                                }
                        }
                        .frame(height: 74)

                        Text(item.day, format: .dateTime.weekday(.narrow))
                            .font(.caption2)
                            .foregroundStyle(item.isToday ? .primary : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(Text(item.day, format: .dateTime.weekday(.wide).month(.abbreviated).day(.defaultDigits)))
                    .accessibilityValue("\(item.totals.calories) calories")
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
        }
    }

    private var entryGroups: [DiaryDayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: store.entries) { entry in
            calendar.startOfDay(for: entry.date)
        }

        return grouped.map { day, entries in
            let sortedEntries = entries.sorted { $0.date > $1.date }
            return DiaryDayGroup(
                day: day,
                entries: sortedEntries,
                totals: store.totals(for: sortedEntries)
            )
        }
        .sorted { $0.day > $1.day }
    }

    private var lastSevenDays: [DiaryDaySummary] {
        let calendar = Calendar.current
        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: Date()) else {
                return nil
            }

            let start = calendar.startOfDay(for: day)
            let entries = store.entries.filter { calendar.isDate($0.date, inSameDayAs: start) }
            return DiaryDaySummary(
                day: start,
                totals: store.totals(for: entries),
                isToday: calendar.isDateInToday(start)
            )
        }
    }
}

struct DiaryDayGroup: Identifiable {
    var id: Date { day }
    var day: Date
    var entries: [MealEntry]
    var totals: DailyTotals
}

struct DiaryDaySummary {
    var day: Date
    var totals: DailyTotals
    var isToday: Bool
}

enum DiaryEditorSheet: Identifiable {
    case manual(MealEstimate)
    case edit(MealEntry)

    var id: String {
        switch self {
        case .manual(let estimate):
            "manual-\(estimate.id)"
        case .edit(let entry):
            "edit-\(entry.id.uuidString)"
        }
    }
}

private extension MealEntry {
    var uiImage: UIImage? {
        guard let imageJPEG else {
            return nil
        }

        return UIImage(data: imageJPEG)
    }
}

struct MealRow: View {
    var entry: MealEntry

    var body: some View {
        HStack(spacing: 12) {
            if let imageJPEG = entry.imageJPEG, let image = UIImage(data: imageJPEG) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .frame(width: 58, height: 58)
                    .overlay {
                        Image(systemName: "fork.knife")
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.estimate.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(entry.date, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("P \(entry.estimate.protein.clean)g  C \(entry.estimate.carbs.clean)g  F \(entry.estimate.fat.clean)g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(entry.estimate.calories)")
                    .font(.headline)
                    .monospacedDigit()
                Text("kcal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DiaryView()
        .environmentObject(AppStore())
}
