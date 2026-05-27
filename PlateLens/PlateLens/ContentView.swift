import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            MealCaptureView()
                .tabItem {
                    Label("Scan", systemImage: "camera.viewfinder")
                }

            DiaryView()
                .tabItem {
                    Label("Diary", systemImage: "calendar")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(.green)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppStore())
}
