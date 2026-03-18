import SwiftUI

@main
struct GoogleTasksWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authManager = GoogleAuthManager()
    @StateObject private var viewModel: TasksViewModel
    
    init() {
        let auth = GoogleAuthManager()
        _authManager = StateObject(wrappedValue: auth)
        _viewModel = StateObject(wrappedValue: TasksViewModel(authManager: auth))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(viewModel)
                .frame(minWidth: 380, minHeight: 420)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            #if canImport(GoogleSignIn)
            if GIDSignIn.sharedInstance.handle(url) {
                return
            }
            #endif
        }
    }
}

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
