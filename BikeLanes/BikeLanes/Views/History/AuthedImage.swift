// BikeLanes/Views/History/AuthedImage.swift
import SwiftUI

/// SwiftUI's `AsyncImage` can't attach an Authorization header, so we roll our
/// own: fetch the bytes with URLSession + Bearer, decode, display. Used for
/// the Denver case thumbnail endpoint which requires a signed-in id_token.
struct AuthedImage: View {
    let url: URL
    let auth: AuthService

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else if failed {
                placeholder(text: "Thumbnail unavailable")
            } else {
                ZStack {
                    placeholder(text: "")
                    ProgressView()
                }
            }
        }
        .task(id: url) { await load() }
    }

    private func placeholder(text: String) -> some View {
        ZStack {
            Rectangle().fill(Color(red: 239/255, green: 236/255, blue: 226/255))
            if !text.isEmpty {
                Text(text).font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
    }

    private func load() async {
        do {
            guard let token = try await auth.currentIdToken(), !token.isEmpty else {
                failed = true; return
            }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
            req.setValue("https://www.denvergov.org", forHTTPHeaderField: "Origin")
            req.setValue("https://www.denvergov.org/", forHTTPHeaderField: "Referer")
            let (data, response) = try await URLSession.shared.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard (200...299).contains(status), let img = UIImage(data: data) else {
                failed = true; return
            }
            image = img
        } catch {
            failed = true
        }
    }
}
