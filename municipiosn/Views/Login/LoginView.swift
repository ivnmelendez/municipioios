import SwiftUI

struct LoginView: View {
    @State private var vm: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?
    @State private var appeared = false

    enum Field { case email, password }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    init(vm: AuthViewModel) {
        _vm = State(wrappedValue: vm)
    }

    var body: some View {
        ZStack {
            Color("Background")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image("logo_dark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.spring(duration: 0.6, bounce: 0.2).delay(0.05), value: appeared)

                Spacer().frame(height: 40)

                VStack(spacing: 16) {
                    VStack(spacing: 0) {
                        TextField("Correo electrónico", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)

                        Divider()
                            .padding(.leading, 16)

                        SecureField("Contraseña", text: $password)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { Task { await vm.signIn(email: email, password: password) } }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                    }
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.spring(duration: 0.55, bounce: 0.15).delay(0.15), value: appeared)

                    if let error = vm.errorMessage {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    VStack(spacing: 12) {
                        Button {
                            Task { await vm.signIn(email: email, password: password) }
                        } label: {
                            Group {
                                if vm.isLoading {
                                    ProgressView()
                                } else {
                                    Text("Iniciar sesión")
                                        .font(.body.weight(.semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.glass)
                        .disabled(vm.isLoading)

                        Button {
                            Task { await vm.signInWithGoogle() }
                        } label: {
                            HStack(spacing: 10) {
                                Image("google_logo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                Text("Continuar con Google")
                                    .font(.body.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.glass)
                        .disabled(vm.isLoading)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.spring(duration: 0.5).delay(0.25), value: appeared)
                }
                .padding(.horizontal, 24)

                Spacer()

                Text("Versión \(appVersion)")
                    .font(.caption2)
                    .foregroundStyle(Color("TextMuted").opacity(0.6))
                    .padding(.bottom, 16)
                    .padding(.top, 8)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    focusedField = nil
                } label: {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear { appeared = true }
        .animation(.default, value: vm.errorMessage)
        .onChange(of: vm.errorMessage) { _, error in
            if error != nil { HapticService.error() }
        }
    }
}
