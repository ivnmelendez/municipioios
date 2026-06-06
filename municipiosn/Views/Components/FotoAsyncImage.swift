import SwiftUI

struct FotoAsyncImage: View {
    let url: String?
    var aspectRatio: CGFloat = 4/3
    var cornerRadius: CGFloat = 12

    var body: some View {
        Group {
            if let urlStr = url, let imageURL = URL(string: urlStr) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholderView
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color("Background"))
                    @unknown default:
                        placeholderView
                    }
                }
            } else {
                placeholderView
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var placeholderView: some View {
        ZStack {
            Color("Background")
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundStyle(Color("TextMuted"))
        }
    }
}
