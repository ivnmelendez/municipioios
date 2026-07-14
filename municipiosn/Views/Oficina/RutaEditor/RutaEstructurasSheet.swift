import SwiftUI
import CoreLocation

struct RutaEstructurasSheet: View {
    @Bindable var vm: RutaEditorViewModel
    @Binding var modoEdicion: Bool
    let onCenterMap: (CLLocationCoordinate2D) -> Void

    var body: some View {
        VStack(spacing: 0) {
            handle
            header
            Divider()
            if vm.itemsActivos.isEmpty {
                emptyState
            } else {
                lista
            }
        }
        .frame(height: modoEdicion ? 420 : 300)
        .background(
            .regularMaterial,
            in: UnevenRoundedRectangle(
                topLeadingRadius: 20, bottomLeadingRadius: modoEdicion ? 0 : 20,
                bottomTrailingRadius: modoEdicion ? 0 : 20, topTrailingRadius: 20
            )
        )
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: -4)
        .padding(.horizontal, modoEdicion ? 0 : 12)
        .padding(.bottom, modoEdicion ? 0 : 8)
        .ignoresSafeArea(.container, edges: modoEdicion ? .bottom : [])
        .animation(.spring(duration: 0.3), value: modoEdicion)
    }

    // MARK: - Subviews

    private var handle: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.4))
            .frame(width: 36, height: 4)
            .padding(.top, 10)
            .padding(.bottom, 6)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Ruta \(vm.rutaActiva?.numero ?? 0)")
                    .font(.headline)
                Text("\(vm.itemsActivos.count) paradas")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if vm.guardando {
                ProgressView()
                    .scaleEffect(0.85)
                    .transition(.opacity)
            }
            if modoEdicion {
                Button {
                    Task { await vm.exportarPDF() }
                } label: {
                    Image(systemName: "printer")
                        .foregroundStyle(Color("Navy"))
                }
                .buttonStyle(.glass(.regular))
                .buttonBorderShape(.circle)
                .controlSize(.small)
                .disabled(vm.itemsActivos.isEmpty)

                Button {
                    withAnimation(.spring(duration: 0.25)) { modoEdicion = false }
                    HapticService.impacto(.light)
                } label: {
                    Text("Listo")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color("Navy"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glass(.regular))
                .buttonBorderShape(.capsule)
            } else {
                Button {
                    withAnimation(.spring(duration: 0.25)) { modoEdicion = true }
                    HapticService.impacto(.light)
                } label: {
                    Label("Editar", systemImage: "pencil")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color("Navy"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glass(.regular))
                .buttonBorderShape(.capsule)
                .disabled(vm.itemsActivos.isEmpty && vm.semanas.isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "mappin.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Toca un pin gris en el mapa para agregar paradas")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var lista: some View {
        List {
            ForEach(Array(vm.itemsActivos.enumerated()), id: \.element.id) { i, item in
                StopRow(numero: i + 1, item: item, modoEdicion: modoEdicion)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !modoEdicion,
                              let lat = item.estructura.lat,
                              let lng = item.estructura.lng else { return }
                        onCenterMap(CLLocationCoordinate2D(latitude: lat, longitude: lng))
                        HapticService.seleccion()
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .onMove { from, to in
                vm.moverEnRuta(from: from, to: to)
            }
            .onDelete { offsets in
                vm.eliminarDeRuta(at: offsets)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(modoEdicion ? .active : .inactive))
    }
}

// MARK: - Stop row

private struct StopRow: View {
    let numero: Int
    let item: RutaEditorItem
    let modoEdicion: Bool

    private var subtitulo: String {
        [item.estructura.parques?.colonias?.nombre, item.estructura.parques?.nombre]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", numero))
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.estructura.numero)
                    .font(.subheadline.weight(.semibold))
                if !subtitulo.isEmpty {
                    Text(subtitulo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()

            if !modoEdicion {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
