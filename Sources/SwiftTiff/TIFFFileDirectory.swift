import Foundation

/// A TIFF Image File Directory (IFD).
///
/// Contains directory entries (tags) and provides typed access to standard
/// TIFF fields. For read TIFFs, also provides raster reading via the
/// stored file data.
public struct TIFFFileDirectory: Sendable {

    // MARK: - Storage

    /// Directory entries keyed by field tag.
    private var entries: [FieldTagType: FileDirectoryEntry]

    /// Raw file data for raster reading (nil for write-only directories).
    private let fileData: Data?

    /// Byte order of the file data.
    private let fileByteOrder: ByteOrder

    // MARK: - Cached derived state

    /// Whether this is a tiled image (true) or stripped (false).
    public let isTiled: Bool

    /// Planar configuration (chunky or planar).
    public var planarConfig: PlanarConfiguration {
        let pc = Self.extractUInt16(from: entries[.planarConfiguration]?.values)
        return pc.flatMap { PlanarConfiguration(rawValue: $0) } ?? .chunky
    }

    /// Rasters to write (used by TIFFWriter).
    public var writeRasters: TIFFRasters?

    // MARK: - Initializers

    /// Initialize for reading — called by TIFFReader after parsing entries.
    public init(
        entries: [FieldTagType: FileDirectoryEntry],
        fileData: Data,
        fileByteOrder: ByteOrder
    ) {
        self.entries = entries
        self.fileData = fileData
        self.fileByteOrder = fileByteOrder
        self.writeRasters = nil

        // Tiled images have tileWidth but no rowsPerStrip
        self.isTiled = entries[.tileWidth] != nil
    }

    /// Initialize for writing — caller will set entries and writeRasters.
    public init() {
        self.entries = [:]
        self.fileData = nil
        self.fileByteOrder = .bigEndian
        self.isTiled = false
        self.writeRasters = nil
    }

    /// Initialize for writing with rasters.
    public init(rasters: TIFFRasters) {
        self.init()
        self.writeRasters = rasters
    }

    // MARK: - Entry access

    /// Get the entry for a field tag.
    public func entry(for tag: FieldTagType) -> FileDirectoryEntry? {
        entries[tag]
    }

    /// All entries, sorted by tag raw value (for writing).
    public var sortedEntries: [FileDirectoryEntry] {
        entries.values.sorted { $0.fieldTag.rawValue < $1.fieldTag.rawValue }
    }

    /// Number of entries.
    public var numEntries: Int { entries.count }

    /// Add or replace an entry.
    public mutating func addEntry(_ entry: FileDirectoryEntry) {
        entries[entry.fieldTag] = entry
    }

    // MARK: - Tag property accessors

    /// Image width in pixels.
    public var imageWidth: Int? {
        intValue(for: .imageWidth)
    }

    /// Image height (length) in pixels.
    public var imageHeight: Int? {
        intValue(for: .imageLength)
    }

    /// Bits per sample for each channel.
    public var bitsPerSample: [Int]? {
        intArray(for: .bitsPerSample)
    }

    /// Compression scheme.
    public var compression: Compression? {
        guard let raw = uint16Value(for: .compression) else { return nil }
        return Compression(rawValue: raw)
    }

    /// Photometric interpretation.
    public var photometricInterpretation: PhotometricInterpretation? {
        guard let raw = uint16Value(for: .photometricInterpretation) else { return nil }
        return PhotometricInterpretation(rawValue: raw)
    }

    /// Strip offsets (for stripped images).
    public var stripOffsets: [Int]? {
        intArray(for: .stripOffsets)
    }

    /// Samples per pixel (defaults to 1 per TIFF spec if not present).
    public var samplesPerPixel: Int {
        intValue(for: .samplesPerPixel) ?? 1
    }

    /// Rows per strip (nil for tiled images).
    public var rowsPerStrip: Int? {
        intValue(for: .rowsPerStrip)
    }

    /// Strip byte counts.
    public var stripByteCounts: [Int]? {
        intArray(for: .stripByteCounts)
    }

    /// Planar configuration tag value.
    public var planarConfiguration: PlanarConfiguration? {
        guard let raw = uint16Value(for: .planarConfiguration) else { return nil }
        return PlanarConfiguration(rawValue: raw)
    }

    /// Sample format for each channel.
    public var sampleFormat: [Int]? {
        intArray(for: .sampleFormat)
    }

    /// Differencing predictor.
    public var predictor: DifferencingPredictor? {
        guard let raw = uint16Value(for: .predictor) else { return nil }
        return DifferencingPredictor(rawValue: raw)
    }

    /// Tile width (for tiled images; for stripped, returns imageWidth).
    public var tileWidth: Int? {
        isTiled ? intValue(for: .tileWidth) : imageWidth
    }

    /// Tile height (for tiled images; for stripped, returns rowsPerStrip).
    public var tileHeight: Int? {
        isTiled ? intValue(for: .tileLength) : rowsPerStrip
    }

    /// Tile offsets (for tiled images).
    public var tileOffsets: [Int]? {
        intArray(for: .tileOffsets)
    }

    /// Tile byte counts (for tiled images).
    public var tileByteCounts: [Int]? {
        intArray(for: .tileByteCounts)
    }

    /// Resolution unit.
    public var resolutionUnit: ResolutionUnit? {
        guard let raw = uint16Value(for: .resolutionUnit) else { return nil }
        return ResolutionUnit(rawValue: raw)
    }

    /// Color map.
    public var colorMap: [Int]? {
        intArray(for: .colorMap)
    }

    // MARK: - Mutating setters (for writing)

    /// Stored as SHORT when the value fits in 16 bits, otherwise LONG.
    public mutating func setImageWidth(_ width: Int) {
        setShortOrLongEntry(.imageWidth, value: width)
    }

    /// Stored as SHORT when the value fits in 16 bits, otherwise LONG.
    public mutating func setImageHeight(_ height: Int) {
        setShortOrLongEntry(.imageLength, value: height)
    }

    public mutating func setBitsPerSample(_ values: [Int]) {
        setShortArrayEntry(.bitsPerSample, values: values.map { UInt16($0) })
    }

    public mutating func setBitsPerSampleAsSingleValue(_ value: Int) {
        setBitsPerSample([value])
    }

    public mutating func setCompression(_ compression: Compression) {
        setShortEntry(.compression, value: compression.rawValue)
    }

    public mutating func setPhotometricInterpretation(_ value: PhotometricInterpretation) {
        setShortEntry(.photometricInterpretation, value: value.rawValue)
    }

    public mutating func setSamplesPerPixel(_ value: Int) {
        setShortEntry(.samplesPerPixel, value: UInt16(value))
    }

    /// Stored as SHORT when the value fits in 16 bits, otherwise LONG.
    public mutating func setRowsPerStrip(_ value: Int) {
        setShortOrLongEntry(.rowsPerStrip, value: value)
    }

    public mutating func setPlanarConfiguration(_ value: PlanarConfiguration) {
        setShortEntry(.planarConfiguration, value: value.rawValue)
    }

    public mutating func setSampleFormat(_ values: [Int]) {
        setShortArrayEntry(.sampleFormat, values: values.map { UInt16($0) })
    }

    public mutating func setSampleFormatAsSingleValue(_ value: SampleFormat) {
        setSampleFormat([Int(value.rawValue)])
    }

    public mutating func setStripOffsets(_ values: [Int]) {
        setLongArrayEntry(.stripOffsets, values: values.map { UInt32($0) })
    }

    public mutating func setStripByteCounts(_ values: [Int]) {
        setLongArrayEntry(.stripByteCounts, values: values.map { UInt32($0) })
    }

    public mutating func setResolutionUnit(_ value: ResolutionUnit) {
        setShortEntry(.resolutionUnit, value: value.rawValue)
    }

    public mutating func setXResolution(_ value: Int) {
        let entry = FileDirectoryEntry(
            fieldTag: .xResolution,
            fieldType: .rational,
            typeCount: 1,
            values: .rational(numerator: UInt32(value), denominator: 1)
        )
        entries[.xResolution] = entry
    }

    public mutating func setYResolution(_ value: Int) {
        let entry = FileDirectoryEntry(
            fieldTag: .yResolution,
            fieldType: .rational,
            typeCount: 1,
            values: .rational(numerator: UInt32(value), denominator: 1)
        )
        entries[.yResolution] = entry
    }

    /// X resolution as rational (numerator, denominator).
    public var xResolution: (numerator: UInt32, denominator: UInt32)? {
        guard let entry = entries[.xResolution] else { return nil }
        if case .rational(let n, let d) = entry.values {
            return (n, d)
        }
        return nil
    }

    /// Y resolution as rational.
    public var yResolution: (numerator: UInt32, denominator: UInt32)? {
        guard let entry = entries[.yResolution] else { return nil }
        if case .rational(let n, let d) = entry.values {
            return (n, d)
        }
        return nil
    }

    // MARK: - Raster reading

    /// Read all rasters in planar (per-sample) mode.
    public func readRasters() throws(TIFFError) -> TIFFRasters {
        guard let width = imageWidth, let height = imageHeight else {
            throw .invalidData("Missing image dimensions")
        }
        let window = ImageWindow(
            minX: 0, minY: 0,
            maxX: width, maxY: height
        )
        return try readRasters(window: window)
    }

    /// Read rasters for a window in planar mode.
    public func readRasters(window: ImageWindow) throws(TIFFError) -> TIFFRasters {
        try readRasters(
            window: window,
            samples: nil,
            sampleValues: true,
            interleaveValues: false
        )
    }

    /// Read rasters as interleaved.
    public func readInterleavedRasters() throws(TIFFError) -> TIFFRasters {
        guard let width = imageWidth, let height = imageHeight else {
            throw .invalidData("Missing image dimensions")
        }
        let window = ImageWindow(
            minX: 0, minY: 0,
            maxX: width, maxY: height
        )
        return try readRasters(
            window: window,
            samples: nil,
            sampleValues: false,
            interleaveValues: true
        )
    }

    /// Read rasters with full control over output format.
    public func readRasters(
        window: ImageWindow,
        samples requestedSamples: [Int]?,
        sampleValues: Bool,
        interleaveValues: Bool
    ) throws(TIFFError) -> TIFFRasters {
        guard let width = imageWidth, let height = imageHeight else {
            throw .invalidData("Missing image dimensions")
        }
        guard let bps = bitsPerSample else {
            throw .invalidData("Missing bitsPerSample")
        }
        guard width > 0, height > 0 else {
            throw .invalidData("Image dimensions must be positive (\(width)x\(height))")
        }

        let spp = samplesPerPixel
        guard spp > 0, bps.count >= spp else {
            throw .invalidData("bitsPerSample has \(bps.count) values for \(spp) samples per pixel")
        }
        guard bps.prefix(spp).allSatisfy({ $0 > 0 && $0 % 8 == 0 }) else {
            throw .unsupported("Bits per sample \(bps) (only whole-byte samples are supported)")
        }

        guard sampleValues != interleaveValues else {
            throw .invalidArgument("Exactly one of sampleValues or interleaveValues must be true")
        }
        guard !width.multipliedReportingOverflow(by: height).overflow,
              !(width * height).multipliedReportingOverflow(by: spp).overflow else {
            throw .invalidData("Image dimensions \(width)x\(height)x\(spp) overflow")
        }
        guard window.maxX <= width, window.maxY <= height else {
            throw .invalidArgument("Window \(window) exceeds image bounds \(width)x\(height)")
        }
        guard window.width > 0, window.height > 0 else {
            throw .invalidArgument("Window \(window) is empty")
        }

        let samples = requestedSamples ?? Array(0..<spp)
        guard !samples.isEmpty else {
            throw .invalidArgument("No samples requested")
        }
        if let bad = samples.first(where: { $0 < 0 || $0 >= spp }) {
            throw .invalidArgument("Sample index \(bad) out of range 0..<\(spp)")
        }

        let windowWidth = window.width
        let windowHeight = window.height
        // Cannot overflow: the window is within the image, checked above
        let valueCount = windowWidth * windowHeight * samples.count

        // Rasters describe the returned samples, not the file's full pixel layout
        let rasterBitsPerSample = samples.map { bps[$0] }
        var rasters: TIFFRasters
        if sampleValues {
            let sampleArrays = (0..<samples.count).map { _ in
                [Double](repeating: 0, count: windowWidth * windowHeight)
            }
            rasters = TIFFRasters(
                width: windowWidth, height: windowHeight,
                samplesPerPixel: samples.count, bitsPerSample: rasterBitsPerSample,
                sampleValues: sampleArrays
            )
        } else {
            rasters = TIFFRasters(
                width: windowWidth, height: windowHeight,
                samplesPerPixel: samples.count, bitsPerSample: rasterBitsPerSample,
                interleaveValues: [Double](repeating: 0, count: valueCount)
            )
        }

        try readRastersInto(
            &rasters,
            window: window,
            samples: samples,
            sampleValues: sampleValues,
            interleaveValues: interleaveValues
        )

        return rasters
    }

    /// Core raster reading logic.
    private func readRastersInto(
        _ rasters: inout TIFFRasters,
        window: ImageWindow,
        samples: [Int],
        sampleValues: Bool,
        interleaveValues: Bool
    ) throws(TIFFError) {
        guard let tw = tileWidth, let th = tileHeight else {
            throw .invalidData("Missing tile/strip dimensions")
        }
        guard tw > 0, th > 0 else {
            throw .invalidData("Tile/strip dimensions must be positive (\(tw)x\(th))")
        }
        guard let bps = bitsPerSample else {
            throw .invalidData("Missing bitsPerSample")
        }

        let windowWidth = window.width
        let isBigEndian = fileByteOrder == .bigEndian

        let minXTile = window.minX / tw
        let maxXTile = (window.maxX + tw - 1) / tw
        let minYTile = window.minY / th
        let maxYTile = (window.maxY + th - 1) / th

        var srcSampleOffsets = [Int]()
        var sampleFieldTypes = [FieldType]()
        for sampleIdx in samples {
            let offset: Int
            if planarConfig == .chunky {
                offset = bps[0..<sampleIdx].reduce(0, +) / 8
            } else {
                offset = 0
            }
            srcSampleOffsets.append(offset)
            sampleFieldTypes.append(try fieldTypeForSample(sampleIdx))
        }

        let chunkyBytesPerPixel = bps.prefix(samplesPerPixel).reduce(0, +) / 8
        var bytesPerPixel = chunkyBytesPerPixel

        // Bound every byte offset computed from the tile layout below
        let (tilePixels, tileOverflow) = tw.multipliedReportingOverflow(by: th)
        guard !tileOverflow,
              !tilePixels.multipliedReportingOverflow(by: max(chunkyBytesPerPixel, 8)).overflow else {
            throw .invalidData("Tile/strip dimensions \(tw)x\(th) overflow")
        }

        var blockCache = [Int: Data]()

        for yTile in minYTile..<maxYTile {
            for xTile in minXTile..<maxXTile {

                let firstLine = yTile * th
                let firstCol = xTile * tw
                let lastLine = (yTile + 1) * th
                let lastCol = (xTile + 1) * tw

                for (sampleIndex, sample) in samples.enumerated() {
                    if planarConfig == .planar {
                        bytesPerPixel = bps[sample] / 8
                    }

                    let block = try tileOrStrip(
                        x: xTile, y: yTile, sample: sample,
                        tileWidth: tw, tileHeight: th,
                        cache: &blockCache
                    )

                    let yStart = max(0, window.minY - firstLine)
                    let yEnd = min(th, th - (lastLine - window.maxY))
                    let xStart = max(0, window.minX - firstCol)
                    let xEnd = min(tw, tw - (lastCol - window.maxX))

                    let fieldType = sampleFieldTypes[sampleIndex]
                    let sampleOffset = srcSampleOffsets[sampleIndex]

                    guard yStart < yEnd, xStart < xEnd else { continue }

                    // The unchecked read below requires the block to hold its last sample
                    let lastValueEnd = ((yEnd - 1) * tw + (xEnd - 1)) * bytesPerPixel
                        + sampleOffset + fieldType.byteCount
                    guard lastValueEnd <= block.count else {
                        throw .invalidData(
                            "Tile/strip (\(xTile), \(yTile)) decoded to \(block.count) bytes; \(lastValueEnd) required"
                        )
                    }

                    // Read directly from raw bytes for performance
                    block.withUnsafeBytes { ptr in
                        for y in yStart..<yEnd {
                            for x in xStart..<xEnd {
                                let pixelOffset = (y * tw + x) * bytesPerPixel
                                let valueOffset = pixelOffset + sampleOffset

                                let value = readSampleValueFast(
                                    ptr: ptr, offset: valueOffset,
                                    fieldType: fieldType, bigEndian: isBigEndian
                                )

                                if interleaveValues {
                                    let coord = (y + firstLine - window.minY) * windowWidth * samples.count
                                        + (x + firstCol - window.minX) * samples.count
                                        + sampleIndex
                                    rasters.setInterleaveValue(value, at: coord)
                                }

                                if sampleValues {
                                    let coord = (y + firstLine - window.minY) * windowWidth
                                        + x + firstCol - window.minX
                                    rasters.setSampleValue(value, sampleIndex: sampleIndex, coordinateIndex: coord)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// Read a sample value directly from an UnsafeRawBufferPointer — no ByteReader overhead.
    /// Field types are pre-validated by the caller, so unsupported types hit fatalError.
    private func readSampleValueFast(
        ptr: UnsafeRawBufferPointer,
        offset: Int,
        fieldType: FieldType,
        bigEndian: Bool
    ) -> Double {
        switch fieldType {
        case .byte:
            return Double(ptr[offset])
        case .short:
            let raw = ptr.loadUnaligned(fromByteOffset: offset, as: UInt16.self)
            return Double(bigEndian ? UInt16(bigEndian: raw) : UInt16(littleEndian: raw))
        case .long:
            let raw = ptr.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
            return Double(bigEndian ? UInt32(bigEndian: raw) : UInt32(littleEndian: raw))
        case .sbyte:
            return Double(Int8(bitPattern: ptr[offset]))
        case .sshort:
            let raw = ptr.loadUnaligned(fromByteOffset: offset, as: UInt16.self)
            let val = bigEndian ? UInt16(bigEndian: raw) : UInt16(littleEndian: raw)
            return Double(Int16(bitPattern: val))
        case .slong:
            let raw = ptr.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
            let val = bigEndian ? UInt32(bigEndian: raw) : UInt32(littleEndian: raw)
            return Double(Int32(bitPattern: val))
        case .float:
            let raw = ptr.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
            let val = bigEndian ? UInt32(bigEndian: raw) : UInt32(littleEndian: raw)
            return Double(Float(bitPattern: val))
        case .double:
            let raw = ptr.loadUnaligned(fromByteOffset: offset, as: UInt64.self)
            let val = bigEndian ? UInt64(bigEndian: raw) : UInt64(littleEndian: raw)
            return Double(bitPattern: val)
        default:
            fatalError("Unsupported field type \(fieldType.rawValue) in fast read path")
        }
    }

    /// Get (and decompress) a tile or strip.
    private func tileOrStrip(
        x: Int, y: Int, sample: Int,
        tileWidth: Int, tileHeight: Int,
        cache: inout [Int: Data]
    ) throws(TIFFError) -> Data {
        guard let data = fileData else {
            throw .invalidArgument("Directory has no file data to read rasters from")
        }
        guard let imgWidth = imageWidth, let imgHeight = imageHeight else {
            throw .invalidData("Missing image dimensions")
        }

        let numTilesPerRow = (imgWidth + tileWidth - 1) / tileWidth
        let numTilesPerCol = (imgHeight + tileHeight - 1) / tileHeight

        let index: Int
        if planarConfig == .chunky {
            index = y * numTilesPerRow + x
        } else {
            index = sample * numTilesPerRow * numTilesPerCol + y * numTilesPerRow + x
        }

        if let cached = cache[index] {
            return cached
        }

        let offset: Int
        let byteCount: Int
        let offsets = isTiled ? tileOffsets : stripOffsets
        let counts = isTiled ? tileByteCounts : stripByteCounts
        guard let offsets, let counts else {
            throw .invalidData("Missing \(isTiled ? "tile" : "strip") offsets/byte counts")
        }
        guard offsets.indices.contains(index), counts.indices.contains(index) else {
            throw .invalidData(
                "\(isTiled ? "Tile" : "Strip") index \(index) out of range (\(offsets.count) offsets, \(counts.count) byte counts)"
            )
        }
        offset = offsets[index]
        byteCount = counts[index]

        var reader = ByteReader(data: data, byteOrder: fileByteOrder)
        reader.position = offset
        let compressedBytes = try reader.readBytes(byteCount)

        let compressionType = compression ?? .none
        let compressionCodec = try codec(for: compressionType)
        var decompressed = try compressionCodec.decode(compressedBytes, byteOrder: fileByteOrder)

        if let pred = predictor, pred != .none, let bps = bitsPerSample {
            decompressed = try Predictor.decode(
                data: decompressed,
                predictor: pred,
                width: tileWidth,
                height: tileHeight,
                bitsPerSample: bps,
                planarConfiguration: planarConfig
            )
        }

        cache[index] = decompressed

        return decompressed
    }

    /// Read a single sample value from decompressed block data.
    private func readSampleValue(
        reader: inout ByteReader,
        fieldType: FieldType
    ) throws(TIFFError) -> Double {
        switch fieldType {
        case .byte:
            return Double(try reader.readUInt8())
        case .short:
            return Double(try reader.readUInt16())
        case .long:
            return Double(try reader.readUInt32())
        case .sbyte:
            return Double(try reader.readInt8())
        case .sshort:
            return Double(try reader.readInt16())
        case .slong:
            return Double(try reader.readInt32())
        case .float:
            return Double(try reader.readFloat32())
        case .double:
            return try reader.readFloat64()
        default:
            throw .unsupportedFieldType(Int(fieldType.rawValue))
        }
    }

    /// Get the FieldType for a sample index based on sample format and bits per sample.
    public func fieldTypeForSample(_ sampleIndex: Int) throws(TIFFError) -> FieldType {
        let sampleFormatValue: Int
        if let sf = sampleFormat, !sf.isEmpty {
            sampleFormatValue = sampleIndex < sf.count ? sf[sampleIndex] : sf[0]
        } else {
            sampleFormatValue = Int(SampleFormat.unsignedInt.rawValue)
        }
        guard let bps = bitsPerSample else {
            throw .invalidData("Missing bitsPerSample")
        }
        guard bps.indices.contains(sampleIndex) else {
            throw .invalidData("No bitsPerSample value for sample \(sampleIndex)")
        }
        return try FieldType.from(sampleFormat: sampleFormatValue, bitsPerSample: bps[sampleIndex])
    }

    // MARK: - Size calculations

    /// Size in bytes of the IFD structure (header + entries + next offset).
    public var size: Int {
        TIFF.ifdHeaderBytes + (entries.count * TIFF.ifdEntryBytes) + TIFF.ifdOffsetBytes
    }

    /// Size in bytes including overflow values.
    public var sizeWithValues: Int {
        TIFF.ifdHeaderBytes + TIFF.ifdOffsetBytes
            + entries.values.reduce(0) { $0 + $1.sizeWithValues }
    }

    // MARK: - Private helpers

    private func intValue(for tag: FieldTagType) -> Int? {
        guard let entry = entries[tag] else { return nil }
        return Self.extractInt(from: entry.values)
    }

    private func uint16Value(for tag: FieldTagType) -> UInt16? {
        guard let entry = entries[tag] else { return nil }
        return Self.extractUInt16(from: entry.values)
    }

    private func intArray(for tag: FieldTagType) -> [Int]? {
        guard let entry = entries[tag] else { return nil }
        return Self.extractIntArray(from: entry.values)
    }

    static func extractInt(from value: EntryValue?) -> Int? {
        guard let value = value else { return nil }
        switch value {
        case .byte(let v): return Int(v)
        case .short(let v): return Int(v)
        case .long(let v): return Int(v)
        case .sbyte(let v): return Int(v)
        case .sshort(let v): return Int(v)
        case .slong(let v): return Int(v)
        case .float(let v): return Int(exactly: v.rounded(.towardZero))
        case .double(let v): return Int(exactly: v.rounded(.towardZero))
        default: return nil
        }
    }

    static func extractUInt16(from value: EntryValue?) -> UInt16? {
        guard let value = value else { return nil }
        switch value {
        case .byte(let v): return UInt16(v)
        case .short(let v): return v
        case .long(let v): return UInt16(exactly: v)
        default: return nil
        }
    }

    static func extractIntArray(from value: EntryValue?) -> [Int]? {
        guard let value = value else { return nil }
        switch value {
        case .array(let values):
            return values.compactMap { Self.extractInt(from: $0) }
        default:
            if let single = Self.extractInt(from: value) {
                return [single]
            }
            return nil
        }
    }

    // MARK: - Mutating setter helpers

    private mutating func setShortOrLongEntry(_ tag: FieldTagType, value: Int) {
        if let short = UInt16(exactly: value) {
            setShortEntry(tag, value: short)
        } else {
            guard let long = UInt32(exactly: value) else {
                preconditionFailure("\(tag) value \(value) does not fit in an unsigned 32-bit TIFF LONG")
            }
            setLongArrayEntry(tag, values: [long])
        }
    }

    private mutating func setShortEntry(_ tag: FieldTagType, value: UInt16) {
        let entry = FileDirectoryEntry(
            fieldTag: tag, fieldType: .short, typeCount: 1,
            values: .short(value)
        )
        entries[tag] = entry
    }

    private mutating func setShortArrayEntry(_ tag: FieldTagType, values: [UInt16]) {
        if values.count == 1 {
            setShortEntry(tag, value: values[0])
        } else {
            let entry = FileDirectoryEntry(
                fieldTag: tag, fieldType: .short, typeCount: values.count,
                values: .array(values.map { .short($0) })
            )
            entries[tag] = entry
        }
    }

    private mutating func setLongArrayEntry(_ tag: FieldTagType, values: [UInt32]) {
        if values.count == 1 {
            let entry = FileDirectoryEntry(
                fieldTag: tag, fieldType: .long, typeCount: 1,
                values: .long(values[0])
            )
            entries[tag] = entry
        } else {
            let entry = FileDirectoryEntry(
                fieldTag: tag, fieldType: .long, typeCount: values.count,
                values: .array(values.map { .long($0) })
            )
            entries[tag] = entry
        }
    }
}
