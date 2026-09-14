import Testing
@testable import SwiftTiff

struct ImageWindowTests {

    // MARK: - Basic construction

    @Test func explicitBounds() {
        let window = ImageWindow(minX: 10, minY: 20, maxX: 110, maxY: 220)
        #expect(window.minX == 10)
        #expect(window.minY == 20)
        #expect(window.maxX == 110)
        #expect(window.maxY == 220)
        #expect(window.width == 100)
        #expect(window.height == 200)
        #expect(window.numPixels == 20_000)
    }

    @Test func singlePixel() {
        let window = ImageWindow(x: 5, y: 10)
        #expect(window.minX == 5)
        #expect(window.minY == 10)
        #expect(window.maxX == 6)
        #expect(window.maxY == 11)
        #expect(window.width == 1)
        #expect(window.height == 1)
        #expect(window.numPixels == 1)
    }

    @Test func originWindow() {
        let window = ImageWindow(x: 0, y: 0)
        #expect(window.minX == 0)
        #expect(window.minY == 0)
        #expect(window.maxX == 1)
        #expect(window.maxY == 1)
    }

    @Test func fullImage() {
        let window = ImageWindow(minX: 0, minY: 0, maxX: 256, maxY: 256)
        #expect(window.width == 256)
        #expect(window.height == 256)
        #expect(window.numPixels == 65536)
    }

    @Test func zeroSizeWindow() {
        // A window where min == max is valid (empty region)
        let window = ImageWindow(minX: 5, minY: 5, maxX: 5, maxY: 5)
        #expect(window.width == 0)
        #expect(window.height == 0)
        #expect(window.numPixels == 0)
    }

    // MARK: - Equatable

    @Test func equality() {
        let a = ImageWindow(minX: 0, minY: 0, maxX: 100, maxY: 100)
        let b = ImageWindow(minX: 0, minY: 0, maxX: 100, maxY: 100)
        let c = ImageWindow(minX: 0, minY: 0, maxX: 100, maxY: 50)
        #expect(a == b)
        #expect(a != c)
    }
}
