import SwiftUI
import UserNotifications

// MARK: - Notification tap handler

final class NotificacionDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificacionDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let destino = response.notification.request.content.userInfo["destino"] as? String
        if destino == "rondines" {
            UserDefaults.standard.set(true, forKey: "pendingRondines")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .abrirRondines, object: nil)
            }
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}

// MARK: - App

@main
struct municipiosnApp: App {
    @State private var authVM = AuthViewModel()

    init() {
        URLCache.shared = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024,
            directory: nil
        )
        UNUserNotificationCenter.current().delegate = NotificacionDelegate.shared
        BackgroundRefreshService.shared.registrar()
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
                        .task { await OfflineQueueService.shared.procesarQueue() }
                        .task { BackgroundRefreshService.shared.programar() }
                        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                            BackgroundRefreshService.shared.programar()
                        }
                        .task {
                            _ = try? await UNUserNotificationCenter.current().requestAuthorization(
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
