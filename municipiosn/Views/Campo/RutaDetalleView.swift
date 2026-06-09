import SwiftUI
import MapKit
import UIKit

struct RutaDetalleView: View {
    let semana: RutaSemana
    let userId: UUID?
    let campanas: [CampanaBasica]

    @State private var items: [RutaEstructuraItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var estructuraAccion: RutaEstructuraItem?
    @State private var estructuraParaAccion: EstructuraConParque?
    @State private var estructuraParaDano: EstructuraConParque?
    private var visitadasCount: Int { items.filter { $0.visitada }.count }
    private var accentColor: Color { Color(hex: semana.color) }

    var body: some View {
        VStack(spacing: 0) {
            if !items.isEmpty {
                progresoHeader
            }

            Group {
                if isLoading {
                    ProgressView("Cargando estructuras...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if items.isEmpty {
                    ContentUnavailableView("Sin estructuras", systemImage: "building.2",
                        description: Text("Esta ruta no tiene estructuras asignadas."))
                } else {
                    lista
                }
            }
        }
        .navigationTitle("Semana \(semana.numero)")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(item: $estructuraAccion) { item in
            AccionSheet(
                item: item,
                accentColor: accentColor,
                onRevision: { marcarRevision(item: item) },
                onAccion: {
                    estructuraAccion = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        estructuraParaAccion = item.estructura
                    }
                },
                onDano: {
                    estructuraAccion = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        estructuraParaDano = item.estructura
                    }
                }
            )
        }
        .sheet(item: $estructuraParaAccion) { estructura in
            RegistrarCoroplastView(
                estructura: estructura,
                campanas: campanas,
                userId: userId,
                rutaSemanaId: semana.id,
                onCompletion: { marcarVisitadaLocal(estructuraId: estructura.id) }
            )
        }
        .sheet(item: $estructuraParaDano) { estructura in
            ReportarDanoView(
                estructura: estructura,
                userId: userId,
                rutaSemanaId: semana.id,
                onCompletion: { marcarVisitadaLocal(estructuraId: estructura.id) }
            )
        }
        .task { await cargar() }
    }

    // MARK: - Progreso

    private var progresoHeader: some View {
        VStack(spacing: 10) {
            HStack {
                Text("\(visitadasCount) de \(items.count) visitadas")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(Double(visitadasCount) / Double(items.count) * 100))%")
                    .font(.subheadline.bold())
                    .foregroundStyle(accentColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.2)).frame(height: 10)
                    Capsule()
                        .fill(accentColor)
                        .frame(
                            width: items.isEmpty ? 0 : geo.size.width * CGFloat(visitadasCount) / CGFloat(items.count),
                            height: 10
                        )
                        .animation(.spring(duration: 0.4), value: visitadasCount)
                }
            }
            .frame(height: 10)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Lista

    private var lista: some View {
        List {
            ForEach(items) { item in
                Button { estructuraAccion = item } label: {
                    RutaEstructuraRow(item: item, accentColor: accentColor)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color(.secondarySystemGroupedBackground))
            }
        }
        .listStyle(.insetGrouped)
    }


    // MARK: - Actions

    private func cargar() async {
        guard let userId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await RutasService.shared.fetchEstructurasEnRuta(
                rutaSemanaId: semana.id,
                userId: userId
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func marcarRevision(item: RutaEstructuraItem) {
        guard let userId else { return }
        Task {
            do {
                try await RutasService.shared.marcarRevision(
                    estructuraId: item.estructura.id,
                    rutaSemanaId: semana.id,
                    userId: userId
                )
                marcarVisitadaLocal(estructuraId: item.estructura.id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func marcarVisitadaLocal(estructuraId: UUID) {
        if let idx = items.firstIndex(where: { $0.estructura.id == estructuraId }) {
            items[idx].visitada = true
        }
    }
}

// MARK: - EstructuraRow

private struct RutaEstructuraRow: View {
    let item: RutaEstructuraItem
    let accentColor: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text("\(item.orden)")
                    .font(.headline.bold())
                    .foregroundStyle(accentColor)
            }

            estructuraFoto

            VStack(alignment: .leading, spacing: 4) {
                Text(item.estructura.numero)
                    .font(.headline)
                if let parque = item.estructura.parques {
                    Text(parque.nombre)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            EstadoBadge(estado: item.estructura.estado)

            if item.visitada {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 6)
        .opacity(item.visitada ? 0.6 : 1)
    }

    private var estructuraFoto: some View {
        Group {
            if let urlStr = item.estructura.fotoUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        fotoPlaceholder
                    }
                }
            } else {
                fotoPlaceholder
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var fotoPlaceholder: some View {
        ZStack {
            Color(.tertiarySystemGroupedBackground)
            Image(systemName: "photo")
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - AccionSheet

private struct AccionSheet: View {
    let item: RutaEstructuraItem
    let accentColor: Color
    let onRevision: () -> Void
    let onAccion: () -> Void
    let onDano: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                estructuraHeader
                    .padding(.horizontal)
                    .padding(.top, 12)

                if item.estructura.lat != nil && item.estructura.lng != nil {
                    Button(action: abrirNavegacion) {
                        Label("Cómo llegar", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }

                VStack(spacing: 14) {
                    opcionButton(
                        icono: "checkmark.circle.fill",
                        color: .green,
                        titulo: "Está bien",
                        subtitulo: "La estructura está en buen estado"
                    ) {
                        onRevision()
                        dismiss()
                    }

                    opcionButton(
                        icono: "wrench.and.screwdriver.fill",
                        color: Color("MunicipioCyan"),
                        titulo: "Registrar acción",
                        subtitulo: "Cambio o reparación de coroplast"
                    ) {
                        onAccion()
                    }

                    opcionButton(
                        icono: "exclamationmark.triangle.fill",
                        color: .orange,
                        titulo: "Reportar daño",
                        subtitulo: "Tiene daño que no puedes arreglar ahora"
                    ) {
                        onDano()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)

                Spacer()
            }
            .navigationTitle("¿Qué pasa aquí?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var estructuraHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Text("\(item.orden)")
                    .font(.subheadline.bold())
                    .foregroundStyle(accentColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.estructura.numero)
                    .font(.title3.bold())
                if let parque = item.estructura.parques {
                    Text(parque.nombre)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
            Spacer()
            EstadoBadge(estado: item.estructura.estado)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func abrirNavegacion() {
        guard let lat = item.estructura.lat, let lng = item.estructura.lng else { return }
        let googleMaps = URL(string: "comgooglemaps://?daddr=\(lat),\(lng)&directionsmode=driving")
        let appleMaps = URL(string: "maps://?daddr=\(lat),\(lng)")
        if let url = googleMaps, UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let url = appleMaps {
            UIApplication.shared.open(url)
        }
    }

    private func opcionButton(icono: String, color: Color, titulo: String, subtitulo: String, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            HStack(spacing: 16) {
                Image(systemName: icono)
                    .font(.title)
                    .foregroundStyle(color)
                    .frame(width: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(titulo)
                        .font(.headline).foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Text(subtitulo)
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.bold()).foregroundStyle(.tertiary)
            }
            .padding(18)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.25), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}
