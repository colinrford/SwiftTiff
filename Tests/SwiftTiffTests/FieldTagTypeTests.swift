import Testing
@testable import SwiftTiff

struct FieldTagTypeTests {

    // MARK: - Raw value round-trips

    @Test func baselineTags() {
        #expect(FieldTagType(rawValue: 254) == .newSubfileType)
        #expect(FieldTagType(rawValue: 256) == .imageWidth)
        #expect(FieldTagType(rawValue: 257) == .imageLength)
        #expect(FieldTagType(rawValue: 258) == .bitsPerSample)
        #expect(FieldTagType(rawValue: 259) == .compression)
        #expect(FieldTagType(rawValue: 262) == .photometricInterpretation)
        #expect(FieldTagType(rawValue: 273) == .stripOffsets)
        #expect(FieldTagType(rawValue: 277) == .samplesPerPixel)
        #expect(FieldTagType(rawValue: 278) == .rowsPerStrip)
        #expect(FieldTagType(rawValue: 279) == .stripByteCounts)
        #expect(FieldTagType(rawValue: 282) == .xResolution)
        #expect(FieldTagType(rawValue: 296) == .resolutionUnit)
        #expect(FieldTagType(rawValue: 317) == .predictor)
        #expect(FieldTagType(rawValue: 339) == .sampleFormat)
    }

    @Test func tileTags() {
        #expect(FieldTagType(rawValue: 322) == .tileWidth)
        #expect(FieldTagType(rawValue: 323) == .tileLength)
        #expect(FieldTagType(rawValue: 324) == .tileOffsets)
        #expect(FieldTagType(rawValue: 325) == .tileByteCounts)
    }

    @Test func geoTiffTags() {
        #expect(FieldTagType(rawValue: 33550) == .modelPixelScale)
        #expect(FieldTagType(rawValue: 33922) == .modelTiepoint)
        #expect(FieldTagType(rawValue: 34264) == .modelTransformation)
        #expect(FieldTagType(rawValue: 34735) == .geoKeyDirectory)
        #expect(FieldTagType(rawValue: 34736) == .geoDoubleParams)
        #expect(FieldTagType(rawValue: 34737) == .geoAsciiParams)
    }

    @Test func exifTags() {
        #expect(FieldTagType(rawValue: 33434) == .exposureTime)
        #expect(FieldTagType(rawValue: 33437) == .fNumber)
        #expect(FieldTagType(rawValue: 34665) == .exifIFD)
        #expect(FieldTagType(rawValue: 36864) == .exifVersion)
        #expect(FieldTagType(rawValue: 40961) == .colorSpace)
    }

    @Test func rawValueRoundTrip() {
        let tag = FieldTagType.imageWidth
        #expect(FieldTagType(rawValue: tag.rawValue) == tag)
    }

    // MARK: - Unknown tags

    @Test func unknownTagReturnsNil() {
        #expect(FieldTagType(rawValue: 0) == nil)
        #expect(FieldTagType(rawValue: 1) == nil)
        #expect(FieldTagType(rawValue: 9999) == nil)
        #expect(FieldTagType(rawValue: 65535) == nil)
    }

    // MARK: - isArray

    @Test func arrayTags() {
        let arrayTags: [FieldTagType] = [
            .bitsPerSample, .extraSamples, .stripByteCounts, .stripOffsets,
            .sampleFormat, .stripRowCounts, .tileByteCounts, .tileOffsets,
            .jpegLosslessPredictors, .jpegPointTransforms,
            .jpegQTables, .jpegDCTables, .jpegACTables
        ]
        for tag in arrayTags {
            #expect(tag.isArray == true, "Expected \(tag) to be an array tag")
        }
    }

    @Test func nonArrayTags() {
        let nonArrayTags: [FieldTagType] = [
            .imageWidth, .imageLength, .compression, .photometricInterpretation,
            .samplesPerPixel, .rowsPerStrip, .planarConfiguration,
            .tileWidth, .tileLength, .predictor, .resolutionUnit,
            .artist, .copyright, .software, .dateTime,
            .geoKeyDirectory, .geoDoubleParams, .geoAsciiParams,
            .modelPixelScale, .modelTiepoint
        ]
        for tag in nonArrayTags {
            #expect(tag.isArray == false, "Expected \(tag) to NOT be an array tag")
        }
    }
}
