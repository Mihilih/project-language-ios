import SwiftUI
import UIKit

/**
 * Profile photos are small JPEGs stored base64 in the `photo` field of the public users/{uid}
 * doc (no Firebase Storage needed). This caches them for the session so each person's photo is
 * read and decoded once (UserPhotos.kt).
 */
@MainActor
final class UserPhotos: ObservableObject {
    static let shared = UserPhotos()

    private nonisolated static let sidePx: CGFloat = 256
    /** Keep well under the Firestore rule's 60,000-character limit. */
    private nonisolated static let maxBase64Chars = 45_000

    @Published private var photos: [String: UIImage] = [:]
    private var requested = Set<String>()

    func photo(_ uid: String?) -> UIImage? { uid.flatMap { photos[$0] } }

    /** Reads users/{uid}.photo once per session. */
    func ensureLoaded(_ uid: String) {
        if uid.isBlank || requested.contains(uid) { return }
        requested.insert(uid)
        Backend.db.collection("users").document(uid).getDocument { [weak self] doc, error in
            Task { @MainActor in
                guard let self else { return }
                if error != nil {
                    self.requested.remove(uid)
                    return
                }
                if let photo = doc?.data()?.string("photo") { self.set(uid, photo) }
            }
        }
    }

    /** Updates the cache right away after the user changes (or removes) their own photo. */
    func set(_ uid: String, _ base64: String?) {
        if let image = base64.flatMap(Self.decode) {
            photos[uid] = image
        } else {
            photos.removeValue(forKey: uid)
        }
    }

    nonisolated static func decode(_ base64: String) -> UIImage? {
        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else { return nil }
        return UIImage(data: data)
    }

    /** Center-crops the picked image to a 256px square JPEG and returns it as base64. */
    nonisolated static func encode(_ data: Data) -> String? {
        guard let source = UIImage(data: data) else { return nil }
        // Draw the centre square at 256×256 px (orientation is applied by UIImage drawing).
        let size = source.size
        let side = min(size.width, size.height)
        guard side > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let scale = sidePx / side
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: sidePx, height: sidePx), format: format)
        let square = renderer.image { _ in
            let drawSize = CGSize(width: size.width * scale, height: size.height * scale)
            source.draw(in: CGRect(
                x: (sidePx - drawSize.width) / 2,
                y: (sidePx - drawSize.height) / 2,
                width: drawSize.width,
                height: drawSize.height
            ))
        }
        var quality: CGFloat = 0.85
        var out = ""
        repeat {
            out = square.jpegData(compressionQuality: quality)?.base64EncodedString() ?? ""
            quality -= 0.10
        } while out.count > maxBase64Chars && quality >= 0.35
        return (!out.isEmpty && out.count <= maxBase64Chars) ? out : nil
    }
}

/**
 * Round avatar: the person's photo if they have one, otherwise their initial on `background`.
 * Pass `uid` to load someone's photo; `photo` overrides it.
 */
struct UserAvatar: View {
    let name: String
    let size: CGFloat
    let background: Color
    let initialColor: Color
    var uid: String? = nil
    var photo: UIImage? = nil

    @ObservedObject private var photos = UserPhotos.shared

    var body: some View {
        let image = photo ?? photos.photo(uid)
        ZStack {
            Circle().fill(background)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
            } else {
                Text(name.initial)
                    .font(AppFont.poppins(size * 0.42))
                    .foregroundStyle(initialColor)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
        .task(id: uid) {
            if let uid { photos.ensureLoaded(uid) }
        }
    }
}
