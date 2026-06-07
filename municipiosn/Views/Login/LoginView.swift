import SwiftUI

struct LoginView: View {
    @State private var vm: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    init(vm: AuthViewModel) {
        _vm = State(wrappedValue: vm)
    }

    var body: some View {
        ZStack {
            Color("Background")
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 60)

                    // Logo
                    VStack(spacing: 12) {
                        Image("logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 20))

                        Text("Municipio SN")
                            .font(.title.bold())
                            .foregroundStyle(Color("Navy"))

                        Text("Estructuras Publicitarias")
                            .font(.subheadline)
                            .foregroundStyle(Color("TextMuted"))
                    }

                    // Form
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Correo electrónico")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color("TextMuted"))
                            TextField("correo@sannicolasdelasgarza.gob.mx", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .email)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .password }
                                .padding(14)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Contraseña")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color("TextMuted"))
                            SecureField("••••••••", text: $password)
                                .focused($focusedField, equals: .password)
                                .submitLabel(.go)
                                .onSubmit { Task { await vm.signIn(email: email, password: password) } }
                                .padding(14)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }

                        if let error = vm.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(error)
                                    .font(.caption)
                            }
                            .foregroundStyle(.red)
                            .padding(12)
                            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                        }

                        Button {
                            Task { await vm.signIn(email: email, password: password) }
                        } label: {
                            Group {
                                if vm.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Iniciar sesión")
                                        .font(.body.weight(.semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(16)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color("MunicipioCyan"))
                        .disabled(vm.isLoading || email.isEmpty || password.isEmpty)

                        HStack {
                            Rectangle()
                                .fill(Color("TextMuted").opacity(0.25))
                                .frame(height: 1)
                            Text("o")
                                .font(.caption)
                                .foregroundStyle(Color("TextMuted"))
                                .padding(.horizontal, 8)
                            Rectangle()
                                .fill(Color("TextMuted").opacity(0.25))
                                .frame(height: 1)
                        }

                        Button {
                            Task { await vm.signInWithGoogle() }
                        } label: {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 22, height: 22)
                                    Text("G")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Color(red: 0.259, green: 0.522, blue: 0.957))
                                }
                                Text("Continuar con Google")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color("Navy"))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.isLoading)
                    }
                    .padding(.horizontal, 4)

                    Spacer()
                }
                .padding(.horizontal, 28)
            }
        }
    }
}
