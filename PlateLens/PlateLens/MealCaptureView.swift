import PhotosUI
import SwiftUI
import UIKit

struct MealCaptureView: View {
    @EnvironmentObject private var store: AppStore
    @AppStorage("plateLens.openAIModel") private var openAIModel = "gpt-4.1-mini"
    @AppStorage("plateLens.goalCalories") private var goalCalories = NutritionGoals.standard.calories
    @AppStorage("plateLens.goalProtein") private var goalProtein = NutritionGoals.standard.protein
    @AppStorage("plateLens.goalCarbs") private var goalCarbs = NutritionGoals.standard.carbs
    @AppStorage("plateLens.goalFat") private var goalFat = NutritionGoals.standard.fat

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var draftEstimate: MealEstimate?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var showsCamera = false

    private let keychain = KeychainStore()
    private let service = OpenAIAnalysisService()

    private var goals: NutritionGoals {
        NutritionGoals(calories: goalCalories, protein: goalProtein, carbs: goalCarbs, fat: goalFat)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    imageStage
                    captureControls
                    actionPanel
                    todayPanel
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("PlateLens")
            .fullScreenCover(isPresented: $showsCamera) {
                CameraCaptureView { image in
                    selectedImage = image
                    selectedPhoto = nil
                    showsCamera = false
                } onCancel: {
                    showsCamera = false
                }
                .ignoresSafeArea()
            }
            .sheet(item: $draftEstimate) { estimate in
                MealEditorView(estimate: estimate, image: selectedImage) { edited in
                    let imageData = selectedImage?.jpegData(compressionQuality: 0.78)
                    store.add(MealEntry(estimate: edited, imageJPEG: imageData))
                    draftEstimate = nil
                    selectedImage = nil
                    selectedPhoto = nil
                }
            }
            .alert("Analysis issue", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var imageStage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))

            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(alignment: .bottomTrailing) {
                        HStack(spacing: 10) {
                            Button {
                                showsCamera = true
                            } label: {
                                Label("Camera", systemImage: "camera")
                                    .font(.headline)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(.ultraThinMaterial, in: Capsule())
                            }
                            .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Label("Change", systemImage: "photo.on.rectangle")
                                    .font(.headline)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(.ultraThinMaterial, in: Capsule())
                            }
                        }
                        .padding()
                    }
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 74))
                        .foregroundStyle(.green)

                    Text("Add a meal photo")
                        .font(.title2.bold())

                    Text("PlateLens will estimate calories and macros, then let you correct the result.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    HStack(spacing: 10) {
                        Button {
                            showsCamera = true
                        } label: {
                            Label("Camera", systemImage: "camera")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("Photo", systemImage: "photo")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 360)
            }
        }
        .task(id: selectedPhoto) {
            await loadSelectedPhoto()
        }
    }

    private var captureControls: some View {
        HStack(spacing: 10) {
            Button {
                showsCamera = true
            } label: {
                Label("Camera", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("Library", systemImage: "photo.stack")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private var actionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Photo analysis")
                        .font(.headline)
                    Text("You review every estimate before it enters the diary.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Button {
                Task {
                    await analyze()
                }
            } label: {
                HStack {
                    if isAnalyzing {
                        ProgressView()
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isAnalyzing ? "Analyzing..." : "Analyze meal")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(selectedImage == nil || isAnalyzing)

            Button {
                selectedImage = nil
                selectedPhoto = nil
                draftEstimate = MealEstimate.manualDraft
            } label: {
                Label("Add manually", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var todayPanel: some View {
        let totals = store.todayTotals

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Today")
                    .font(.headline)

                Spacer()

                Text("\(store.todayEntries.count) meals")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            MacroProgressTile(
                title: "Calories",
                value: "\(totals.calories)",
                target: "\(goals.calories)",
                unit: "kcal",
                progress: goals.progress(for: totals, macro: .calories),
                color: .green
            )

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

            MacroProgressTile(
                title: "Fat",
                value: totals.fat.clean,
                target: goals.fat.clean,
                unit: "g",
                progress: goals.progress(for: totals, macro: .fat),
                color: .pink
            )
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func loadSelectedPhoto() async {
        guard let selectedPhoto else {
            return
        }

        do {
            if let data = try await selectedPhoto.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                selectedImage = image
            }
        } catch {
            errorMessage = "Could not load the selected photo."
        }
    }

    private func analyze() async {
        guard let selectedImage else {
            return
        }

        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            let estimate = try await service.analyze(image: selectedImage, apiKey: keychain.readAPIKey(), model: openAIModel)
            draftEstimate = estimate
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CameraCaptureView: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var onImage: (UIImage) -> Void
        var onCancel: () -> Void

        init(onImage: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImage = onImage
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            } else {
                onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}

struct MacroProgressTile: View {
    var title: String
    var value: String
    var target: String
    var unit: String
    var progress: Double
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(value)/\(target) \(unit)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            ProgressView(value: min(progress, 1))
                .tint(progress > 1 ? .red : color)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.title3.bold())
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    MealCaptureView()
        .environmentObject(AppStore())
}
