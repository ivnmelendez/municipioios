import SwiftUI

struct FotoAsyncImage: View {
    let url: String?
    var aspectRatio: CGFloat = 4/3
    var cornerRadius: CGFloat = 12
    var thumbnail: Bool = true

    private var resolvedURL: URL? {
        guard let urlStr = url else { return nil }
        return thumbnail ? supabaseThumb(urlStr, width: 600, quality: 70)
                         : supabaseThumb(urlStr, width: 1400, quality: 85)
    }

    var body: some View {
        Group {
            if let imageURL = resolvedURL {
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

    private func supabaseThumb(_ urlString: String, width: Int, quality: Int) -> URL? {
        guard urlString.contains("/storage/v1/object/public/") else {
            return URL(string: urlString)
        }
        let transformed = urlString.replacingOccurrences(
            of: "/storage/v1/object/public/",
            with: "/storage/v1/render/image/public/"
        )
        guard var components = URLComponents(string: transformed) else {
            return URL(string: urlString)
        }
        components.queryItems = [
            URLQueryItem(name: "width", value: "\(width)"),
            URLQueryItem(name: "quality", value: "\(quality)")
        ]
        return components.url
    }
}
