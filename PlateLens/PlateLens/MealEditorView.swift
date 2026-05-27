import SwiftUI
import UIKit

struct MealEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var estimate: MealEstimate
    var image: UIImage?
    var onSave: (MealEstimate) -> Void

    init(estimate: MealEstimate, image: UIImage?, onSave: @escaping (MealEstimate) -> Void) {
        _estimate = State(initialValue: estimate)
        self.image = image
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                if let image {
                    Section {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .listRowInsets(EdgeInsets())
                }

                Section("Meal") {
                    TextField("Name", text: $estimate.title)
                    TextField("Portion", text: $estimate.portionDescription, axis: .vertical)
                }

                Section("Nutrition") {
                    NumberField(title: "Calories", value: $estimate.calories, unit: "kcal")
                    DecimalField(title: "Protein", value: $estimate.protein, unit: "g")
                    DecimalField(title: "Carbs", value: $estimate.carbs, unit: "g")
                    DecimalField(title: "Fat", value: $estimate.fat, unit: "g")
                }

                Section("Confidence") {
                    HStack {
                        Slider(value: $estimate.confidence, in: 0...1, step: 0.01)
                        Text("\(Int(estimate.confidence * 100))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                if !estimate.ingredients.isEmpty {
                    Section("Ingredients") {
                        ForEach($estimate.ingredients) { $ingredient in
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Ingredient", text: $ingredient.name)
                                    .font(.headline)
                                TextField("Amount", text: $ingredient.amount)
                                HStack {
                                    Text("\(ingredient.calories) kcal")
                                    Spacer()
                                    Text("P \(ingredient.protein.clean) C \(ingredient.carbs.clean) F \(ingredient.fat.clean)")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                if !estimate.assumptions.isEmpty {
                    Section("Assumptions") {
                        ForEach(estimate.assumptions, id: \.self) { assumption in
                            Text(assumption)
                        }
                    }
                }
            }
            .navigationTitle("Review meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(estimate)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(estimate.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct NumberField: View {
    var title: String
    @Binding var value: Int
    var unit: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: $value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }
}

struct DecimalField: View {
    var title: String
    @Binding var value: Double
    var unit: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: $value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    MealEditorView(estimate: .manualDraft, image: nil) { _ in }
}
