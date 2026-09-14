import Testing
@testable import SwiftTiff

struct ConstantsTests {

    // MARK: - TIFF namespace constants

    @Test func tiffFormatConstants() {
        #expect(TIFF.fileIdentifier == 42)
        #expect(TIFF.headerBytes == 8)
        #expect(TIFF.ifdHeaderBytes == 2)
        #expect(TIFF.ifdOffsetBytes == 4)
        #expect(TIFF.ifdEntryBytes == 12)
        #expect(TIFF.defaultMaxBytesPerStrip == 8000)
    }

    // MARK: - Compression raw values

    @Test func compressionRawValues() {
        #expect(Compression.none.rawValue == 1)
        #expect(Compression.ccittHuffman.rawValue == 2)
        #expect(Compression.t4.rawValue == 3)
        #expect(Compression.t6.rawValue == 4)
        #expect(Compression.lzw.rawValue == 5)
        #expect(Compression.jpegOld.rawValue == 6)
        #expect(Compression.jpegNew.rawValue == 7)
        #expect(Compression.deflate.rawValue == 8)
        #expect(Compression.packbits.rawValue == 32773)
    }

    @Test func compressionFromRawValue() {
        #expect(Compression(rawValue: 5) == .lzw)
        #expect(Compression(rawValue: 32773) == .packbits)
        #expect(Compression(rawValue: 999) == nil)
        // Verify deprecated PKZIP deflate (32946) is NOT a valid case
        #expect(Compression(rawValue: 32946) == nil)
    }

    // MARK: - SampleFormat raw values

    @Test func sampleFormatRawValues() {
        #expect(SampleFormat.unsignedInt.rawValue == 1)
        #expect(SampleFormat.signedInt.rawValue == 2)
        #expect(SampleFormat.float.rawValue == 3)
        #expect(SampleFormat.undefined.rawValue == 4)
    }

    // MARK: - PhotometricInterpretation raw values

    @Test func photometricInterpretationRawValues() {
        #expect(PhotometricInterpretation.whiteIsZero.rawValue == 0)
        #expect(PhotometricInterpretation.blackIsZero.rawValue == 1)
        #expect(PhotometricInterpretation.rgb.rawValue == 2)
        #expect(PhotometricInterpretation.palette.rawValue == 3)
        #expect(PhotometricInterpretation.transparency.rawValue == 4)
        #expect(PhotometricInterpretation.separated.rawValue == 5)
        #expect(PhotometricInterpretation.yCbCr.rawValue == 6)
        #expect(PhotometricInterpretation.cieLab.rawValue == 8)
        #expect(PhotometricInterpretation.iccLab.rawValue == 9)
        #expect(PhotometricInterpretation.ituLab.rawValue == 10)
    }

    // MARK: - PlanarConfiguration raw values

    @Test func planarConfigurationRawValues() {
        #expect(PlanarConfiguration.chunky.rawValue == 1)
        #expect(PlanarConfiguration.planar.rawValue == 2)
    }

    // MARK: - DifferencingPredictor raw values

    @Test func differencingPredictorRawValues() {
        #expect(DifferencingPredictor.none.rawValue == 1)
        #expect(DifferencingPredictor.horizontal.rawValue == 2)
        #expect(DifferencingPredictor.floatingPoint.rawValue == 3)
    }

    // MARK: - Spot-check remaining enums

    @Test func extraSamplesRawValues() {
        #expect(ExtraSamples.unspecified.rawValue == 0)
        #expect(ExtraSamples.associatedAlpha.rawValue == 1)
        #expect(ExtraSamples.unassociatedAlpha.rawValue == 2)
    }

    @Test func orientationRawValues() {
        #expect(Orientation.topRowLeftColumn.rawValue == 1)
        #expect(Orientation.leftRowBottomColumn.rawValue == 8)
        #expect(Orientation(rawValue: 0) == nil)
        #expect(Orientation(rawValue: 9) == nil)
    }

    @Test func resolutionUnitRawValues() {
        #expect(ResolutionUnit.none.rawValue == 1)
        #expect(ResolutionUnit.inch.rawValue == 2)
        #expect(ResolutionUnit.centimeter.rawValue == 3)
    }

    @Test func subfileTypeRawValues() {
        #expect(SubfileType.full.rawValue == 1)
        #expect(SubfileType.reduced.rawValue == 2)
        #expect(SubfileType.singlePageMultiPage.rawValue == 3)
    }

    @Test func fillOrderRawValues() {
        #expect(FillOrder.lowerColumnHigherOrder.rawValue == 1)
        #expect(FillOrder.lowerColumnLowerOrder.rawValue == 2)
    }

    @Test func thresholdingRawValues() {
        #expect(Thresholding.none.rawValue == 1)
        #expect(Thresholding.ordered.rawValue == 2)
        #expect(Thresholding.random.rawValue == 3)
    }

    @Test func grayResponseRawValues() {
        #expect(GrayResponse.tenths.rawValue == 1)
        #expect(GrayResponse.hundredThousandths.rawValue == 5)
    }
}
