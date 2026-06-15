import SwiftUI
import PhotosUI

struct FotoCapturaView: View {
    @Binding var imagen: UIImage?
    var altura: CGFloat = 220

    @State private var mostrarCamara = false
    @State private var mostrarFototeca = false
    @State private var fotoItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 12) {
            // Preview
            if let img = imagen {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: altura)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .frame(maxWidth: .infinity)
                    .frame(height: altura)
                    .overlay {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 44))
                            .foregroundStyle(Color("Navy").opacity(0.3))
                    }
            }

            // Buttons
            HStack(spacing: 10) {
                fotoButton(
                    icono: "camera.fill",
                    titulo: imagen == nil ? "Cámara" : "Repetir con cámara"
                ) {
                    mostrarCamara = true
                }

                fotoButton(
                    icono: "photo.on.rectangle",
                    titulo: imagen == nil ? "Carrete" : "Cambiar del carrete"
                ) {
                    mostrarFototeca = true
                }

                if imagen != nil {
                    Button {
                        imagen = nil
                    } label: {
                        Image(systemName: "trash")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.red)
                            .frame(width: 48, height: 48)
                            .background(Color(.secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 10))
                    }
                }
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

    private func fotoButton(icono: String, titulo: String, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            HStack(spacing: 8) {
                Image(systemName: icono)
                    .font(.body.weight(.medium))
                Text(titulo)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(Color("Navy"))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Camera picker

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
            if let img = info[.originalImage] as? UIImage { parent.onCaptura(img) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Compression

extension UIImage {
    func preparadaParaSubir(maxDimension: CGFloat = 1600) -> UIImage {
        let escala = maxDimension / max(size.width, size.height)
        let base: UIImage
        if escala < 1 {
            let s = CGSize(width: (size.width * escala).rounded(),
                           height: (size.height * escala).rounded())
            base = UIGraphicsImageRenderer(size: s).image { _ in
                draw(in: CGRect(origin: .zero, size: s))
            }
        } else {
            base = self
        }
        guard let data = base.jpegData(compressionQuality: 0.75),
              let result = UIImage(data: data) else { return base }
        return result
    }
}
