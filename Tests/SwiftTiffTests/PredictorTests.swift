import Testing
import Foundation
@testable import SwiftTiff

struct PredictorTests {

    // MARK: - No predictor

    @Test func noPredictorPassthrough() throws {
        let input = Data([0x01, 0x02, 0x03, 0x04])
        let result = try Predictor.decode(
            data: input,
            predictor: .none,
            width: 2, height: 1,
            bitsPerSample: [8, 8],
            planarConfiguration: .chunky
        )
        #expect(result == input)
    }

    // MARK: - Horizontal predictor

    @Test func horizontalPredictorSingleSample8Bit() throws {
        // 4 pixels wide, 1 row, 1 sample, 8 bits
        // Encoded differences: [10, 5, 3, 2]
        // Decoded values: [10, 15, 18, 20]
        let input = Data([10, 5, 3, 2])
        let result = try Predictor.decode(
            data: input,
            predictor: .horizontal,
            width: 4, height: 1,
            bitsPerSample: [8],
            planarConfiguration: .chunky
        )
        #expect(result == Data([10, 15, 18, 20]))
    }

    @Test func horizontalPredictorRGBChunky() throws {
        // 3 pixels wide, 1 row, 3 samples (RGB), 8 bits
        // Encoded: [R0, G0, B0, dR1, dG1, dB1, dR2, dG2, dB2]
        // = [100, 50, 25, 10, 5, 3, 20, 10, 7]
        // Decoded: [100, 50, 25, 110, 55, 28, 130, 65, 35]
        let input = Data([100, 50, 25, 10, 5, 3, 20, 10, 7])
        let result = try Predictor.decode(
            data: input,
            predictor: .horizontal,
            width: 3, height: 1,
            bitsPerSample: [8, 8, 8],
            planarConfiguration: .chunky
        )
        #expect(result == Data([100, 50, 25, 110, 55, 28, 130, 65, 35]))
    }

    @Test func horizontalPredictorMultipleRows() throws {
        // 2 pixels wide, 2 rows, 1 sample, 8 bits
        // Row 0 encoded: [10, 5] → decoded: [10, 15]
        // Row 1 encoded: [20, 3] → decoded: [20, 23] (each row resets)
        let input = Data([10, 5, 20, 3])
        let result = try Predictor.decode(
            data: input,
            predictor: .horizontal,
            width: 2, height: 2,
            bitsPerSample: [8],
            planarConfiguration: .chunky
        )
        #expect(result == Data([10, 15, 20, 23]))
    }

    @Test func horizontalPredictorPlanar() throws {
        // Planar configuration: samples = 1 (each plane decoded independently)
        // 3 pixels wide, 1 row, 1 sample per plane
        let input = Data([100, 10, 20])
        let result = try Predictor.decode(
            data: input,
            predictor: .horizontal,
            width: 3, height: 1,
            bitsPerSample: [8, 8, 8],
            planarConfiguration: .planar
        )
        #expect(result == Data([100, 110, 130]))
    }

    @Test func horizontalPredictorWrapping() throws {
        // Test wrapping: 250 + 10 = 260, which wraps to 4 as UInt8 (260 - 256)
        // But the predictor works on signed bytes: Int8(250) = -6, Int8(10) = 10
        // -6 + 10 = 4, written as UInt8 = 4
        let input = Data([250, 10])
        let result = try Predictor.decode(
            data: input,
            predictor: .horizontal,
            width: 2, height: 1,
            bitsPerSample: [8],
            planarConfiguration: .chunky
        )
        // 250 as Int8 = -6; -6 + 10 = 4
        #expect(result == Data([250, 4]))
    }

    @Test func horizontalPredictor16Bit() throws {
        // 2 pixels wide, 1 row, 1 sample, 16 bits
        // Little-endian: [0x00, 0x01] = 256, [0x05, 0x00] = 5
        // Decoded: 256, 261 = [0x00, 0x01, 0x05, 0x01]
        let input = Data([0x00, 0x01, 0x05, 0x00])
        let result = try Predictor.decode(
            data: input,
            predictor: .horizontal,
            width: 2, height: 1,
            bitsPerSample: [16],
            planarConfiguration: .chunky
        )
        #expect(result == Data([0x00, 0x01, 0x05, 0x01]))
    }

    // MARK: - Floating-point predictor

    @Test func floatingPointPredictorBasic() throws {
        // 2 pixels wide, 1 row, 1 sample, 32 bits (4 bytes per sample)
        // Input (byte-planar, differenced): all zeros → all zeros after undiff
        // After rearrange: byte order reversed per sample
        let input = Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        let result = try Predictor.decode(
            data: input,
            predictor: .floatingPoint,
            width: 2, height: 1,
            bitsPerSample: [32],
            planarConfiguration: .chunky
        )
        #expect(result.count == 8)
        #expect(result == Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]))
    }

    // MARK: - Error cases

    @Test func nonMultipleOf8BitsThrows() {
        #expect(throws: TIFFError.self) {
            try Predictor.decode(
                data: Data([0x01]),
                predictor: .horizontal,
                width: 1, height: 1,
                bitsPerSample: [7],
                planarConfiguration: .chunky
            )
        }
    }

    @Test func unequalBitsPerSampleThrows() {
        #expect(throws: TIFFError.self) {
            try Predictor.decode(
                data: Data([0x01, 0x02, 0x03]),
                predictor: .horizontal,
                width: 1, height: 1,
                bitsPerSample: [8, 16],
                planarConfiguration: .chunky
            )
        }
    }

    // MARK: - Horizontal predictor 32-bit

    @Test func horizontalPredictor32Bit() throws {
        // 2 pixels wide, 1 row, 1 sample, 32 bits
        // Little-endian: [0x01, 0x00, 0x00, 0x00] = 1, [0x02, 0x00, 0x00, 0x00] = 2
        // Decoded: 1, 3 = [0x01, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00]
        let input = Data([0x01, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00])
        let result = try Predictor.decode(
            data: input,
            predictor: .horizontal,
            width: 2, height: 1,
            bitsPerSample: [32],
            planarConfiguration: .chunky
        )
        #expect(result == Data([0x01, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00]))
    }

    // MARK: - Floating-point predictor non-trivial

    @Test func floatingPointPredictorNonTrivial() throws {
        // 2 pixels wide, 1 row, 1 sample, 32 bits (4 bytes per sample)
        // samplesWidth = 2, bytesPerSample = 4
        //
        // Phase 1: Read 2*4=8 bytes, undo byte differencing (samples=1)
        // Input (byte-planar, differenced): [0x10, 0x05, 0x20, 0x03, 0x30, 0x01, 0x40, 0x02]
        // After undiff per byte position:
        //   Byte 0: decoded[0] = 0x10, decoded[1] = 0x10+0x05=0x15
        //   Byte 1: decoded[2] = 0x20, decoded[3] = 0x20+0x03=0x23
        //   Byte 2: decoded[4] = 0x30, decoded[5] = 0x30+0x01=0x31
        //   Byte 3: decoded[6] = 0x40, decoded[7] = 0x40+0x02=0x42
        //
        // Phase 2: Rearrange byte-planar → standard sample order
        //   Undifferencing accumulates across entire row (not per byte-plane):
        //     decoded = [0x10, 0x15, 0x35, 0x38, 0x68, 0x69, 0xA9, 0xAB]
        //   Phase 2 rearrange (reverse byte order per sample, samplesWidth=2):
        //     pixel 0: decoded[6]=0xA9, decoded[4]=0x68, decoded[2]=0x35, decoded[0]=0x10
        //     pixel 1: decoded[7]=0xAB, decoded[5]=0x69, decoded[3]=0x38, decoded[1]=0x15
        let input = Data([0x10, 0x05, 0x20, 0x03, 0x30, 0x01, 0x40, 0x02])
        let result = try Predictor.decode(
            data: input,
            predictor: .floatingPoint,
            width: 2, height: 1,
            bitsPerSample: [32],
            planarConfiguration: .chunky
        )
        #expect(result == Data([0xA9, 0x68, 0x35, 0x10, 0xAB, 0x69, 0x38, 0x15]))
    }

    // MARK: - Floating-point predictor with multiple samples

    @Test func floatingPointPredictorMultiSample() throws {
        // 2 pixels wide, 1 row, 2 samples, 32 bits (4 bytes per sample)
        // samplesWidth = 4, bytesPerSample = 4
        // 16 input bytes, 16 output bytes
        //
        // Phase 1 undifferencing accumulates per-sample across the row:
        //   decoded = [1,2, 1,2, 1,2, 1,2, 2,4, 2,4, 2,4, 2,4]
        // Phase 2 rearranges byte-planar → standard sample order
        let input = Data([1, 2, 0, 0, 0, 0, 0, 0, 1, 2, 0, 0, 0, 0, 0, 0])
        let result = try Predictor.decode(
            data: input,
            predictor: .floatingPoint,
            width: 2, height: 1,
            bitsPerSample: [32, 32],
            planarConfiguration: .chunky
        )
        #expect(result.count == 16)
        #expect(result == Data([2, 2, 1, 1, 4, 4, 2, 2, 2, 2, 1, 1, 4, 4, 2, 2]))
    }

    // MARK: - Truncated strip

    @Test func horizontalPredictorTruncatedStrip() throws {
        // height=3 declared, but data only contains 2 rows
        // Should decode the 2 available rows without crashing
        let input = Data([10, 5, 20, 3])  // 2 rows of 2 pixels
        let result = try Predictor.decode(
            data: input,
            predictor: .horizontal,
            width: 2, height: 3,
            bitsPerSample: [8],
            planarConfiguration: .chunky
        )
        #expect(result == Data([10, 15, 20, 23]))
    }

    // MARK: - Horizontal predictor multi-row with RGB

    @Test func horizontalPredictorMultiRowRGB() throws {
        // 2 pixels wide, 2 rows, 3 samples (RGB), 8 bits
        // Row 0: [100, 50, 25, 10, 5, 3] → [100, 50, 25, 110, 55, 28]
        // Row 1: [200, 100, 50, 20, 10, 5] → [200, 100, 50, 220, 110, 55]
        let input = Data([100, 50, 25, 10, 5, 3, 200, 100, 50, 20, 10, 5])
        let result = try Predictor.decode(
            data: input,
            predictor: .horizontal,
            width: 2, height: 2,
            bitsPerSample: [8, 8, 8],
            planarConfiguration: .chunky
        )
        #expect(result == Data([100, 50, 25, 110, 55, 28, 200, 100, 50, 220, 110, 55]))
    }

}
