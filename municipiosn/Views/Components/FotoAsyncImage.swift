import SwiftUI

struct FotoAsyncImage: View {
    let url: String?
    var aspectRatio: CGFloat = 4/3
    var cornerRadius: CGFloat = 12
    var thumbnail: Bool = true
    var thumbnailWidth: Int = 600

    @State private var uiImage: UIImage? = nil
    @State private var loadState: LoadState = .idle

    private enum LoadState { case idle, loading, failed }

    var body: some View {
        Group {
            if let img = uiImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else if loadState == .failed || url == nil || url?.isEmpty == true {
                placeholderView
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color("Background"))
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .onAppear {
            guard loadState == .idle, let urlStr = url else { return }
            loadState = .loading
            Task {
                let thumbURL = thumbnail
                    ? supabaseThumb(urlStr, width: thumbnailWidth, quality: 60)
                    : supabaseThumb(urlStr, width: 1400, quality: 85)
                let urls = [thumbURL, URL(string: urlStr)].compactMap { $0 }
                for imageURL in urls {
                    let request = URLRequest(url: imageURL, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
                    if let (data, _) = try? await URLSession.shared.data(for: request),
                       let img = UIImage(data: data) {
                        uiImage = img
                        return
                    }
                }
                loadState = .failed
            }
        }
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
