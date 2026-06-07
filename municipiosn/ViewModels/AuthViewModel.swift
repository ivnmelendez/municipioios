import Foundation
import Supabase
import AuthenticationServices

enum AuthState {
    case checking, authenticated, unauthenticated
}

@MainActor
@Observable
final class AuthViewModel {
    var authState: AuthState = .checking
    var errorMessage: String?
    var isLoading = false

    private let auth = SupabaseService.shared.client.auth

    init() {
        Task { await checkSession() }
    }

    func checkSession() async {
        do {
            _ = try await auth.session
            authState = .authenticated
        } catch {
            authState = .unauthenticated
        }
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await auth.signIn(email: email, password: password)
            authState = .authenticated
        } catch {
            errorMessage = localizedAuthError(error)
        }
    }

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await auth.signInWithOAuth(
                provider: .google,
                redirectTo: URL(string: "com.ivanmelendez.municipiosn://login-callback")
            ) { session in
                session.prefersEphemeralWebBrowserSession = true
            }
            authState = .authenticated
        } catch is CancellationError {
            // user cancelled, no error shown
        } catch {
            errorMessage = localizedAuthError(error)
        }
    }

    func signOut() async {
        try? await auth.signOut()
        authState = .unauthenticated
    }

    private func localizedAuthError(_ error: Error) -> String {
        let raw = error.localizedDescription.lowercased()
        if raw.contains("invalid login credentials") || raw.contains("invalid email or password") {
            return "Correo o contraseña incorrectos. Verifica tus datos e intenta de nuevo."
        } else if raw.contains("email not confirmed") {
            return "Tu cuenta aún no ha sido verificada. Revisa tu correo."
        } else if raw.contains("network") || raw.contains("internet") || raw.contains("offline") {
            return "Sin conexión a internet. Verifica tu red e intenta de nuevo."
        } else if raw.contains("too many requests") || raw.contains("rate limit") {
            return "Demasiados intentos. Espera unos minutos antes de intentar de nuevo."
        }
        return "Ocurrió un error inesperado. Intenta de nuevo."
    }
}
