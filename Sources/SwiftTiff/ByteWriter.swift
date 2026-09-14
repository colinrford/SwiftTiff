import Foundation

/// Writes binary data with configurable byte order.
public struct ByteWriter: Sendable {
    public private(set) var data: Data
    public var byteOrder: ByteOrder

    public init(byteOrder: ByteOrder = .bigEndian) {
        self.data = Data()
        self.byteOrder = byteOrder
    }

    public var count: Int { data.count }

    // MARK: - Write methods

    public mutating func writeUInt8(_ value: UInt8) {
        data.append(value)
    }

    public mutating func writeInt8(_ value: Int8) {
        writeUInt8(UInt8(bitPattern: value))
    }

    public mutating func writeUInt16(_ value: UInt16) {
        let swapped = byteOrder == .bigEndian
            ? value.bigEndian
            : value.littleEndian
        withUnsafeBytes(of: swapped) { data.append(contentsOf: $0) }
    }

    public mutating func writeInt16(_ value: Int16) {
        writeUInt16(UInt16(bitPattern: value))
    }

    public mutating func writeUInt32(_ value: UInt32) {
        let swapped = byteOrder == .bigEndian
            ? value.bigEndian
            : value.littleEndian
        withUnsafeBytes(of: swapped) { data.append(contentsOf: $0) }
    }

    public mutating func writeInt32(_ value: Int32) {
        writeUInt32(UInt32(bitPattern: value))
    }

    public mutating func writeFloat32(_ value: Float) {
        writeUInt32(value.bitPattern)
    }

    public mutating func writeFloat64(_ value: Double) {
        let bits = value.bitPattern
        let swapped = byteOrder == .bigEndian
            ? bits.bigEndian
            : bits.littleEndian
        withUnsafeBytes(of: swapped) { data.append(contentsOf: $0) }
    }

    public mutating func writeBytes(_ bytes: Data) {
        data.append(bytes)
    }

    /// Write a UTF-8 string. Returns the number of bytes written.
    @discardableResult
    public mutating func writeString(_ string: String) -> Int {
        let utf8 = Data(string.utf8)
        data.append(utf8)
        return utf8.count
    }
}
