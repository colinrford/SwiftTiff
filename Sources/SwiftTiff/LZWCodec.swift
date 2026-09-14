import Foundation

/// LZW codec for TIFF (Compression.lzw).
///
/// Implements TIFF 6.0 LZW decompression with variable-width codes.
/// Encoder is not yet implemented (matches ObjC behavior).
public struct LZWCodec: CompressionCodec {
    public let rowEncoding = false

    /// Clear code — resets the code table.
    private static let clearCode = 256
    /// End of information code — terminates decoding.
    private static let eoiCode = 257
    /// Minimum code bit width (codes 0–257 fit in 9 bits).
    private static let minBits = 9

    public func decode(_ data: Data, byteOrder: ByteOrder) throws(TIFFError) -> Data {
        let data = data.zeroIndexed
        var output = [UInt8]()

        // Bit-level reader state
        var bitPosition = 0

        // Initialize the code table
        var table = [[UInt8]]()
        var currentBits = 0
        func resetTable() {
            table = (0..<256).map { [UInt8($0)] }
            table.append([])  // 256 = clear code (placeholder)
            table.append([])  // 257 = EOI code (placeholder)
            currentBits = Self.minBits
        }
        resetTable()

        /// Read the next variable-width code from the input data.
        ///
        /// Bug fix: ObjC used `pow(2, ...)` (floating-point) for bitmask
        /// computation. Swift uses integer bit shifts (`1 << n`).
        func nextCode() -> Int {
            let byteOffset = bitPosition / 8
            let bitOffset = bitPosition % 8

            guard byteOffset < data.count else {
                // ObjC: logs warning and returns EOI
                return Self.eoiCode
            }

            // Accumulate enough bits from up to 3 bytes
            var rawBits = 0
            for i in 0..<3 {
                let idx = byteOffset + i
                guard idx < data.count else { break }
                rawBits = (rawBits << 8) | Int(data[idx])
            }

            // We have up to 24 bits starting from byteOffset.
            // The code starts at bitOffset within those bits.
            let bitsAvailable = (min(data.count - byteOffset, 3)) * 8
            let shift = bitsAvailable - bitOffset - currentBits
            let code: Int
            if shift >= 0 {
                code = (rawBits >> shift) & ((1 << currentBits) - 1)
            } else {
                // Not enough bits — return EOI
                return Self.eoiCode
            }

            bitPosition += currentBits
            return code
        }

        var oldCode = 0

        // Read first code (must be a clear code or a literal)
        var code = nextCode()
        while code != Self.eoiCode {

            if code == Self.clearCode {
                resetTable()

                // Skip consecutive clear codes
                code = nextCode()
                while code == Self.clearCode {
                    code = nextCode()
                }
                if code == Self.eoiCode {
                    break
                }
                if code > Self.clearCode {
                    throw .corruptedLZW
                }

                // Output the literal value
                output.append(contentsOf: table[code])
                oldCode = code

            } else if code < table.count {
                // Code is already in the table
                let value = table[code]
                output.append(contentsOf: value)

                // Add new entry: oldCode's value + first byte of current value
                var newEntry = table[oldCode]
                newEntry.append(value[0])
                table.append(newEntry)

                // Check if we need to widen the code size
                if table.count >= (1 << currentBits) - 1 && currentBits < 12 {
                    currentBits += 1
                }

                oldCode = code

            } else {
                // Code is NOT in the table — special LZW case
                let oldValue = table[oldCode]
                var newEntry = oldValue
                newEntry.append(oldValue[0])
                output.append(contentsOf: newEntry)

                // The new code must equal table.count (the next code to be added)
                if code != table.count {
                    throw .corruptedLZW
                }
                table.append(newEntry)

                // Check if we need to widen the code size
                if table.count >= (1 << currentBits) - 1 && currentBits < 12 {
                    currentBits += 1
                }

                oldCode = code
            }

            code = nextCode()
        }

        return Data(output)
    }

    public func encode(_ data: Data, byteOrder: ByteOrder) throws(TIFFError) -> Data {
        throw .unsupportedCompression
    }
}
