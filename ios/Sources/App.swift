import SwiftUI

@main
struct GoodManNetApp: App {
    @AppStorage("gm_dark") private var dark = true
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(dark ? .dark : .light)
        }
    }
}
