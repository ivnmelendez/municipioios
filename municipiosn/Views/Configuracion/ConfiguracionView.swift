import SwiftUI
import PhotosUI
import UIKit

struct ConfiguracionView: View {
    @AppStorage("notificacionesHabilitadas") private var notificaciones = true
    @State private var photoItem: PhotosPickerItem?
    @State private var fotoPerfil: Image?
    @State private var confirmarCerrarSesion = false
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var auth

    var body: some View {
        let initiales = auth.initiales
        return ScrollView {
            VStack(spacing: 0) {

                // MARK: Header de perfil
                VStack(spacing: 14) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            Group {
                                if let foto = fotoPerfil {
                                    foto
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 90, height: 90)
                                        .clipShape(Circle())
                                } else {
                                    Text(initiales.isEmpty ? "?" : initiales)
                                        .font(.system(size: 30, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color("Navy"))
                                        .frame(width: 90, height: 90)
                                        .background(.regularMaterial, in: Circle())
                                }
                            }

                            Image(systemName: "camera.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(Color("MunicipioCyan"), in: Circle())
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

                    VStack(spacing: 3) {
                        Text(auth.displayName.isEmpty ? "Usuario" : auth.displayName)
                            .font(.title2.bold())
                            .foregroundStyle(Color("Navy"))
                        Text("San Nicolás de los Garza, NL")
                            .font(.caption)
                            .foregroundStyle(Color("TextMuted"))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 32)
                .padding(.bottom, 28)

                // MARK: Sección preferencias
                VStack(spacing: 1) {
                    configuracionRow {
                        Toggle(isOn: $notificaciones) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Notificaciones")
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text("Intervenciones, daños y rondín del sábado")
                                        .font(.caption)
                                        .foregroundStyle(Color("TextMuted"))
                                }
                            } icon: {
                                Image(systemName: "bell.badge.fill")
                                    .foregroundStyle(Color("MunicipioCyan"))
                            }
                        }
                        .tint(Color("MunicipioCyan"))
                        .onChange(of: notificaciones) { _, habilitadas in
                            if habilitadas {
                                RealtimeService.shared.programarNotificacionSabado()
                            } else {
                                RealtimeService.shared.cancelarNotificacionSabado()
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                // MARK: Probar notificación (debug)
                #if DEBUG
                configuracionRow {
                    Button {
                        probarNotificacion()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Probar notificación de rondín")
                                    .font(.body.weight(.medium))
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
                .padding(.horizontal, 20)
                .padding(.top, 12)
                #endif

                // MARK: Cerrar sesión
                Button {
                    confirmarCerrarSesion = true
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.body.weight(.medium))
                        Text("Cerrar sesión")
                            .font(.body.weight(.medium))
                    }
                    .foregroundStyle(Color(red: 0.86, green: 0.2, blue: 0.2))
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 24)

                // MARK: Info de app
                VStack(spacing: 4) {
                    Text("Municipios SN")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color("TextMuted"))
                    Text("Versión 1.0 · San Nicolás de los Garza, NL")
                        .font(.caption2)
                        .foregroundStyle(Color("TextMuted").opacity(0.6))
                }
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
        }
        .background(Color("Background"))
        .onAppear { cargarFoto() }
        .confirmationDialog("¿Cerrar sesión?", isPresented: $confirmarCerrarSesion, titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) {
                Task { await auth.signOut() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se cerrará tu sesión en este dispositivo.")
        }
    }

    // MARK: Row helper
    @ViewBuilder
    private func configuracionRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Persistencia de foto
    private func guardarFoto(data: Data) {
        let url = fotoURL()
        try? data.write(to: url)
    }

    private func cargarFoto() {
        let url = fotoURL()
        guard let data = try? Data(contentsOf: url),
              let uiImage = UIImage(data: data) else { return }
        fotoPerfil = Image(uiImage: uiImage)
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
