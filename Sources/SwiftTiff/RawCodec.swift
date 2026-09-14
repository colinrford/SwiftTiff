import Foundation

/// No-op codec for uncompressed TIFF data (Compression.none).
public struct RawCodec: CompressionCodec {
    public let rowEncoding = false

    public func decode(_ data: Data, byteOrder: ByteOrder) throws(TIFFError) -> Data {
        data
    }

    public func encode(_ data: Data, byteOrder: ByteOrder) throws(TIFFError) -> Data {
        data
    }
}
