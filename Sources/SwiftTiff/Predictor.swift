import Foundation

/// Differencing predictor decoder.
///
/// Applied as a post-processing step after decompression. The predictor
/// reverses per-row differencing applied during compression.
public enum Predictor {

    /// Decode predictor-encoded data.
    ///
    /// ObjC: `+[TIFFPredictor decodeData:withPredictor:andWidth:andHeight:andBitsPerSample:andPlanarConfiguration:]`
    ///
    /// - Parameters:
    ///   - data: Decompressed strip/tile data.
    ///   - predictor: The differencing predictor type.
    ///   - width: Tile/strip width in pixels.
    ///   - height: Number of rows.
    ///   - bitsPerSample: Bits per sample for each sample channel.
    ///   - planarConfiguration: Planar configuration of the data.
    /// - Returns: Decoded data, or the original data if predictor is `.none`.
    public static func decode(
        data: Data,
        predictor: DifferencingPredictor,
        width: Int,
        height: Int,
        bitsPerSample: [Int],
        planarConfiguration: PlanarConfiguration
    ) throws(TIFFError) -> Data {

        guard predictor != .none else {
            return data
        }

        guard let bps = bitsPerSample.first, bps > 0, bps % 8 == 0,
              bitsPerSample.allSatisfy({ $0 == bps }) else {
            throw .unsupportedPredictor
        }

        let bytesPerSample = bps / 8
        let samples = planarConfiguration == .planar ? 1 : bitsPerSample.count

        var reader = ByteReader(data: data, byteOrder: .littleEndian)
        var writer = ByteWriter(byteOrder: .littleEndian)

        for row in 0..<height {
            // Last strip may be truncated
            if row * samples * width * bytesPerSample >= data.count {
                break
            }

            switch predictor {
            case .none:
                break // unreachable — guarded above
            case .horizontal:
                try decodeHorizontal(
                    reader: &reader, writer: &writer,
                    width: width, bytesPerSample: bytesPerSample, samples: samples
                )
            case .floatingPoint:
                try decodeFloatingPoint(
                    reader: &reader, writer: &writer,
                    width: width, bytesPerSample: bytesPerSample, samples: samples
                )
            }
        }

        return writer.data
    }

    // MARK: - Horizontal predictor

    /// Decode a single row with horizontal differencing.
    ///
    /// Each sample value is the difference from the previous pixel's
    /// corresponding sample. Accumulate to reconstruct originals.
    private static func decodeHorizontal(
        reader: inout ByteReader,
        writer: inout ByteWriter,
        width: Int,
        bytesPerSample: Int,
        samples: Int
    ) throws(TIFFError) {
        var previous = [Int32](repeating: 0, count: samples)

        for _ in 0..<width {
            for sample in 0..<samples {
                let encoded = try readValue(reader: &reader, bytesPerSample: bytesPerSample)
                let value = encoded &+ previous[sample]
                writeValue(value, writer: &writer, bytesPerSample: bytesPerSample)
                previous[sample] = value
            }
        }
    }

    // MARK: - Floating-point predictor

    /// Decode a single row with floating-point differencing.
    ///
    /// Bytes are differenced across the row, then rearranged from
    /// byte-planar order back to standard sample byte order.
    private static func decodeFloatingPoint(
        reader: inout ByteReader,
        writer: inout ByteWriter,
        width: Int,
        bytesPerSample: Int,
        samples: Int
    ) throws(TIFFError) {
        let samplesWidth = width * samples
        let rowBytes = samplesWidth * bytesPerSample
        guard rowBytes <= reader.remainingBytes else {
            throw .unexpectedEndOfData(
                offset: reader.position, requested: rowBytes, available: reader.remainingBytes
            )
        }

        // Phase 1: Undo byte-level differencing
        var decoded = [UInt8](repeating: 0, count: samplesWidth * bytesPerSample)
        var previous = [UInt8](repeating: 0, count: samples)

        for sampleByte in 0..<(width * bytesPerSample) {
            for sample in 0..<samples {
                let raw = try reader.readUInt8()
                let value = raw &+ previous[sample]
                decoded[sampleByte * samples + sample] = value
                previous[sample] = value
            }
        }

        // Phase 2: Rearrange from byte-planar to standard sample order
        for widthSample in 0..<samplesWidth {
            for sampleByte in 0..<bytesPerSample {
                let index = (bytesPerSample - sampleByte - 1) * samplesWidth + widthSample
                writer.writeUInt8(decoded[index])
            }
        }
    }

    // MARK: - Value read/write helpers

    /// Read a sample value from the byte reader.
    ///
    /// Reads 1, 2, or 4 bytes depending on `bytesPerSample`.
    /// Uses little-endian byte order (predictor works on raw byte differences).
    private static func readValue(
        reader: inout ByteReader,
        bytesPerSample: Int
    ) throws(TIFFError) -> Int32 {
        switch bytesPerSample {
        case 1:
            return Int32(Int8(bitPattern: try reader.readUInt8()))
        case 2:
            return Int32(Int16(bitPattern: try reader.readUInt16()))
        case 4:
            return Int32(bitPattern: try reader.readUInt32())
        default:
            throw .unsupportedPredictor
        }
    }

    /// Write a sample value to the byte writer.
    private static func writeValue(
        _ value: Int32,
        writer: inout ByteWriter,
        bytesPerSample: Int
    ) {
        switch bytesPerSample {
        case 1:
            writer.writeInt8(Int8(truncatingIfNeeded: value))
        case 2:
            writer.writeInt16(Int16(truncatingIfNeeded: value))
        case 4:
            writer.writeInt32(value)
        default:
            break // unreachable — readValue would have thrown
        }
    }
}
