import SwiftUI

struct LoginView: View {
    @State private var vm: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

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
                ScrollView {
                    VStack(spacing: 32) {
                        Spacer(minLength: 60)

                        Image("logo_dark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 160, height: 160)

                        // Form
                        VStack(spacing: 0) {
                            Group {
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
                        }
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(spacing: 12) {
                            if let error = vm.errorMessage {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                    Text(error)
                                        .font(.footnote)
                                }
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                            }

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

                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 24)
                }

                Text("Versión \(appVersion)")
                    .font(.caption2)
                    .foregroundStyle(Color("TextMuted").opacity(0.6))
                    .padding(.bottom, 16)
                    .padding(.top, 8)
            }
        }
    }
}
