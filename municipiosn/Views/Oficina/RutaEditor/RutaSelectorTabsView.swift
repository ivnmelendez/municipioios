import SwiftUI

struct RutaSelectorTabsView: View {
    let semanas: [RutaSemana]
    @Binding var selectedIndex: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(semanas.enumerated()), id: \.offset) { i, semana in
                let isSelected = i == selectedIndex
                Button {
                    selectedIndex = i
                    HapticService.seleccion()
                } label: {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color(hex: semana.color))
                            .frame(width: 8, height: 8)
                        Text("Ruta \(semana.numero)")
                            .font(.caption.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? .primary : .secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.glass(.regular))
                .buttonBorderShape(.capsule)
                .overlay(
                    Capsule()
                        .strokeBorder(Color("Navy").opacity(isSelected ? 0.65 : 0), lineWidth: 1.5)
                )
                .animation(.spring(duration: 0.25), value: selectedIndex)
            }
        }
    }
}
