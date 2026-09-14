import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 16.1, *)
struct CampoActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var ultimaActualizacion: Date
        var activo: Bool
    }
    let nombre: String
    let inicial: String
}

private let workerGreen = Color(red: 0.086, green: 0.627, blue: 0.522)

struct CampoLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CampoActivityAttributes.self) { context in
            // Lock screen / banner
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(workerGreen)
                            .frame(width: 40, height: 40)
                            .overlay {
                                Text(context.attributes.inicial)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.attributes.nombre)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("En campo")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(workerGreen)
                                .frame(width: 8, height: 8)
                            Text("En vivo")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(workerGreen)
                        }
                        Text(context.state.ultimaActualizacion, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .foregroundStyle(workerGreen)
                        Text("Ubicación actualizada \(context.state.ultimaActualizacion, style: .relative)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Circle()
                        .fill(workerGreen)
                        .frame(width: 8, height: 8)
                    Text(context.attributes.inicial)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
            } compactTrailing: {
                Text(context.state.ultimaActualizacion, style: .timer)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: 32)
            } minimal: {
                Circle()
                    .fill(workerGreen)
                    .frame(width: 12, height: 12)
                    .overlay {
                        Text(context.attributes.inicial)
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white)
                    }
            }
            .keylineTint(workerGreen)
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<CampoActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(workerGreen)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text(context.attributes.inicial)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                    }
                Circle()
                    .fill(Color(red: 0.18, green: 0.8, blue: 0.44))
                    .frame(width: 12, height: 12)
                    .overlay { Circle().stroke(.white, lineWidth: 2) }
                    .offset(x: 2, y: -2)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(context.attributes.nombre)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                        .foregroundStyle(workerGreen)
                    Text("En campo · actualizado \(context.state.ultimaActualizacion, style: .relative)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Circle().fill(workerGreen).frame(width: 6, height: 6)
                    Text("En vivo")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(workerGreen)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .activityBackgroundTint(Color(white: 0.97))
    }
}

#Preview("Lock Screen", as: .content, using: CampoActivityAttributes(nombre: "Carlos Garza", inicial: "C")) {
    CampoLiveActivityLiveActivity()
} contentStates: {
    CampoActivityAttributes.ContentState(ultimaActualizacion: .now, activo: true)
}

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: CampoActivityAttributes(nombre: "Carlos Garza", inicial: "C")) {
    CampoLiveActivityLiveActivity()
} contentStates: {
    CampoActivityAttributes.ContentState(ultimaActualizacion: .now, activo: true)
}

#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: CampoActivityAttributes(nombre: "Carlos Garza", inicial: "C")) {
    CampoLiveActivityLiveActivity()
} contentStates: {
    CampoActivityAttributes.ContentState(ultimaActualizacion: .now, activo: true)
}
