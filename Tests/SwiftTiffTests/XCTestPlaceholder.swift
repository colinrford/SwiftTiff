import XCTest

// This empty XCTestCase exists solely to prevent the XCTest runner from
// crashing with signal 4 (SIGILL) when the test bundle contains no
// XCTestCase subclasses. All real tests use Swift Testing (@Test).
final class XCTestPlaceholder: XCTestCase {
    func testPlaceholder() {}
}
