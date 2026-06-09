import SwiftUI

struct RutasTabView: View {
    let userId: UUID?
    let campanas: [CampanaBasica]

    @State private var semanas: [RutaSemana] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Cargando rutas...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if semanas.isEmpty {
                    ContentUnavailableView {
                        Label("Sin rutas", systemImage: "route")
                    } description: {
                        Text("No hay rutas generadas aún.")
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(semanas) { semana in
                                NavigationLink {
                                    RutaDetalleView(
                                        semana: semana,
                                        userId: userId,
                                        campanas: campanas
                                    )
                                } label: {
                                    SemanaCard(semana: semana)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Rutas")
            .navigationBarTitleDisplayMode(.large)
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .task { await cargar() }
    }

    private func cargar() async {
        isLoading = true
        defer { isLoading = false }
        do {
            semanas = try await RutasService.shared.fetchSemanasRecientes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - SemanaCard

private struct SemanaCard: View {
    let semana: RutaSemana

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: semana.color))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "route")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                Text("Semana \(semana.numero)")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            .padding(20)
        }
        .frame(height: 140)
        .shadow(color: Color(hex: semana.color).opacity(0.4), radius: 8, y: 4)
    }
}
