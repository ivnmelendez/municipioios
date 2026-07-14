import SwiftUI

struct OficinaRootView: View {
    let authVM: AuthViewModel
    @SceneStorage("oficinaTab") private var tab = "rutas"

    var body: some View {
        TabView(selection: $tab) {
            Tab("Rutas", systemImage: "map.circle.fill", value: "rutas") {
                NavigationStack {
                    RutaEditorView()
                }
            }
            Tab("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right", value: "salir") {
                SignOutView(authVM: authVM)
            }
        }
        .tint(Color("Navy"))
        .overlay(alignment: .top) { NetworkStatusBanner() }
    }
}

// MARK: - Sign out placeholder tab

private struct SignOutView: View {
    let authVM: AuthViewModel
    @State private var confirming = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "person.circle")
                .font(.system(size: 64))
                .foregroundStyle(Color("Navy"))
            Text(authVM.displayName)
                .font(.title3.weight(.semibold))
            Text("Modo Oficina")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Cerrar sesión", role: .destructive) {
                confirming = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
            Spacer()
        }
        .confirmationDialog("¿Cerrar sesión?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) {
                Task { await authVM.signOut() }
            }
            Button("Cancelar", role: .cancel) {}
        }
    }
}
