import SwiftUI
import UserNotifications

@main
struct municipiosnApp: App {
    @State private var authVM = AuthViewModel()

    init() {
        Task {
            try? await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
        }
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
                        .task { await RealtimeService.shared.subscribir() }
                case .unauthenticated:
                    LoginView(vm: authVM)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authVM.authState)
        }
    }
}
