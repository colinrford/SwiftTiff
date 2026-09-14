import Foundation

/// Reads binary data with configurable byte order.
public struct ByteReader: Sendable {
    public private(set) var data: Data
    public var position: Int
    public var byteOrder: ByteOrder

    public init(data: Data, byteOrder: ByteOrder = .bigEndian) {
        self.data = data.zeroIndexed
        self.position = 0
        self.byteOrder = byteOrder
    }

    // MARK: - Bounds checking

    /// Throws if reading `count` bytes at `offset` would exceed the data.
    private func checkBounds(offset: Int, count: Int) throws(TIFFError) {
        if offset + count > data.count {
            throw .unexpectedEndOfData(
                offset: offset,
                requested: count,
                available: data.count
            )
        }
    }

    // MARK: - Sequential reads (advance position)

    public mutating func readUInt8() throws(TIFFError) -> UInt8 {
        let value = try readUInt8(at: position)
        position += 1
        return value
    }

    public mutating func readUInt16() throws(TIFFError) -> UInt16 {
        let value = try readUInt16(at: position)
        position += 2
        return value
    }

    public mutating func readUInt32() throws(TIFFError) -> UInt32 {
        let value = try readUInt32(at: position)
        position += 4
        return value
    }

    public mutating func readInt8() throws(TIFFError) -> Int8 {
        Int8(bitPattern: try readUInt8())
    }

    public mutating func readInt16() throws(TIFFError) -> Int16 {
        Int16(bitPattern: try readUInt16())
    }

    public mutating func readInt32() throws(TIFFError) -> Int32 {
        Int32(bitPattern: try readUInt32())
    }

    public mutating func readFloat32() throws(TIFFError) -> Float {
        Float(bitPattern: try readUInt32())
    }

    public mutating func readFloat64() throws(TIFFError) -> Double {
        let value = try readFloat64(at: position)
        position += 8
        return value
    }

    public mutating func readBytes(_ count: Int) throws(TIFFError) -> Data {
        try checkBounds(offset: position, count: count)
        let slice = data[position ..< position + count]
        position += count
        return Data(slice)
    }

    public mutating func readString(_ count: Int) throws(TIFFError) -> String {
        let bytes = try readBytes(count)
        return String(decoding: bytes, as: UTF8.self)
    }

    // MARK: - Random-access reads (no position change)

    public func readUInt8(at offset: Int) throws(TIFFError) -> UInt8 {
        try checkBounds(offset: offset, count: 1)
        return data[offset]
    }

    public func readUInt16(at offset: Int) throws(TIFFError) -> UInt16 {
        try checkBounds(offset: offset, count: 2)
        let raw = data.withUnsafeBytes { ptr in
            ptr.loadUnaligned(fromByteOffset: offset, as: UInt16.self)
        }
        return byteOrder == .bigEndian
            ? UInt16(bigEndian: raw)
            : UInt16(littleEndian: raw)
    }

    public func readUInt32(at offset: Int) throws(TIFFError) -> UInt32 {
        try checkBounds(offset: offset, count: 4)
        let raw = data.withUnsafeBytes { ptr in
            ptr.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
        }
        return byteOrder == .bigEndian
            ? UInt32(bigEndian: raw)
            : UInt32(littleEndian: raw)
    }

    public func readInt8(at offset: Int) throws(TIFFError) -> Int8 {
        Int8(bitPattern: try readUInt8(at: offset))
    }

    public func readInt16(at offset: Int) throws(TIFFError) -> Int16 {
        Int16(bitPattern: try readUInt16(at: offset))
    }

    public func readInt32(at offset: Int) throws(TIFFError) -> Int32 {
        Int32(bitPattern: try readUInt32(at: offset))
    }

    public func readFloat32(at offset: Int) throws(TIFFError) -> Float {
        Float(bitPattern: try readUInt32(at: offset))
    }

    public func readFloat64(at offset: Int) throws(TIFFError) -> Double {
        try checkBounds(offset: offset, count: 8)
        let raw = data.withUnsafeBytes { ptr in
            ptr.loadUnaligned(fromByteOffset: offset, as: UInt64.self)
        }
        let swapped = byteOrder == .bigEndian
            ? UInt64(bigEndian: raw)
            : UInt64(littleEndian: raw)
        return Double(bitPattern: swapped)
    }

    public func readBytes(at offset: Int, count: Int) throws(TIFFError) -> Data {
        try checkBounds(offset: offset, count: count)
        return Data(data[offset ..< offset + count])
    }

    public func readString(at offset: Int, count: Int) throws(TIFFError) -> String {
        let bytes = try readBytes(at: offset, count: count)
        return String(decoding: bytes, as: UTF8.self)
    }

    // MARK: - State

    public var remainingBytes: Int { data.count - position }
    public var hasRemaining: Bool { position < data.count }
    public var byteLength: Int { data.count }

    // MARK: - Factory methods (replacing TIFFIOUtils)
    // These use plain `throws` because Foundation I/O can throw non-TIFFError types.

    /// Read all bytes from a file path.
    public static func from(file path: String) throws -> ByteReader {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return ByteReader(data: data)
    }

    /// Read all bytes from an input stream.
    public static func from(stream: InputStream) throws -> ByteReader {
        stream.open()
        defer { stream.close() }
        var result = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let bytesRead = stream.read(buffer, maxLength: bufferSize)
            if bytesRead > 0 {
                result.append(buffer, count: bytesRead)
            } else if bytesRead < 0 {
                throw stream.streamError ?? TIFFError.unexpectedEndOfData(
                    offset: result.count, requested: 1, available: 0
                )
            } else {
                break
            }
        }
        return ByteReader(data: result)
    }
}

extension Data {
    /// This data with `startIndex == 0`, copying only if it is a slice.
    ///
    /// Slices such as `data[4407...]` keep their parent's indices, so
    /// offset-based subscripting (`data[0]`) traps unless rebased first.
    var zeroIndexed: Data {
        startIndex == 0 ? self : Data(self)
    }
}
