import SwiftUI
import PhotosUI

// MARK: - Shared photo capture component (camera + library, pre-compressed)

struct FotoCapturaView: View {
    @Binding var imagen: UIImage?
    var altura: CGFloat = 240
    var tint: Color = Color("Navy")

    @State private var mostrarOpciones = false
    @State private var mostrarCamara = false
    @State private var mostrarFototeca = false
    @State private var fotoItem: PhotosPickerItem?

    var body: some View {
        Button { mostrarOpciones = true } label: {
            ZStack {
                if let img = imagen {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: altura)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(alignment: .bottomTrailing) {
                            Label("Cambiar", systemImage: "camera.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.45), in: Capsule())
                                .padding(12)
                        }
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .frame(maxWidth: .infinity)
                        .frame(height: altura)
                        .overlay {
                            VStack(spacing: 12) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 38))
                                    .foregroundStyle(tint)
                                Text("Agregar foto")
                                    .font(.headline)
                                    .foregroundStyle(tint)
                                Text("Cámara o carrete")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                }
            }
        }
        .buttonStyle(.plain)
        .confirmationDialog("Agregar foto", isPresented: $mostrarOpciones, titleVisibility: .visible) {
            Button("Tomar foto con cámara") { mostrarCamara = true }
            Button("Elegir del carrete") { mostrarFototeca = true }
            if imagen != nil {
                Button("Eliminar foto", role: .destructive) { imagen = nil }
            }
        }
        .photosPicker(isPresented: $mostrarFototeca, selection: $fotoItem, matching: .images)
        .onChange(of: fotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let raw = UIImage(data: data) {
                    imagen = raw.preparadaParaSubir()
                }
                fotoItem = nil
            }
        }
        .fullScreenCover(isPresented: $mostrarCamara) {
            CameraPickerView { capturada in
                imagen = capturada.preparadaParaSubir()
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Camera UIViewControllerRepresentable

private struct CameraPickerView: UIViewControllerRepresentable {
    let onCaptura: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.onCaptura(img)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - UIImage compression

extension UIImage {
    /// Resize to max 1600px on longest side, then encode at 0.75 quality.
    /// Keeps field photos ~200–400 KB without visible quality loss.
    func preparadaParaSubir(maxDimension: CGFloat = 1600) -> UIImage {
        let escala = maxDimension / max(size.width, size.height)
        let base: UIImage
        if escala < 1 {
            let nuevoTamaño = CGSize(width: (size.width * escala).rounded(),
                                    height: (size.height * escala).rounded())
            base = UIGraphicsImageRenderer(size: nuevoTamaño).image { _ in
                draw(in: CGRect(origin: .zero, size: nuevoTamaño))
            }
        } else {
            base = self
        }
        guard let data = base.jpegData(compressionQuality: 0.75),
              let resultado = UIImage(data: data) else { return base }
        return resultado
    }
}
