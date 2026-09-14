import Foundation

/// A rectangular window over a TIFF image. Coordinates are pixel-based:
/// min values are inclusive, max values are exclusive.
public struct ImageWindow: Sendable, Equatable {
    /// Minimum x coordinate (inclusive).
    public let minX: Int
    /// Minimum y coordinate (inclusive).
    public let minY: Int
    /// Maximum x coordinate (exclusive).
    public let maxX: Int
    /// Maximum y coordinate (exclusive).
    public let maxY: Int

    /// Creates a window with explicit bounds.
    ///
    /// - Precondition: `minX <= maxX && minY <= maxY`
    /// - Precondition: All coordinates >= 0
    public init(minX: Int, minY: Int, maxX: Int, maxY: Int) {
        precondition(minX >= 0 && minY >= 0, "Coordinates must be non-negative")
        precondition(minX <= maxX && minY <= maxY, "Min must not exceed max")
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }

    /// Creates a single-pixel window at `(x, y)`.
    /// ObjC: `initWithX:andY:` → `(x, y, x+1, y+1)`
    public init(x: Int, y: Int) {
        self.init(minX: x, minY: y, maxX: x + 1, maxY: y + 1)
    }

    /// Width in pixels.
    public var width: Int { maxX - minX }

    /// Height in pixels.
    public var height: Int { maxY - minY }

    /// Total number of pixels in the window.
    public var numPixels: Int { width * height }
}
