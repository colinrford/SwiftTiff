import Foundation
import Testing
@testable import SwiftTiff

enum TestFile: String {
    case stripped = "stripped"
    case tiled = "tiled"
    case int32 = "int32"
    case uint32 = "uint32"
    case float32 = "float32"
    case float64 = "float64"
    case lzw = "lzw"
    case packbits = "packbits"
    case interleave = "interleave"
    case tiledPlanar = "tiledplanar"
    case tiledPlanarLzw = "tiledplanarlzw"
    case lzwPredictor = "lzw_predictor"
    case lzwPredictorFloating = "lzw_predictor_floating"
    case jpeg = "quad-jpeg"
    case rgb = "rgb"
    case small = "small"
    case overviews = "overviews"
    case deflate = "deflate"

    var url: URL {
        Bundle.module.url(
            forResource: rawValue,
            withExtension: rawValue == "quad-jpeg" ? "tif" : "tiff",
            subdirectory: "Fixtures"
        )!
    }
}

/// Compare pixel values between two TIFFImages.
func compareTIFFImages(
    _ image1: TIFFImage,
    _ image2: TIFFImage,
    exactType: Bool = true,
    sameBitsPerSample: Bool = true
) throws {
    let dir1 = image1.fileDirectory
    let dir2 = image2.fileDirectory

    let width = dir1.imageWidth!
    let height = dir1.imageHeight!
    #expect(width == dir2.imageWidth!)
    #expect(height == dir2.imageHeight!)

    let rasters1 = try dir1.readRasters()
    let rasters2 = try dir2.readRasters()

    let spp = min(dir1.samplesPerPixel, dir2.samplesPerPixel)
    var mismatches = 0
    var firstMismatch: (x: Int, y: Int, s: Int, v1: Double, v2: Double)?

    for y in 0..<height {
        for x in 0..<width {
            let px1 = rasters1.pixel(x: x, y: y)
            let px2 = rasters2.pixel(x: x, y: y)
            for s in 0..<spp {
                if px1[s] != px2[s] {
                    mismatches += 1
                    if firstMismatch == nil {
                        firstMismatch = (x, y, s, px1[s], px2[s])
                    }
                }
            }
        }
    }

    if let m = firstMismatch {
        Issue.record("Pixel mismatch: \(mismatches) total. First at (\(m.x),\(m.y)) sample \(m.s): \(m.v1) vs \(m.v2)")
    }
}

/// Compare planar sample values between two Rasters.
func compareRastersSampleValues(_ r1: TIFFRasters, _ r2: TIFFRasters) {
    #expect(r1.width == r2.width)
    #expect(r1.height == r2.height)

    var mismatches = 0
    var firstMismatch: (x: Int, y: Int, s: Int, v1: Double, v2: Double)?

    for y in 0..<r1.height {
        for x in 0..<r1.width {
            let px1 = r1.pixel(x: x, y: y)
            let px2 = r2.pixel(x: x, y: y)
            for s in 0..<min(px1.count, px2.count) {
                if px1[s] != px2[s] {
                    mismatches += 1
                    if firstMismatch == nil {
                        firstMismatch = (x, y, s, px1[s], px2[s])
                    }
                }
            }
        }
    }
    if let m = firstMismatch {
        Issue.record("Sample mismatch: \(mismatches) total. First at (\(m.x),\(m.y)) sample \(m.s): \(m.v1) vs \(m.v2)")
    }
}

/// Compare interleaved values between two Rasters.
func compareRastersInterleaveValues(_ r1: TIFFRasters, _ r2: TIFFRasters) {
    #expect(r1.width == r2.width)
    #expect(r1.height == r2.height)
    #expect(r1.hasInterleaveValues)
    #expect(r2.hasInterleaveValues)

    var mismatches = 0
    var firstMismatch: (x: Int, y: Int, s: Int, v1: Double, v2: Double)?

    for y in 0..<r1.height {
        for x in 0..<r1.width {
            let px1 = r1.pixel(x: x, y: y)
            let px2 = r2.pixel(x: x, y: y)
            for s in 0..<min(px1.count, px2.count) {
                if px1[s] != px2[s] {
                    mismatches += 1
                    if firstMismatch == nil {
                        firstMismatch = (x, y, s, px1[s], px2[s])
                    }
                }
            }
        }
    }
    if let m = firstMismatch {
        Issue.record("Interleave mismatch: \(mismatches) total. First at (\(m.x),\(m.y)) sample \(m.s): \(m.v1) vs \(m.v2)")
    }
}
