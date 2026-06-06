import Foundation
import Supabase

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
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        try? await auth.signOut()
        authState = .unauthenticated
    }
}
