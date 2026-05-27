import UIKit

enum DictionaryImageStorage {
    static let imagesDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = base
            .appendingPathComponent("images", isDirectory: true)
            .appendingPathComponent("dictionary", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()

    static func imageURL(for cardID: UUID) -> URL {
        imagesDirectory.appendingPathComponent("\(cardID.uuidString).jpg")
    }

    static func imageExists(for cardID: UUID) -> Bool {
        FileManager.default.fileExists(atPath: imageURL(for: cardID).path)
    }

    static func loadImage(for cardID: UUID) -> UIImage? {
        let url = imageURL(for: cardID)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    static func saveImage(_ image: UIImage, for cardID: UUID) throws {
        let resized = resize(image, maxSide: 512)
        guard let data = resized.jpegData(compressionQuality: 0.82) else { return }
        let url = imageURL(for: cardID)
        try data.write(to: url, options: .atomic)
    }

    static func deleteImage(for cardID: UUID) {
        let url = imageURL(for: cardID)
        try? FileManager.default.removeItem(at: url)
    }

    private static func resize(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > maxSide || size.height > maxSide else { return image }
        let scale = min(maxSide / size.width, maxSide / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
