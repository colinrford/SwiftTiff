import Foundation

/// Writes `TIFFImage` structures to TIFF format.
public enum TIFFWriter {

    /// Write a TIFF image to in-memory data.
    public static func write(image: TIFFImage) throws(TIFFError) -> Data {
        var writer = ByteWriter(byteOrder: .littleEndian)
        try write(image: image, using: &writer)
        return writer.data
    }

    /// Write a TIFF image to a file path.
    public static func write(image: TIFFImage, to path: String) throws {
        let data = try write(image: image)
        try data.write(to: URL(fileURLWithPath: path))
    }

    /// Write a TIFF image using the provided ByteWriter.
    public static func write(
        image: TIFFImage,
        using writer: inout ByteWriter
    ) throws(TIFFError) {
        // Write byte order marker (bytes 0-1)
        _ = writer.writeString(writer.byteOrder.marker)

        // Write TIFF file identifier (bytes 2-3)
        writer.writeUInt16(TIFF.fileIdentifier)

        // Write first IFD offset (bytes 4-7) -- starts immediately at byte 8
        writer.writeUInt32(UInt32(TIFF.headerBytes))

        // Write file directories
        try writeDirectories(image: image, writer: &writer)
    }

    // MARK: - Directory writing

    private static func writeDirectories(
        image: TIFFImage,
        writer: inout ByteWriter
    ) throws(TIFFError) {
        for (i, var directory) in image.fileDirectories.enumerated() {

            // 1. Populate strip entries with placeholders for correct size calculation
            try populateStripEntries(&directory)

            let startOfDirectory = writer.count
            let afterDirectory = startOfDirectory + directory.size
            let afterValues = startOfDirectory + directory.sizeWithValues

            // 2. Write rasters to temp buffer -- this sets real strip offsets/byte counts
            let rastersBytes = try writeRasters(
                directory: &directory,
                byteOrder: writer.byteOrder,
                offset: afterValues
            )

            // 3. Write number of directory entries
            writer.writeUInt16(UInt16(directory.numEntries))

            // 4. Write each IFD entry
            var overflowEntries = [(FileDirectoryEntry, Int)]()
            var nextOverflowByte = afterDirectory

            for entry in directory.sortedEntries {
                writer.writeUInt16(entry.fieldTag.rawValue)
                writer.writeUInt16(entry.fieldType.rawValue)
                writer.writeUInt32(UInt32(entry.typeCount))

                let valueBytes = entry.fieldType.byteCount * entry.typeCount
                if valueBytes > 4 {
                    // Write offset to overflow area
                    overflowEntries.append((entry, nextOverflowByte))
                    writer.writeUInt32(try offset32(nextOverflowByte))
                    nextOverflowByte += entry.sizeOfValues
                } else {
                    // Write inline value, left-aligned, padded to 4 bytes
                    let bytesWritten = writeEntryValues(
                        writer: &writer, entry: entry
                    )
                    writeFiller(&writer, count: 4 - bytesWritten)
                }
            }

            // 5. Write next IFD offset (or 0 for last directory)
            if i + 1 < image.fileDirectories.count {
                let nextDirectoryOffset = afterValues + rastersBytes.count
                writer.writeUInt32(try offset32(nextDirectoryOffset))
            } else {
                writer.writeUInt32(0)
            }

            // 6. Write overflow entry values
            for (entry, _) in overflowEntries {
                writeEntryValues(writer: &writer, entry: entry)
            }

            // 7. Append raster bytes
            writer.writeBytes(rastersBytes)
        }
    }

    // MARK: - Strip population

    /// Populate strip offset and byte count entries with placeholder values.
    /// This allows `directory.size` and `directory.sizeWithValues` to return
    /// correct values before rasters are written.
    private static func populateStripEntries(
        _ directory: inout TIFFFileDirectory
    ) throws(TIFFError) {
        guard directory.writeRasters != nil else {
            throw .writeError("writeRasters is required to write a TIFF")
        }
        guard !directory.isTiled else {
            throw .writeError("Tiled image writing is not supported")
        }

        guard let rowsPerStrip = directory.rowsPerStrip,
              let imageHeight = directory.imageHeight else {
            throw .writeError("Missing rowsPerStrip or imageHeight")
        }
        guard rowsPerStrip > 0 else {
            throw .writeError("rowsPerStrip must be positive")
        }

        let stripsPerSample = (imageHeight + rowsPerStrip - 1) / rowsPerStrip
        var strips = stripsPerSample
        if directory.planarConfig == .planar {
            strips *= directory.samplesPerPixel
        }

        // Set placeholder values (zeros)
        directory.setStripOffsets(Array(repeating: 0, count: strips))
        directory.setStripByteCounts(Array(repeating: 0, count: strips))
    }

    // MARK: - Raster writing

    /// Write raster data to a temporary buffer. Updates strip offsets and
    /// byte counts on the directory with actual values.
    ///
    /// Returns the raw bytes to be appended after the IFD.
    private static func writeRasters(
        directory: inout TIFFFileDirectory,
        byteOrder: ByteOrder,
        offset: Int
    ) throws(TIFFError) -> Data {
        guard let rasters = directory.writeRasters else {
            throw .writeError("writeRasters is required")
        }
        guard !directory.isTiled else {
            throw .writeError("Tiled image writing is not supported")
        }

        guard rasters.width == directory.imageWidth,
              rasters.height == directory.imageHeight,
              rasters.samplesPerPixel == directory.samplesPerPixel else {
            throw .writeError(
                "Rasters (\(rasters.width)x\(rasters.height), \(rasters.samplesPerPixel) samples) do not match directory "
                    + "(\(directory.imageWidth.map(String.init) ?? "nil")x\(directory.imageHeight.map(String.init) ?? "nil"), "
                    + "\(directory.samplesPerPixel) samples)"
            )
        }

        // Get sample field types
        var sampleFieldTypes = [FieldType]()
        for sample in 0..<rasters.samplesPerPixel {
            sampleFieldTypes.append(try directory.fieldTypeForSample(sample))
        }

        // Get compression encoder
        let compressionType = directory.compression ?? .none
        let encoder = try codec(for: compressionType)

        var writer = ByteWriter(byteOrder: byteOrder)
        try writeStripRasters(
            writer: &writer,
            directory: &directory,
            rasters: rasters,
            offset: offset,
            sampleFieldTypes: sampleFieldTypes,
            encoder: encoder
        )

        return writer.data
    }

    /// Write strip raster data.
    private static func writeStripRasters(
        writer: inout ByteWriter,
        directory: inout TIFFFileDirectory,
        rasters: TIFFRasters,
        offset: Int,
        sampleFieldTypes: [FieldType],
        encoder: any CompressionCodec
    ) throws(TIFFError) {
        guard let rowsPerStrip = directory.rowsPerStrip,
              let maxY = directory.imageHeight,
              let imageWidth = directory.imageWidth else {
            throw .writeError("Missing image dimensions or rowsPerStrip")
        }

        let stripsPerSample = (maxY + rowsPerStrip - 1) / rowsPerStrip
        var strips = stripsPerSample
        if directory.planarConfig == .planar {
            strips *= rasters.samplesPerPixel
        }

        var stripOffsets = [Int]()
        var stripByteCounts = [Int]()
        var currentOffset = offset

        for strip in 0..<strips {
            let startingY: Int
            let sample: Int?

            if directory.planarConfig == .planar {
                sample = strip / stripsPerSample
                startingY = (strip % stripsPerSample) * rowsPerStrip
            } else {
                sample = nil
                startingY = strip * rowsPerStrip
            }

            // Write strip data to temp writer
            var stripWriter = ByteWriter(byteOrder: writer.byteOrder)
            let endingY = min(startingY + rowsPerStrip, maxY)

            for y in startingY..<endingY {
                var rowWriter = ByteWriter(byteOrder: writer.byteOrder)

                for x in 0..<imageWidth {
                    if let sample = sample {
                        // Planar: write single sample
                        let value = rasters.pixelSample(
                            sample: sample, x: x, y: y
                        )
                        try writeSampleValue(
                            writer: &rowWriter,
                            fieldType: sampleFieldTypes[sample],
                            value: value
                        )
                    } else {
                        // Chunky: write all samples
                        let values = rasters.pixel(x: x, y: y)
                        for (sampleIndex, value) in values.enumerated() {
                            try writeSampleValue(
                                writer: &rowWriter,
                                fieldType: sampleFieldTypes[sampleIndex],
                                value: value
                            )
                        }
                    }
                }

                // Encode row if row-encoding codec
                var rowData = rowWriter.data
                if encoder.rowEncoding {
                    rowData = try encoder.encode(
                        rowData, byteOrder: writer.byteOrder
                    )
                }
                stripWriter.writeBytes(rowData)
            }

            // Encode strip if non-row-encoding codec
            var stripData = stripWriter.data
            if !encoder.rowEncoding {
                stripData = try encoder.encode(
                    stripData, byteOrder: writer.byteOrder
                )
            }

            // Write strip and record offset/count
            writer.writeBytes(stripData)
            stripByteCounts.append(stripData.count)
            stripOffsets.append(currentOffset)
            currentOffset += stripData.count
        }

        // Classic TIFF offsets are 32-bit
        _ = try offset32(currentOffset)

        // Update directory with actual offsets and byte counts
        directory.setStripOffsets(stripOffsets)
        directory.setStripByteCounts(stripByteCounts)
    }

    // MARK: - Sample value writing

    /// Write a single sample value to the writer.
    ///
    /// Integer samples truncate fractional parts toward zero.
    /// - Throws: `TIFFError.writeError` if the value (or NaN) does not fit the sample type.
    private static func writeSampleValue(
        writer: inout ByteWriter,
        fieldType: FieldType,
        value: Double
    ) throws(TIFFError) {
        func integer<T: BinaryInteger>(_: T.Type) throws(TIFFError) -> T {
            guard let v = T(exactly: value.rounded(.towardZero)) else {
                throw .writeError("Sample value \(value) does not fit in \(fieldType)")
            }
            return v
        }
        switch fieldType {
        case .byte:
            writer.writeUInt8(try integer(UInt8.self))
        case .short:
            writer.writeUInt16(try integer(UInt16.self))
        case .long:
            writer.writeUInt32(try integer(UInt32.self))
        case .sbyte:
            writer.writeInt8(try integer(Int8.self))
        case .sshort:
            writer.writeInt16(try integer(Int16.self))
        case .slong:
            writer.writeInt32(try integer(Int32.self))
        case .float:
            writer.writeFloat32(Float(value))
        case .double:
            writer.writeFloat64(value)
        default:
            fatalError("Unsupported field type for raster writing: \(fieldType)")
        }
    }

    // MARK: - Entry value writing

    /// Write entry values to the writer. Returns the number of bytes written.
    @discardableResult
    private static func writeEntryValues(
        writer: inout ByteWriter,
        entry: FileDirectoryEntry
    ) -> Int {
        var bytesWritten = 0

        // Unwrap single values to a list for uniform iteration
        let values: [EntryValue]
        switch entry.values {
        case .array(let arr):
            values = arr
        default:
            values = [entry.values]
        }

        for value in values {
            switch (entry.fieldType, value) {
            case (.ascii, .ascii(let s)):
                bytesWritten += writer.writeString(s)
                // Pad ASCII to typeCount with null bytes
                if bytesWritten < entry.typeCount {
                    let filler = entry.typeCount - bytesWritten
                    writeFiller(&writer, count: filler)
                    bytesWritten += filler
                }
            case (.byte, .byte(let v)):
                writer.writeUInt8(v)
                bytesWritten += 1
            case (.undefined, .byte(let v)):
                writer.writeUInt8(v)
                bytesWritten += 1
            case (.sbyte, .sbyte(let v)):
                writer.writeInt8(v)
                bytesWritten += 1
            case (.short, .short(let v)):
                writer.writeUInt16(v)
                bytesWritten += 2
            case (.sshort, .sshort(let v)):
                writer.writeInt16(v)
                bytesWritten += 2
            case (.long, .long(let v)):
                writer.writeUInt32(v)
                bytesWritten += 4
            case (.slong, .slong(let v)):
                writer.writeInt32(v)
                bytesWritten += 4
            case (.rational, .rational(let n, let d)):
                writer.writeUInt32(n)
                writer.writeUInt32(d)
                bytesWritten += 8
            case (.srational, .srational(let n, let d)):
                writer.writeInt32(n)
                writer.writeInt32(d)
                bytesWritten += 8
            case (.float, .float(let v)):
                writer.writeFloat32(v)
                bytesWritten += 4
            case (.double, .double(let v)):
                writer.writeFloat64(v)
                bytesWritten += 8
            default:
                // Type mismatch -- skip (shouldn't happen for valid entries)
                break
            }
        }

        return bytesWritten
    }

    /// Convert a file offset to the 32-bit form classic TIFF stores.
    private static func offset32(_ offset: Int) throws(TIFFError) -> UInt32 {
        guard let value = UInt32(exactly: offset) else {
            throw .writeError("Offset \(offset) exceeds the 4 GB classic TIFF limit")
        }
        return value
    }

    /// Write zero filler bytes.
    private static func writeFiller(
        _ writer: inout ByteWriter, count: Int
    ) {
        for _ in 0..<count {
            writer.writeUInt8(0)
        }
    }
}
