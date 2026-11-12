import SwiftUI

@main
struct StudyFlowApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background || phase == .inactive {
                UserDefaults.standard.synchronize()
            }
        }
    }
}
