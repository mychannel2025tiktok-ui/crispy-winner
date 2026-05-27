import Foundation

struct MealEstimate: Codable, Equatable {
    var title: String
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var confidence: Double
    var portionDescription: String
    var assumptions: [String]
    var ingredients: [IngredientEstimate]

    static let empty = MealEstimate(
        title: "",
        calories: 0,
        protein: 0,
        carbs: 0,
        fat: 0,
        confidence: 0,
        portionDescription: "",
        assumptions: [],
        ingredients: []
    )

    static let manualDraft = MealEstimate(
        title: "Meal",
        calories: 0,
        protein: 0,
        carbs: 0,
        fat: 0,
        confidence: 1,
        portionDescription: "",
        assumptions: [],
        ingredients: []
    )
}

extension MealEstimate: Identifiable {
    var id: String {
        "\(title)-\(calories)-\(protein)-\(carbs)-\(fat)-\(confidence)"
    }
}

struct IngredientEstimate: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var amount: String
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double

    enum CodingKeys: String, CodingKey {
        case name
        case amount
        case calories
        case protein
        case carbs
        case fat
    }
}

struct MealEntry: Codable, Identifiable, Equatable {
    var id: UUID
    var date: Date
    var estimate: MealEstimate
    var imageJPEG: Data?

    init(id: UUID = UUID(), date: Date = Date(), estimate: MealEstimate, imageJPEG: Data?) {
        self.id = id
        self.date = date
        self.estimate = estimate
        self.imageJPEG = imageJPEG
    }
}

struct DailyTotals: Equatable {
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
}

struct NutritionGoals: Equatable {
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double

    static let standard = NutritionGoals(calories: 2200, protein: 140, carbs: 230, fat: 75)

    func progress(for totals: DailyTotals, macro: MacroKind) -> Double {
        let current: Double
        let target: Double

        switch macro {
        case .calories:
            current = Double(totals.calories)
            target = Double(calories)
        case .protein:
            current = totals.protein
            target = protein
        case .carbs:
            current = totals.carbs
            target = carbs
        case .fat:
            current = totals.fat
            target = fat
        }

        guard target > 0 else {
            return 0
        }

        return min(max(current / target, 0), 1.25)
    }
}

enum MacroKind {
    case calories
    case protein
    case carbs
    case fat
}

enum MealAnalysisError: LocalizedError {
    case missingAPIKey
    case invalidImage
    case invalidResponse
    case emptyResult
    case serverMessage(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Add your API key in Settings first."
        case .invalidImage:
            "The selected image could not be prepared."
        case .invalidResponse:
            "The analysis response could not be read."
        case .emptyResult:
            "No meal estimate was returned."
        case .serverMessage(let message):
            message
        }
    }
}

extension Double {
    var clean: String {
        if rounded() == self {
            return String(Int(self))
        }
        return String(format: "%.1f", self)
    }
}
