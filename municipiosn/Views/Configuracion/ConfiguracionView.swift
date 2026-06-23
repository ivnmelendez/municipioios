import SwiftUI
import PhotosUI
import UIKit

struct ConfiguracionView: View {
    var vm: DashboardViewModel
    @AppStorage("notificacionesHabilitadas") private var notificaciones = true
    @State private var photoItem: PhotosPickerItem?
    @State private var fotoPerfil: Image?
    @State private var confirmarCerrarSesion = false
    @State private var mostrarEditorDashboard = false
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var auth

    var body: some View {
        NavigationStack {
        List {

                // MARK: Header perfil
                Section {
                    HStack(spacing: 16) {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            ZStack(alignment: .bottomTrailing) {
                                Group {
                                    if let foto = fotoPerfil {
                                        foto
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 72, height: 72)
                                            .clipShape(Circle())
                                    } else {
                                        Text(auth.initiales.isEmpty ? "?" : auth.initiales)
                                            .font(.system(size: 24, weight: .bold, design: .rounded))
                                            .foregroundStyle(Color("Navy"))
                                            .frame(width: 72, height: 72)
                                            .background(Color("Navy").opacity(0.1), in: Circle())
                                    }
                                }
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(5)
                                    .background(Color("Navy"), in: Circle())
                                    .offset(x: 2, y: 2)
                            }
                        }
                        .buttonStyle(.plain)
                        .onChange(of: photoItem) {
                            Task {
                                if let data = try? await photoItem?.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data) {
                                    fotoPerfil = Image(uiImage: uiImage)
                                    guardarFoto(data: data)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(auth.displayName.isEmpty ? "Usuario" : auth.displayName)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(auth.rol == "campo" ? "Campo" : "Administrador")
                                .font(.subheadline)
                                .foregroundStyle(Color("TextMuted"))
                            Text("San Nicolás de los Garza, NL")
                                .font(.caption)
                                .foregroundStyle(Color("TextMuted").opacity(0.7))
                        }
                    }
                    .padding(.vertical, 6)
                }

                // MARK: Preferencias
                Section("Preferencias") {
                    Toggle(isOn: $notificaciones) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Notificaciones")
                                    .font(.body)
                                Text("Intervenciones, daños y rondín")
                                    .font(.caption)
                                    .foregroundStyle(Color("TextMuted"))
                            }
                        } icon: {
                            Image(systemName: "bell.badge.fill")
                                .foregroundStyle(Color("Navy"))
                        }
                    }
                    .tint(Color("Navy"))
                    .onChange(of: notificaciones) { _, habilitadas in
                        if habilitadas {
                            Task { await pedirPermisoNotificaciones() }
                        } else {
                            RealtimeService.shared.cancelarNotificacionSabado()
                        }
                    }

                    Button {
                        mostrarEditorDashboard = true
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Personalizar inicio")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Text("Elige qué tarjetas ver y en qué orden")
                                    .font(.caption)
                                    .foregroundStyle(Color("TextMuted"))
                            }
                        } icon: {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundStyle(Color("Navy"))
                        }
                    }
                    .buttonStyle(.plain)
                }

                // MARK: Debug
                #if DEBUG
                Section("Desarrollo") {
                    Button {
                        probarNotificacion()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Probar notificación de rondín")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Text("Llega en 2 minutos — cierra la app para probar")
                                    .font(.caption)
                                    .foregroundStyle(Color("TextMuted"))
                            }
                        } icon: {
                            Image(systemName: "bell.and.waves.left.and.right.fill")
                                .foregroundStyle(Color("Navy"))
                        }
                    }
                    .buttonStyle(.plain)
                }
                #endif

                // MARK: Sesión
                Section {
                    Button(role: .destructive) {
                        confirmarCerrarSesion = true
                    } label: {
                        Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                // MARK: Footer versión
                Section {
                    EmptyView()
                } footer: {
                    Text("Municipios SN · Versión 1.0\nSan Nicolás de los Garza, NL")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Mi perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }
                        .fontWeight(.semibold)
                        .tint(Color("Navy"))
                }
            }
            .sheet(isPresented: $mostrarEditorDashboard) {
                EditorDashboardSheet(vm: vm)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .onAppear { cargarFoto() }
        }
        .alert("¿Cerrar sesión?", isPresented: $confirmarCerrarSesion) {
            Button("Cerrar sesión", role: .destructive) {
                Task { await auth.signOut() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se cerrará tu sesión en este dispositivo.")
        }
    }

    // MARK: Persistencia foto

    private func guardarFoto(data: Data) {
        try? data.write(to: fotoURL())
    }

    private func cargarFoto() {
        guard let data = try? Data(contentsOf: fotoURL()),
              let uiImage = UIImage(data: data) else { return }
        fotoPerfil = Image(uiImage: uiImage)
    }

    private func pedirPermisoNotificaciones() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            if granted {
                RealtimeService.shared.programarNotificacionSabado()
            } else {
                notificaciones = false
            }
        case .denied:
            notificaciones = false
            if let url = URL(string: UIApplication.openSettingsURLString) {
                await UIApplication.shared.open(url)
            }
        default:
            RealtimeService.shared.programarNotificacionSabado()
        }
    }

    private func probarNotificacion() {
        let content = UNMutableNotificationContent()
        content.title = "Historial de rondín disponible"
        content.body = "Ya puedes revisar las estructuras visitadas hoy por el equipo de campo."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 120, repeats: false)
        let request = UNNotificationRequest(identifier: "rondin_prueba", content: content, trigger: trigger)
        Task { try? await UNUserNotificationCenter.current().add(request) }
    }

    private func fotoURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("perfil.jpg")
    }
}
