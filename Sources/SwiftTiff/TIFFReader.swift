import Foundation

/// Reads TIFF files into `TIFFImage` structures.
public enum TIFFReader {

    /// Read a TIFF from in-memory data.
    public static func read(from data: Data) throws(TIFFError) -> TIFFImage {
        var reader = ByteReader(data: data)

        // Read byte order marker (bytes 0-1)
        let orderMarker = try reader.readString(2)
        let byteOrder: ByteOrder
        switch orderMarker {
        case "II":
            byteOrder = .littleEndian
        case "MM":
            byteOrder = .bigEndian
        default:
            throw .invalidByteOrder(orderMarker)
        }
        reader.byteOrder = byteOrder

        // Validate TIFF file identifier (bytes 2-3)
        let identifier = try reader.readUInt16()
        guard identifier == TIFF.fileIdentifier else {
            throw .invalidFileIdentifier(identifier)
        }

        // Read first IFD offset (bytes 4-7)
        var ifdOffset = Int(try reader.readUInt32())

        // Parse IFDs
        var image = TIFFImage()
        var visitedOffsets = Set<Int>()
        while ifdOffset != 0 {
            guard visitedOffsets.insert(ifdOffset).inserted else {
                throw .invalidData("IFD chain loops back to offset \(ifdOffset)")
            }
            reader.position = ifdOffset

            let numEntries = Int(try reader.readUInt16())

            var entries = [FieldTagType: FileDirectoryEntry]()
            for _ in 0..<numEntries {
                let tagRaw = try reader.readUInt16()
                let typeRaw = try reader.readUInt16()
                let typeCount = Int(try reader.readUInt32())

                let nextEntryPos = reader.position + 4

                guard let fieldTag = FieldTagType(rawValue: tagRaw) else {
                    reader.position = nextEntryPos
                    continue
                }
                guard let fieldType = FieldType(rawValue: typeRaw) else {
                    reader.position = nextEntryPos
                    continue
                }

                let values = try readFieldValues(
                    reader: &reader,
                    fieldTag: fieldTag,
                    fieldType: fieldType,
                    typeCount: typeCount
                )

                let entry = FileDirectoryEntry(
                    fieldTag: fieldTag,
                    fieldType: fieldType,
                    typeCount: typeCount,
                    values: values
                )
                entries[fieldTag] = entry

                reader.position = nextEntryPos
            }

            let directory = TIFFFileDirectory(
                entries: entries,
                fileData: reader.data,
                fileByteOrder: byteOrder
            )
            image.fileDirectories.append(directory)

            // Read next IFD offset
            ifdOffset = Int(try reader.readUInt32())
        }

        return image
    }

    /// Read a TIFF from a file path.
    public static func read(fromFile path: String) throws -> TIFFImage {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try read(from: data)
    }

    /// Read a TIFF from an input stream.
    public static func read(from stream: InputStream) throws -> TIFFImage {
        let reader = try ByteReader.from(stream: stream)
        return try read(from: reader.data)
    }

    // MARK: - Private value reading

    private static func readFieldValues(
        reader: inout ByteReader,
        fieldTag: FieldTagType,
        fieldType: FieldType,
        typeCount: Int
    ) throws(TIFFError) -> EntryValue {
        let valueBytes = fieldType.byteCount * typeCount
        if valueBytes > 4 {
            let valueOffset = Int(try reader.readUInt32())
            reader.position = valueOffset
        }
        // Reject counts the file cannot hold before allocating per-value storage
        guard valueBytes <= reader.remainingBytes else {
            throw .unexpectedEndOfData(
                offset: reader.position,
                requested: valueBytes,
                available: reader.remainingBytes
            )
        }

        var values = [EntryValue]()
        for _ in 0..<typeCount {
            switch fieldType {
            case .byte:
                values.append(.byte(try reader.readUInt8()))
            case .undefined:
                values.append(.byte(try reader.readUInt8()))
            case .ascii:
                values.append(.ascii(try reader.readString(1)))
            case .short:
                values.append(.short(try reader.readUInt16()))
            case .long:
                values.append(.long(try reader.readUInt32()))
            case .rational:
                let num = try reader.readUInt32()
                let den = try reader.readUInt32()
                values.append(.rational(numerator: num, denominator: den))
            case .sbyte:
                values.append(.sbyte(try reader.readInt8()))
            case .sshort:
                values.append(.sshort(try reader.readInt16()))
            case .slong:
                values.append(.slong(try reader.readInt32()))
            case .srational:
                let num = try reader.readInt32()
                let den = try reader.readInt32()
                values.append(.srational(numerator: num, denominator: den))
            case .float:
                values.append(.float(try reader.readFloat32()))
            case .double:
                values.append(.double(try reader.readFloat64()))
            }
        }

        // Handle ASCII: combine single chars into strings (split on null)
        if fieldType == .ascii {
            return combineAsciiValues(values)
        }

        // Single non-array value: unwrap
        if typeCount == 1
            && !fieldTag.isArray
            && fieldType != .rational
            && fieldType != .srational
        {
            return values[0]
        }

        return .array(values)
    }

    /// Combine individual ASCII character values into NUL-separated strings.
    /// Always an array, even for a single string, matching tiff-ios.
    private static func combineAsciiValues(_ values: [EntryValue]) -> EntryValue {
        var strings = [EntryValue]()
        var current = ""
        for value in values {
            if case .ascii(let ch) = value {
                if ch.isEmpty || ch == "\0" {
                    if !current.isEmpty {
                        strings.append(.ascii(current))
                        current = ""
                    }
                } else {
                    current += ch
                }
            }
        }
        if !current.isEmpty {
            strings.append(.ascii(current))
        }

        return .array(strings)
    }
}
