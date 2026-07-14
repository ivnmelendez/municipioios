import SwiftUI

struct RutaSeleccionView: View {
    var vm: CampoViewModel
    let userId: UUID?

    @State private var rutaNavegando: RutaSemana?

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoadingRutas {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(vm.rutasInfo) { info in
                                rutaCard(info: info)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Rutas de campo")
            .navigationBarTitleDisplayMode(.large)
            .background(Color("Background"))
        }
        .fullScreenCover(item: $rutaNavegando) { ruta in
            RutaNavegacionView(
                ruta: ruta,
                userId: userId,
                campanas: vm.campanas,
                onTerminar: {
                    rutaNavegando = nil
                    Task { await vm.cargarRutas(userId: userId) }
                },
                todasLasRutas: vm.rutasInfo.map(\.ruta)
            )
        }
        .task { await vm.cargarRutas(userId: userId) }
    }

    private func rutaCard(info: RutaInfo) -> some View {
        let color = Color(hex: info.ruta.color)
        let terminada = info.visitadas == info.total && info.total > 0

        return Button {
            rutaNavegando = info.ruta
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 52, height: 52)
                    if terminada {
                        Image(systemName: "checkmark")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                    } else {
                        Text("\(info.ruta.numero)")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Ruta \(info.ruta.numero)")
                            .font(.headline)
                        if terminada {
                            Text("Completada")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.green, in: Capsule())
                        }
                    }
                    Text("\(info.visitadas) de \(info.total) estructuras visitadas")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ProgressView(value: info.progreso)
                        .tint(color)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(18)
            .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
