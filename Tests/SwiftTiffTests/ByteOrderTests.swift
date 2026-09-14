import Testing
@testable import SwiftTiff

struct ByteOrderTests {

    // MARK: - Marker property

    @Test func markerValues() {
        #expect(ByteOrder.littleEndian.marker == "II")
        #expect(ByteOrder.bigEndian.marker == "MM")
    }

    // MARK: - Init from marker

    @Test func initFromValidMarkers() throws {
        #expect(try ByteOrder(marker: "II") == .littleEndian)
        #expect(try ByteOrder(marker: "MM") == .bigEndian)
    }

    @Test func initFromInvalidMarkerThrows() {
        #expect(throws: TIFFError.self) {
            try ByteOrder(marker: "XX")
        }
        #expect(throws: TIFFError.self) {
            try ByteOrder(marker: "")
        }
        #expect(throws: TIFFError.self) {
            try ByteOrder(marker: "Ii") // case sensitive
        }
    }

    // MARK: - Round-trip

    @Test func markerRoundTrip() throws {
        for order in [ByteOrder.littleEndian, .bigEndian] {
            let recovered = try ByteOrder(marker: order.marker)
            #expect(recovered == order)
        }
    }
}
