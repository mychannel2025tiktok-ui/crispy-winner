import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @AppStorage("plateLens.openAIModel") private var openAIModel = "gpt-4.1-mini"
    @AppStorage("plateLens.goalCalories") private var goalCalories = NutritionGoals.standard.calories
    @AppStorage("plateLens.goalProtein") private var goalProtein = NutritionGoals.standard.protein
    @AppStorage("plateLens.goalCarbs") private var goalCarbs = NutritionGoals.standard.carbs
    @AppStorage("plateLens.goalFat") private var goalFat = NutritionGoals.standard.fat

    @State private var apiKey: String = ""
    @State private var savedMessage = false
    @State private var exportFile: ExportFile?
    @State private var exportError: String?
    @State private var showsClearConfirmation = false

    private let keychain = KeychainStore()

    var body: some View {
        NavigationStack {
            Form {
                Section("API") {
                    SecureField("OpenAI API key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("Model", text: $openAIModel)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button {
                        keychain.saveAPIKey(apiKey)
                        savedMessage = true
                    } label: {
                        Label("Save key", systemImage: "key.fill")
                    }

                    Button(role: .destructive) {
                        apiKey = ""
                        keychain.saveAPIKey("")
                        savedMessage = true
                    } label: {
                        Label("Remove key", systemImage: "key.slash")
                    }
                } footer: {
                    Text("Your key is stored in the iPhone Keychain and is not written into the app source.")
                }

                Section("Daily Goals") {
                    NumberField(title: "Calories", value: $goalCalories, unit: "kcal")
                    DecimalField(title: "Protein", value: $goalProtein, unit: "g")
                    DecimalField(title: "Carbs", value: $goalCarbs, unit: "g")
                    DecimalField(title: "Fat", value: $goalFat, unit: "g")

                    Button {
                        let standard = NutritionGoals.standard
                        goalCalories = standard.calories
                        goalProtein = standard.protein
                        goalCarbs = standard.carbs
                        goalFat = standard.fat
                    } label: {
                        Label("Reset goals", systemImage: "arrow.counterclockwise")
                    }
                }

                Section("Analysis") {
                    LabeledContent("Provider", value: "OpenAI Vision")
                    LabeledContent("Model", value: openAIModel.isEmpty ? "gpt-4.1-mini" : openAIModel)
                    LabeledContent("Result", value: "Editable estimate")
                }

                Section("Data") {
                    Button {
                        prepareExport()
                    } label: {
                        Label("Prepare CSV export", systemImage: "tablecells")
                    }

                    if let exportFile {
                        ShareLink(item: exportFile.url) {
                            Label("Share \(exportFile.url.lastPathComponent)", systemImage: "square.and.arrow.up")
                        }
                    }

                    Button(role: .destructive) {
                        showsClearConfirmation = true
                    } label: {
                        Label("Delete meal history", systemImage: "trash")
                    }
                    .disabled(store.entries.isEmpty)
                }

                Section("Privacy") {
                    Label("Meal history stays on this device.", systemImage: "lock.shield")
                    Label("Photos are sent only when you tap Analyze.", systemImage: "photo.badge.checkmark")
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                apiKey = keychain.readAPIKey()
            }
            .confirmationDialog("Delete all saved meals?", isPresented: $showsClearConfirmation, titleVisibility: .visible) {
                Button("Delete meal history", role: .destructive) {
                    store.clearEntries()
                    exportFile = nil
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes local diary entries from this iPhone.")
            }
            .alert("Saved", isPresented: $savedMessage) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Settings were updated.")
            }
            .alert("Export issue", isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportError ?? "")
            }
        }
    }

    private func prepareExport() {
        do {
            exportFile = ExportFile(url: try store.writeCSVExport())
        } catch {
            exportError = "Could not prepare the CSV file."
        }
    }
}

struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

#Preview {
    SettingsView()
        .environmentObject(AppStore())
}
