import Foundation

/// PackBits RLE codec (Compression.packbits).
///
/// Decodes per TIFF 6.0 spec Appendix C. Encoder is not yet implemented
/// (matches ObjC behavior).
public struct PackbitsCodec: CompressionCodec {
    public let rowEncoding = true

    public func decode(_ data: Data, byteOrder: ByteOrder) throws(TIFFError) -> Data {
        var reader = ByteReader(data: data, byteOrder: byteOrder)
        var decoded = Data()

        while reader.hasRemaining {
            let header = try Int8(bitPattern: reader.readUInt8())

            if header == -128 {
                // No-op
                continue
            } else if header < 0 {
                // Run: repeat next byte (-header + 1) times
                let count = Int(-header) + 1
                let byte = try reader.readUInt8()
                decoded.append(contentsOf: [UInt8](repeating: byte, count: count))
            } else {
                // Literal: copy next (header + 1) bytes
                let count = Int(header) + 1
                let bytes = try reader.readBytes(count)
                decoded.append(bytes)
            }
        }

        return decoded
    }

    public func encode(_ data: Data, byteOrder: ByteOrder) throws(TIFFError) -> Data {
        throw .unsupportedCompression
    }
}
