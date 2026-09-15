import SwiftUI

@main
struct municipiosnAdminApp: App {
    @State private var authVM = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                switch authVM.authState {
                case .checking:
                    ProgressView("Cargando…")
                        .frame(width: 300, height: 200)
                case .unauthenticated:
                    LoginView(authVM: authVM)
                        .frame(minWidth: 400, minHeight: 500)
                case .authenticated:
                    if authVM.rol == "admin" || authVM.rol == "oficina" {
                        macOSRootView(authVM: authVM)
                    } else {
                        ContentUnavailableView(
                            "Acceso restringido",
                            systemImage: "lock.fill",
                            description: Text("Esta app es solo para administradores.")
                        )
                        .frame(minWidth: 400, minHeight: 300)
                    }
                }
            }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
