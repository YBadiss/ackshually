import UIKit
import PDFKit

/// Covers for My Games: the first page of each rulebook, rendered off the main thread and kept
/// in memory and in Caches (keyed by file, modification date and pixel width, so a re-imported
/// file gets a new cover).
actor CoverCache {
    static let shared = CoverCache()

    private let memory = NSCache<NSString, UIImage>()
    private let folder: URL = {
        let u = URL.cachesDirectory.appending(path: "Covers", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }()

    /// A cover `pixelWidth` pixels wide (scale 1: the caller wraps it at its display scale).
    func cover(for url: URL, pixelWidth: Int) -> UIImage? {
        guard pixelWidth > 0, let key = key(for: url, pixelWidth: pixelWidth) else { return nil }
        if let img = memory.object(forKey: key as NSString) { return img }
        let file = folder.appending(path: key + ".png")
        if let data = try? Data(contentsOf: file), let img = UIImage(data: data) {
            memory.setObject(img, forKey: key as NSString)
            return img
        }
        guard let img = Self.render(url, pixelWidth: pixelWidth) else { return nil }
        memory.setObject(img, forKey: key as NSString)
        try? img.pngData()?.write(to: file, options: .atomic)
        return img
    }

    /// Drops every cached size of a deleted game.
    func remove(fileName: String) {
        memory.removeAllObjects()
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for f in files where f.lastPathComponent.hasPrefix(Self.safe(fileName) + "-") { try? FileManager.default.removeItem(at: f) }
    }

    private func key(for url: URL, pixelWidth: Int) -> String? {
        guard let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate else { return nil }
        return "\(Self.safe(url.lastPathComponent))-\(Int(modified.timeIntervalSince1970))-\(pixelWidth)"
    }

    private static func safe(_ name: String) -> String {
        name.replacingOccurrences(of: "/", with: "_")
    }

    private static func render(_ url: URL, pixelWidth: Int) -> UIImage? {
        guard let page = PDFDocument(url: url)?.page(at: 0) else { return nil }
        let bounds = page.bounds(for: .cropBox)
        guard bounds.width > 0 else { return nil }
        let rotated = page.rotation % 180 != 0
        let aspect = rotated ? bounds.width / bounds.height : bounds.height / bounds.width
        let size = CGSize(width: CGFloat(pixelWidth), height: (CGFloat(pixelWidth) * aspect).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let cg = ctx.cgContext
            // PDF space is bottom-up; `transform(for:)` maps the crop box (and its rotation) to it.
            cg.translateBy(x: 0, y: size.height)
            cg.scaleBy(x: size.width / (rotated ? bounds.height : bounds.width), y: -size.height / (rotated ? bounds.width : bounds.height))
            page.draw(with: .cropBox, to: cg)
        }
    }
}
