import SwiftUI
import UserNotifications

@main
struct municipiosnApp: App {
    @State private var authVM = AuthViewModel()

    init() {
        URLCache.shared = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024,
            directory: nil
        )
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch authVM.authState {
                case .checking:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color("Background"))
                case .authenticated:
                    ContentView(authVM: authVM)
                        .environment(authVM)
                        .task { await RealtimeService.shared.subscribir() }
                        .task {
                            try? await UNUserNotificationCenter.current().requestAuthorization(
                                options: [.alert, .sound, .badge]
                            )
                        }
                case .unauthenticated:
                    LoginView(vm: authVM)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authVM.authState)
        }
    }
}
