import SwiftUI
@testable import Ackshually

/// A SwiftUI view in its own window at a fixed size, in-process (no app launch, no XCUITest runner):
/// the theme, text size and appearance are set like the app sets them, animations are off, and
/// `settle()` runs layout until geometry-driven state (shelf height, "More", detent metrics) stops
/// changing. Layout tests read element frames by accessibility identifier; snapshot tests render
/// the window.
@MainActor
final class HostedView {
    let window: UIWindow
    let controller: UIHostingController<AnyView>

    /// `safeArea: false` (default) lays the view out like sheet content: no status bar or home
    /// indicator insets from the simulator's screen.
    init(size: CGSize, typeSize: DynamicTypeSize = .large, dark: Bool = false, safeArea: Bool = false,
         sizeClass: UIUserInterfaceSizeClass? = nil, @ViewBuilder _ content: () -> some View) {
        Self.enableAccessibility
        UIView.setAnimationsEnabled(false)
        controller = UIHostingController(rootView: AnyView(content().themed().transaction { $0.disablesAnimations = true }))
        if !safeArea { controller.safeAreaRegions = [] }
        controller.traitOverrides.preferredContentSizeCategory = UIContentSizeCategory(typeSize)
        controller.traitOverrides.userInterfaceStyle = dark ? .dark : .light
        if let sizeClass { controller.traitOverrides.horizontalSizeClass = sizeClass }
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        window = scene.map(UIWindow.init(windowScene:)) ?? UIWindow()
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = controller
        window.isHidden = false
    }

    /// Runs layout passes until the hierarchy stops changing (geometry readers feed state back).
    func settle(passes: Int = 6) async {
        for _ in 0..<passes {
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
            try? await Task.sleep(for: .milliseconds(30))
        }
    }

    func close() {
        window.isHidden = true
        window.rootViewController = nil
    }

    // MARK: Frames

    /// SwiftUI only builds its accessibility tree for an assistive client. XCUITest turns this on
    /// from outside; in-process, tests turn on the same automation flag (as KIF does).
    private static let enableAccessibility: Void = {
        guard let lib = dlopen("/usr/lib/libAccessibility.dylib", RTLD_NOW),
              let sym = dlsym(lib, "_AXSSetAutomationEnabled") else { return }
        unsafeBitCast(sym, to: (@convention(c) (Int32) -> Void).self)(1)
    }()

    struct Element {
        var identifier: String
        var label: String
        var value: String
        var frame: CGRect
    }

    /// Every accessibility element under the window, depth first, with its frame in window points.
    var elements: [Element] {
        var out: [Element] = []
        var seen = Set<ObjectIdentifier>()
        func visit(_ object: NSObject) {
            guard seen.insert(ObjectIdentifier(object)).inserted else { return }
            let id = Self.identifier(of: object)
            if object.isAccessibilityElement || !id.isEmpty {
                out.append(Element(identifier: id, label: object.accessibilityLabel ?? "", value: object.accessibilityValue ?? "",
                                   frame: window.convert(object.accessibilityFrame, from: nil)))
            }
            if let children = object.accessibilityElements as? [NSObject] {
                children.forEach(visit)
            } else {
                let n = object.accessibilityElementCount()
                if n != NSNotFound, n > 0 {
                    for i in 0..<n { (object.accessibilityElement(at: i) as? NSObject).map(visit) }
                }
            }
            (object as? UIView)?.subviews.forEach(visit)
        }
        visit(window)
        return out
    }

    /// SwiftUI's elements answer `accessibilityIdentifier` without declaring the protocol.
    private static func identifier(of object: NSObject) -> String {
        let sel = NSSelectorFromString("accessibilityIdentifier")
        guard object.responds(to: sel) else { return "" }
        return object.perform(sel)?.takeUnretainedValue() as? String ?? ""
    }

    func frames(_ identifier: String) -> [CGRect] { elements.filter { $0.identifier == identifier }.map(\.frame) }

    func frame(_ identifier: String) -> CGRect? { frames(identifier).first }

    func element(_ identifier: String) -> Element? { elements.first { $0.identifier == identifier } }

    /// Settles until `condition` holds (async work such as highlight placement), up to ~3 s.
    func settle(until condition: () -> Bool) async -> Bool {
        for _ in 0..<100 {
            if condition() { return true }
            await settle(passes: 1)
        }
        return condition()
    }

    /// Waits until two renders ~150 ms apart are identical (up to ~3 s): PDFKit draws its page tiles
    /// asynchronously, sharper as they finish, so a capture right after layout can catch a blurry tile
    /// when the machine is busy (other tests just ran).
    func settleRendering() async {
        var last = image(scale: 1).pngData()
        for _ in 0..<20 {
            try? await Task.sleep(for: .milliseconds(150))
            let next = image(scale: 1).pngData()
            if next == last { return }
            last = next
        }
    }

    /// Renders the window like the screen does (materials and glass included).
    func image(scale: CGFloat? = nil) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        if let scale { format.scale = scale }
        // 8-bit sRGB: wide-colour 16-bit PNGs are 3–4× larger and the diff gains nothing.
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }
}
