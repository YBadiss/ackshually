import XCTest
import SwiftUI
import AckshuallyCore
@testable import Ackshually

/// "Add N Rulebooks" (S14) and My Games' Edit mode, hosted in-process from the preview fixtures.
@MainActor
final class AddRulebooksLayoutTests: XCTestCase {
    private static let phone = CGSize(width: 402, height: 874)
    private var host: HostedView?

    override func tearDown() async throws { host?.close(); host = nil }

    private func hosted(size: CGSize = phone, typeSize: DynamicTypeSize = .large,
                        @ViewBuilder _ content: () -> some View) async -> HostedView {
        host?.close()
        let h = HostedView(size: size, typeSize: typeSize, safeArea: true, content)
        host = h
        await h.settle()
        return h
    }

    /// Every book of a suggested batch is on screen inside its width, with its role menu (not the skipped one),
    /// the group badges and Add; at the largest text size rows still fit the width.
    func testSuggestedBatchShowsGroupsRolesAndAdd() async throws {
        let c = AddRulebooksFixtures.suggested
        for size in [DynamicTypeSize.large, .accessibility5] {
            let h = await hosted(typeSize: size) { AddRulebooksFixtures.sheet(c) }
            XCTAssertNotNil(h.frame("addRulebooksConfirm"), "Add (\(size))")
            for b in c.batch.groups.flatMap(\.books) + c.batch.skipped {
                guard let f = h.frame("review-\(b.fileName)") else {
                    XCTAssertEqual(size, .accessibility5, "\(b.title) missing at \(size)")  // scrolled below at AX5
                    continue
                }
                XCTAssertLessThanOrEqual(f.maxX, h.window.bounds.width + 0.5, "\(b.title) runs off screen at \(size)")
                XCTAssertGreaterThanOrEqual(f.minX, -0.5)
            }
        }
        let h = await hosted { AddRulebooksFixtures.sheet(c) }
        XCTAssertNotNil(h.frame("role-woodland-rivers.pdf"))
        XCTAssertNil(h.frame("role-score-pad.pdf"), "skipped files have no role")
        XCTAssertTrue(h.elements.contains { $0.label.contains("New game") })
        XCTAssertTrue(h.elements.contains { $0.label.contains("In My Games") })
        XCTAssertTrue(h.elements.contains { $0.label == "Add 5 Rulebooks" })
        XCTAssertTrue(h.elements.contains { $0.label == c.note }, "the note under the groups")
    }

    func testSortingHasNoNoteAndUnsortedSaysSortYourself() async throws {
        var h = await hosted { AddRulebooksFixtures.sheet(AddRulebooksFixtures.sorting) }
        XCTAssertNil(AddRulebooksFixtures.sorting.note)
        XCTAssertTrue(h.elements.contains { $0.value == "Sorting" })
        XCTAssertFalse(AddRulebooksFixtures.sorting.canAdd, "Add waits for the groups")
        h = await hosted(size: CGSize(width: Self.phone.width, height: 1800)) { AddRulebooksFixtures.sheet(AddRulebooksFixtures.unsorted) }
        XCTAssertTrue(h.elements.contains { $0.label.hasPrefix("Sort these yourself") })
        XCTAssertEqual(AddRulebooksFixtures.unsorted.batch.groups.count, AddRulebooksFixtures.files.count, "one game per file")
    }
}
