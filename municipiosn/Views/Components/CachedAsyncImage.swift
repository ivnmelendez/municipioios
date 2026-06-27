import SwiftUI

/// Drop-in replacement for AsyncImage that enforces disk caching via URLCache.
/// AsyncImage(url:) ignores URLCache when Supabase responds with no-cache headers.
struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    @ViewBuilder let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase = .empty

    var body: some View {
        content(phase)
            .onAppear { load() }
    }

    private func load() {
        guard case .empty = phase, let url else { return }
        Task {
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
            if let (data, _) = try? await URLSession.shared.data(for: request),
               let uiImage = UIImage(data: data) {
                phase = .success(Image(uiImage: uiImage))
            } else {
                phase = .failure(URLError(.badServerResponse))
            }
        }
    }
}
