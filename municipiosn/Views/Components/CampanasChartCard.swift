import SwiftUI

struct CampanasChartCard: View {
    let datos: [UsoCampana]
    @State private var mostrarTodo = false

    private var top: [UsoCampana] { Array(datos.prefix(5)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Campañas en uso", systemImage: "megaphone.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("MunicipioCyan"))
                Spacer()
                if datos.count > 5 {
                    Button {
                        mostrarTodo = true
                    } label: {
                        HStack(spacing: 3) {
                            Text("Ver todas")
                            Image(systemName: "chevron.right")
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color("MunicipioCyan"))
                    }
                }
            }

            if top.isEmpty {
                Text("Sin campañas activas")
                    .font(.body)
                    .foregroundStyle(Color("TextMuted"))
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(top.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color("TextMuted"))
                                .frame(width: 20, alignment: .center)
                            Text(item.nombre)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer()
                            Text("\(item.totalCaras) caras")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color("MunicipioCyan"))
                                .monospacedDigit()
                        }
                        .padding(.vertical, 11)
                        if index < top.count - 1 {
                            Divider().padding(.leading, 32)
                        }
                    }
                }
            }
        }
        .padding(20)
        .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .sheet(isPresented: $mostrarTodo) {
            CampanasListaCompleta(datos: datos)
        }
    }
}

private struct CampanasListaCompleta: View {
    let datos: [UsoCampana]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(datos.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color("TextMuted"))
                            .frame(width: 28, alignment: .center)
                        Text(item.nombre)
                            .font(.body)
                        Spacer()
                        Text("\(item.totalCaras) caras")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color("MunicipioCyan"))
                            .monospacedDigit()
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Campañas en uso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }
}
