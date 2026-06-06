import SwiftUI

struct ConfiguracionView: View {
    @AppStorage("notificacionesHabilitadas") private var notificacionesHabilitadas = true

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Configuración")
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color("Navy"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

                Toggle(isOn: $notificacionesHabilitadas) {
                    HStack(spacing: 14) {
                        Image(systemName: "bell.badge.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color("MunicipioCyan"))
                            .frame(width: 44, height: 44)
                            .background(Color("MunicipioCyan").opacity(0.14), in: Circle())

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Notificaciones de cambios")
                                .font(.body.weight(.medium))
                                .foregroundStyle(Color("Navy"))
                            Text("Alertas en tiempo real de cambios de rotoplas")
                                .font(.caption)
                                .foregroundStyle(Color("TextMuted"))
                        }
                    }
                }
                .tint(Color("MunicipioCyan"))
                .padding(18)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 24)
        }
        .background(Color("Background"))
    }
}
