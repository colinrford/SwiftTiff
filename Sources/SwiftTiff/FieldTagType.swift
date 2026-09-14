/// IFD field tag identifiers per TIFF 6.0 + GeoTIFF + EXIF extensions.
public enum FieldTagType: UInt16, Sendable, Hashable {
    // ── Baseline TIFF 6.0 ──
    case newSubfileType              = 254
    case subfileType                 = 255
    case imageWidth                  = 256
    case imageLength                 = 257
    case bitsPerSample               = 258
    case compression                 = 259
    case photometricInterpretation   = 262
    case thresholding                = 263
    case cellWidth                   = 264
    case cellLength                  = 265
    case fillOrder                   = 266
    case documentName                = 269
    case imageDescription            = 270
    case make                        = 271
    case model                       = 272
    case stripOffsets                = 273
    case orientation                 = 274
    case samplesPerPixel             = 277
    case rowsPerStrip                = 278
    case stripByteCounts             = 279
    case minSampleValue              = 280
    case maxSampleValue              = 281
    case xResolution                 = 282
    case yResolution                 = 283
    case planarConfiguration         = 284
    case pageName                    = 285
    case xPosition                   = 286
    case yPosition                   = 287
    case freeOffsets                 = 288
    case freeByteCounts              = 289
    case grayResponseUnit            = 290
    case grayResponseCurve           = 291
    case t4Options                   = 292
    case t6Options                   = 293
    case resolutionUnit              = 296
    case pageNumber                  = 297
    case transferFunction            = 301
    case software                    = 305
    case dateTime                    = 306
    case artist                      = 315
    case hostComputer                = 316
    case predictor                   = 317
    case whitePoint                  = 318
    case primaryChromaticities       = 319
    case colorMap                    = 320
    case halftoneHints               = 321
    case tileWidth                   = 322
    case tileLength                  = 323
    case tileOffsets                 = 324
    case tileByteCounts              = 325
    case badFaxLines                 = 326
    case cleanFaxData                = 327
    case consecutiveBadFaxLines      = 328
    case subIFDs                     = 330
    case dotRange                    = 336
    case extraSamples                = 338
    case sampleFormat                = 339
    case sMinSampleValue             = 340
    case sMaxSampleValue             = 341
    case clipPath                    = 343
    case xClipPathUnits              = 344
    case yClipPathUnits              = 345
    case indexed                     = 346
    case jpegTables                  = 347
    case decode                      = 433
    case defaultImageColor           = 434
    // ── JPEG (old-style) ──
    case jpegProc                    = 512
    case jpegInterchangeFormat       = 513
    case jpegInterchangeFormatLength = 514
    case jpegRestartInterval         = 515
    case jpegLosslessPredictors      = 517
    case jpegPointTransforms         = 518
    case jpegQTables                 = 519
    case jpegDCTables                = 520
    case jpegACTables                = 521
    // ── YCbCr ──
    case yCbCrCoefficients           = 529
    case yCbCrSubSampling            = 530
    case yCbCrPositioning            = 531
    case referenceBlackWhite         = 532
    // ── Misc extensions ──
    case stripRowCounts              = 559
    case xmp                         = 700
    // ── Copyright ──
    case copyright                   = 33432
    // ── EXIF ──
    case exposureTime                = 33434
    case fNumber                     = 33437
    // ── GeoTIFF ──
    case modelPixelScale             = 33550
    case iptc                        = 33723
    case modelTiepoint               = 33922
    case modelTransformation         = 34264
    case photoshop                   = 34377
    case exifIFD                     = 34665
    case iccProfile                  = 34675
    // ── GeoTIFF keys ──
    case geoKeyDirectory             = 34735
    case geoDoubleParams             = 34736
    case geoAsciiParams              = 34737
    // ── EXIF tags (continued) ──
    case exifVersion                 = 36864
    case dateTimeOriginal            = 36867
    case dateTimeDigitized           = 36868
    case shutterSpeedValue           = 37377
    case apertureValue               = 37378
    case lightSource                 = 37384
    case flash                       = 37385
    case makerNote                   = 37500
    case userComment                 = 37510
    case flashpixVersion             = 40960
    case colorSpace                  = 40961
    case fileSource                  = 41728
    case imageUniqueID               = 42016
    // ── GDAL ──
    case gdalMetadata                = 42112
    case gdalNodata                  = 42113

    /// Whether this tag's value is always an array (even for count=1).
    public var isArray: Bool {
        switch self {
        case .bitsPerSample, .extraSamples, .stripByteCounts, .stripOffsets,
             .sampleFormat, .stripRowCounts, .tileByteCounts, .tileOffsets,
             .jpegLosslessPredictors, .jpegPointTransforms,
             .jpegQTables, .jpegDCTables, .jpegACTables:
            return true
        default:
            return false
        }
    }
}
