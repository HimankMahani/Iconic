//
//  TemplatesStoreTests.swift
//  IconicTests
//
//  Tests for TemplatesStore CRUD operations and IconTemplate encoding fidelity.
//  TemplatesStore is @MainActor; every test runs on MainActor via MainActor.run.
//

import XCTest
@testable import Iconic

@MainActor
final class TemplatesStoreTests: XCTestCase {

    private let defaults = UserDefaults.standard
    private let key = "iconic.templates.v1"

    override func setUp() {
        super.setUp()
        defaults.removeObject(forKey: key)
    }

    override func tearDown() {
        defaults.removeObject(forKey: key)
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeTemplate(
        name: String = "Test Template",
        symbol: String = "star.fill"
    ) -> IconTemplate {
        IconTemplate(name: name, symbol: symbol)
    }

    // MARK: - testInitialState

    func testInitialStateIsEmpty() {
        let store = TemplatesStore()
        XCTAssertTrue(store.templates.isEmpty, "New store should start with zero templates")
    }

    func testInitialStateLoadsExistingDefaults() {
        // Seed UserDefaults with a template, then init the store.
        let seed = [IconTemplate(name: "Seed", symbol: "leaf.fill")]
        if let data = try? JSONEncoder().encode(seed) {
            defaults.set(data, forKey: key)
        }

        let store = TemplatesStore()
        XCTAssertEqual(store.templates.count, 1)
        XCTAssertEqual(store.templates.first?.name, "Seed")
        XCTAssertEqual(store.templates.first?.symbol, "leaf.fill")
    }

    // MARK: - testAddCustomTemplate

    func testAddCustomTemplate() {
        let store = TemplatesStore()
        let template = makeTemplate(name: "My Template", symbol: "heart.fill")

        store.add(template)

        XCTAssertEqual(store.templates.count, 1)
        XCTAssertEqual(store.templates.first?.name, "My Template")
        XCTAssertEqual(store.templates.first?.symbol, "heart.fill")
    }

    func testAddMultipleTemplates() {
        let store = TemplatesStore()
        store.add(makeTemplate(name: "T1", symbol: "star.fill"))
        store.add(makeTemplate(name: "T2", symbol: "cloud.fill"))
        store.add(makeTemplate(name: "T3", symbol: "moon.fill"))

        XCTAssertEqual(store.templates.count, 3)
        XCTAssertEqual(store.templates[0].name, "T1")
        XCTAssertEqual(store.templates[1].name, "T2")
        XCTAssertEqual(store.templates[2].name, "T3")
    }

    func testAddTemplateWithColors() {
        let store = TemplatesStore()
        var template = makeTemplate()
        template.symbolColorHex = "#FF0000"
        template.folderColorHex = "#00FF00"
        template.symbolGradientEndHex = "#0000FF"

        store.add(template)

        let stored = store.templates.first!
        XCTAssertEqual(stored.symbolColorHex, "#FF0000")
        XCTAssertEqual(stored.folderColorHex, "#00FF00")
        XCTAssertEqual(stored.symbolGradientEndHex, "#0000FF")
    }

    func testAddTemplateWithAdjustments() {
        let store = TemplatesStore()
        var template = makeTemplate()
        template.symbolOpacity = 0.5
        template.symbolScale = 1.5
        template.symbolOffsetY = 10.0

        store.add(template)

        let stored = store.templates.first!
        XCTAssertEqual(stored.symbolOpacity, 0.5, accuracy: 0.001)
        XCTAssertEqual(stored.symbolScale, 1.5, accuracy: 0.001)
        XCTAssertEqual(stored.symbolOffsetY, 10.0, accuracy: 0.001)
    }

    // MARK: - testDeleteCustomTemplate

    func testDeleteCustomTemplateById() {
        let store = TemplatesStore()
        let template = makeTemplate()
        store.add(template)
        XCTAssertEqual(store.templates.count, 1)

        store.remove(id: template.id)
        XCTAssertTrue(store.templates.isEmpty, "Template should be removed by id")
    }

    func testDeleteCustomTemplateByOffsets() {
        let store = TemplatesStore()
        store.add(makeTemplate(name: "A"))
        store.add(makeTemplate(name: "B"))
        store.add(makeTemplate(name: "C"))
        XCTAssertEqual(store.templates.count, 3)

        store.remove(at: IndexSet(integer: 1))
        XCTAssertEqual(store.templates.count, 2)
        XCTAssertEqual(store.templates[0].name, "A")
        XCTAssertEqual(store.templates[1].name, "C")
    }

    func testDeleteNonexistentIdDoesNothing() {
        let store = TemplatesStore()
        store.add(makeTemplate())
        store.remove(id: UUID())
        XCTAssertEqual(store.templates.count, 1, "Removing nonexistent id should be a no-op")
    }

    // MARK: - testUpdateTemplate

    func testUpdateTemplate() {
        let store = TemplatesStore()
        var template = makeTemplate(name: "Original", symbol: "star.fill")
        store.add(template)

        template.name = "Updated"
        template.symbol = "cloud.fill"
        store.update(template)

        XCTAssertEqual(store.templates.first?.name, "Updated")
        XCTAssertEqual(store.templates.first?.symbol, "cloud.fill")
    }

    func testUpdateNonexistentTemplateDoesNothing() {
        let store = TemplatesStore()
        store.add(makeTemplate(name: "Existing"))

        var phantom = makeTemplate(name: "Phantom")
        phantom.id = UUID() // different id
        store.update(phantom)

        XCTAssertEqual(store.templates.count, 1)
        XCTAssertEqual(store.templates.first?.name, "Existing")
    }

    // MARK: - testDuplicateTemplate

    func testDuplicateTemplate() {
        let store = TemplatesStore()
        let original = makeTemplate(name: "Original", symbol: "star.fill")
        store.add(original)

        // Add another template with the same name and symbol but different UUID
        let duplicate = makeTemplate(name: "Original", symbol: "star.fill")
        store.add(duplicate)

        XCTAssertEqual(store.templates.count, 2, "Store should allow duplicate names")
        XCTAssertNotEqual(store.templates[0].id, store.templates[1].id, "Each template should have a unique id")
    }

    func testDuplicateTemplateWithDifferentAdjustments() {
        let store = TemplatesStore()
        var t1 = makeTemplate(name: "Style")
        t1.symbolOpacity = 1.0
        store.add(t1)

        var t2 = makeTemplate(name: "Style")
        t2.symbolOpacity = 0.5
        store.add(t2)

        XCTAssertEqual(store.templates.count, 2)
        XCTAssertEqual(store.templates[0].symbolOpacity, 1.0, accuracy: 0.001)
        XCTAssertEqual(store.templates[1].symbolOpacity, 0.5, accuracy: 0.001)
    }

    // MARK: - testSaveLoadRoundTrip (encode/decode fidelity)

    func testSaveLoadRoundTrip() {
        let store = TemplatesStore()

        var t1 = makeTemplate(name: "Gradient", symbol: "sunset.fill")
        t1.symbolColorHex = "#FF6B6B"
        t1.folderColorHex = "#4ECDC4"
        t1.symbolGradientEndHex = "#45B7D1"
        t1.symbolOpacity = 0.8
        t1.symbolScale = 1.2
        t1.symbolOffsetY = -5.0
        store.add(t1)

        var t2 = makeTemplate(name: "Minimal", symbol: "circle")
        t2.symbolOpacity = 0.3
        store.add(t2)

        // Encode the current state (simulating what save() does internally)
        guard let data = try? JSONEncoder().encode(store.templates) else {
            XCTFail("Encoding failed")
            return
        }

        // Decode back (simulating what load() does internally)
        guard let decoded = try? JSONDecoder().decode([IconTemplate].self, from: data) else {
            XCTFail("Decoding failed")
            return
        }

        XCTAssertEqual(decoded.count, 2)

        let d1 = decoded[0]
        XCTAssertEqual(d1.name, "Gradient")
        XCTAssertEqual(d1.symbol, "sunset.fill")
        XCTAssertEqual(d1.symbolColorHex, "#FF6B6B")
        XCTAssertEqual(d1.folderColorHex, "#4ECDC4")
        XCTAssertEqual(d1.symbolGradientEndHex, "#45B7D1")
        XCTAssertEqual(d1.symbolOpacity, 0.8, accuracy: 0.001)
        XCTAssertEqual(d1.symbolScale, 1.2, accuracy: 0.001)
        XCTAssertEqual(d1.symbolOffsetY, -5.0, accuracy: 0.001)

        let d2 = decoded[1]
        XCTAssertEqual(d2.name, "Minimal")
        XCTAssertEqual(d2.symbol, "circle")
        XCTAssertEqual(d2.symbolOpacity, 0.3, accuracy: 0.001)
    }

    func testSaveLoadRoundTripEmpty() {
        let store = TemplatesStore()
        let data = try! JSONEncoder().encode(store.templates)
        let decoded = try! JSONDecoder().decode([IconTemplate].self, from: data)
        XCTAssertTrue(decoded.isEmpty)
    }

    func testUserDefaultsPersistence() {
        let store1 = TemplatesStore()
        store1.add(makeTemplate(name: "Persistent", symbol: "lock.fill"))
        XCTAssertEqual(store1.templates.count, 1)

        // Create a new store instance — should load from UserDefaults
        let store2 = TemplatesStore()
        XCTAssertEqual(store2.templates.count, 1, "New store should load persisted templates")
        XCTAssertEqual(store2.templates.first?.name, "Persistent")
        XCTAssertEqual(store2.templates.first?.symbol, "lock.fill")
    }

    // MARK: - testDeleteBuiltinThrows/ignores (adapted — no builtin concept)

    func testRemoveAllTemplatesLeavesEmptyState() {
        let store = TemplatesStore()
        store.add(makeTemplate(name: "A"))
        store.add(makeTemplate(name: "B"))

        store.remove(at: IndexSet(integersIn: 0...1))
        XCTAssertTrue(store.templates.isEmpty)

        // Persists the empty state
        let fresh = TemplatesStore()
        XCTAssertTrue(fresh.templates.isEmpty, "Empty state should persist via UserDefaults")
    }
}
