import SwiftUI
import PhotosUI
import UIKit
import Supabase
import UserNotifications

struct ConfiguracionView: View {
    var vm: DashboardViewModel?
    @AppStorage("notificacionesHabilitadas") private var notificaciones = true
    @State private var photoItem: PhotosPickerItem?
    @State private var fotoPerfil: Image?
    @State private var subiendoFoto = false
    @AppStorage("perfil_avatar_url_cache") private var avatarUrlCached = ""
    @State private var confirmarCerrarSesion = false
    @State private var mostrarEditorDashboard = false
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var auth

    private var initiales: String { auth.initiales }
    private var displayName: String { auth.displayName }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: Perfil
                    perfilCard
                        .padding(.horizontal, 20)

                    // MARK: Preferencias
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preferencias")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color("TextMuted"))
                            .padding(.horizontal, 20)

                        VStack(spacing: 0) {
                            HStack(spacing: 14) {
                                Image(systemName: "bell.badge.fill")
                                    .font(.system(size: 17))
                                    .foregroundStyle(Color("Navy"))
                                    .frame(width: 28)
                                Text("Notificaciones")
                                    .font(.body)
                                Spacer()
                                Toggle("", isOn: $notificaciones)
                                    .tint(Color("Azul"))
                                    .labelsHidden()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .onChange(of: notificaciones) { _, habilitadas in
                                if habilitadas {
                                    Task { await pedirPermisoNotificaciones() }
                                } else {
                                    RealtimeService.shared.cancelarNotificacionSabado()
                                }
                            }

                            Divider().padding(.leading, 58)

                            #if DEBUG
                            Button {
                                guard notificaciones else { return }
                                Task {
                                    let content = UNMutableNotificationContent()
                                    content.title = "Historial de rondín disponible"
                                    content.body = "Ya puedes revisar las estructuras visitadas hoy por el equipo de campo."
                                    content.sound = .default
                                    content.userInfo = ["destino": "rondines"]
                                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                                    let request = UNNotificationRequest(identifier: "test_rondin", content: content, trigger: trigger)
                                    try? await UNUserNotificationCenter.current().add(request)
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "bell.badge")
                                        .font(.system(size: 17))
                                        .foregroundStyle(.orange)
                                        .frame(width: 28)
                                    Text("Probar notificación (5s)")
                                        .font(.body)
                                        .foregroundStyle(.orange)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }

                            Divider().padding(.leading, 58)
                            #endif

                            if vm != nil {
                            Button { mostrarEditorDashboard = true } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.system(size: 17))
                                        .foregroundStyle(Color("Navy"))
                                        .frame(width: 28)
                                    Text("Personalizar inicio")
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color("TextMuted").opacity(0.4))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(.plain)
                            } // if vm != nil
                        }
                        .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .padding(.horizontal, 20)
                    }

                    // MARK: Sesión
                    Button {
                        confirmarCerrarSesion = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 17))
                                .foregroundStyle(.red)
                                .frame(width: 28)
                            Text("Cerrar sesión")
                                .font(.body)
                                .foregroundStyle(.red)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .padding(.horizontal, 20)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .background(Color("Background"))
            .navigationTitle("Mi perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }
                        .fontWeight(.semibold)
                        .tint(Color("Azul"))
                }
            }
            .sheet(isPresented: $mostrarEditorDashboard) {
                if let vm {
                    EditorDashboardSheet(vm: vm)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
            }
            .onAppear { cargarFoto() }
        }
        .alert("¿Cerrar sesión?", isPresented: $confirmarCerrarSesion) {
            Button("Cerrar sesión", role: .destructive) {
                dismiss()
                Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    await auth.signOut()
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se cerrará tu sesión en este dispositivo.")
        }
    }

    private var perfilCard: some View {
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
                            Text(initiales.isEmpty ? "?" : initiales)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color("Navy"))
                                .frame(width: 72, height: 72)
                                .background(Color("TextMuted").opacity(0.12), in: Circle())
                        }
                    }
                    Image(systemName: "camera.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(Color("Azul"), in: Circle())
                        .offset(x: 2, y: 2)
                }
            }
            .buttonStyle(.plain)
            .onChange(of: photoItem) {
                Task {
                    if let data = try? await photoItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data),
                       let compressed = uiImage.jpegData(compressionQuality: 0.7) {
                        fotoPerfil = Image(uiImage: uiImage)
                        guardarFotoLocal(data: compressed)
                        await subirFoto(data: compressed)
                    }
                }
            }
            .overlay {
                if subiendoFoto {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 72, height: 72)
                        .background(.black.opacity(0.4), in: Circle())
                }
            }

            Text(displayName.isEmpty ? "Usuario" : displayName)
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: Persistencia foto

    private func guardarFotoLocal(data: Data) {
        try? data.write(to: fotoURL())
    }

    private func subirFoto(data: Data) async {
        print("[Avatar] iniciando upload, perfilId=\(String(describing: auth.perfilId))")
        guard let userId = auth.perfilId else {
            print("[Avatar] perfilId nil — abortando")
            return
        }
        subiendoFoto = true
        defer { subiendoFoto = false }
        do {
            let client = SupabaseService.shared.client
            let path = "\(userId.uuidString.lowercased()).jpg"
            print("[Avatar] subiendo a avatars/\(path)")
            try await client.storage
                .from("avatars")
                .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
            let publicUrl = try client.storage.from("avatars").getPublicURL(path: path)
            print("[Avatar] url pública: \(publicUrl.absoluteString)")
            try await client
                .from("perfiles")
                .update(["avatar_url": publicUrl.absoluteString])
                .eq("id", value: userId.uuidString)
                .execute()
            auth.avatarUrl = publicUrl.absoluteString
            NotificationCenter.default.post(name: .avatarActualizado, object: nil)
            print("[Avatar] avatar_url guardado en DB")
        } catch {
            print("[Avatar] error: \(error)")
        }
    }

    private func cargarFoto() {
        let localUrl = fotoURL()
        let remoteUrlStr = auth.avatarUrl ?? ""

        // URL no cambió → usar caché local directamente, sin red
        if remoteUrlStr == avatarUrlCached,
           let data = try? Data(contentsOf: localUrl),
           let uiImage = UIImage(data: data) {
            fotoPerfil = Image(uiImage: uiImage)
            return
        }

        // URL cambió o no hay caché → descargar
        if let url = URL(string: remoteUrlStr), !remoteUrlStr.isEmpty {
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let uiImage = UIImage(data: data) {
                    fotoPerfil = Image(uiImage: uiImage)
                    try? data.write(to: localUrl)
                    avatarUrlCached = remoteUrlStr
                }
            }
            return
        }

        // Sin URL remota → archivo local si existe
        if let data = try? Data(contentsOf: localUrl),
           let uiImage = UIImage(data: data) {
            fotoPerfil = Image(uiImage: uiImage)
        }
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

    private func fotoURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("perfil.jpg")
    }
}
