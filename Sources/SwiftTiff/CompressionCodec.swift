import Foundation

/// A codec that can decode and/or encode TIFF strip/tile data.
public protocol CompressionCodec: Sendable {
    /// Whether encoding operates on individual rows (`true`) vs. full blocks/strips (`false`).
    var rowEncoding: Bool { get }
    /// Decode compressed data.
    func decode(_ data: Data, byteOrder: ByteOrder) throws(TIFFError) -> Data
    /// Encode raw data.
    func encode(_ data: Data, byteOrder: ByteOrder) throws(TIFFError) -> Data
}

/// Resolve a `Compression` value to its codec implementation.
///
/// ObjC: switch block in `TIFFFileDirectory.m` lines 66-90.
/// Swift: moved to a standalone function so it can be used without a TIFFFileDirectory.
///
/// - Throws: `TIFFError.unsupportedCompression` for compression types without a codec.
public func codec(for compression: Compression) throws(TIFFError) -> CompressionCodec {
    switch compression {
    case .none:
        return RawCodec()
    case .lzw:
        return LZWCodec()
    case .packbits:
        return PackbitsCodec()
    case .deflate:
        return DeflateCodec()
    case .ccittHuffman, .t4, .t6, .jpegOld, .jpegNew:
        throw .unsupportedCompression
    }
}
