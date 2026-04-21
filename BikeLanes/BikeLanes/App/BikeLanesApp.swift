import SwiftUI
import SwiftData

@main
struct BikeLanesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bicycle")
                .font(.system(size: 48))
            Text("Hello, Bike Lanes")
                .font(.title2)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
