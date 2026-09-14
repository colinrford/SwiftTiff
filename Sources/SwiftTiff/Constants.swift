/// TIFF format constants.
public enum TIFF {
    /// Magic number identifying a TIFF file (decimal 42).
    public static let fileIdentifier: UInt16 = 42
    /// Size of the TIFF file header in bytes.
    public static let headerBytes  = 8
    /// Size of the IFD entry count field.
    public static let ifdHeaderBytes = 2
    /// Size of the "next IFD offset" field.
    public static let ifdOffsetBytes = 4
    /// Size of a single IFD entry.
    public static let ifdEntryBytes  = 12
    /// Default max bytes per strip when writing.
    public static let defaultMaxBytesPerStrip = 8000
}

/// TIFF compression schemes.
public enum Compression: UInt16, Sendable {
    case none          = 1
    case ccittHuffman  = 2
    case t4            = 3
    case t6            = 4
    case lzw           = 5
    case jpegOld       = 6
    case jpegNew       = 7
    case deflate       = 8
    case packbits      = 32773
}

/// Extra samples interpretation.
public enum ExtraSamples: UInt16, Sendable {
    case unspecified        = 0
    case associatedAlpha    = 1
    case unassociatedAlpha  = 2
}

/// Photometric interpretation.
public enum PhotometricInterpretation: UInt16, Sendable {
    case whiteIsZero   = 0
    case blackIsZero   = 1
    case rgb           = 2
    case palette       = 3
    case transparency  = 4
    case separated     = 5
    case yCbCr         = 6
    case cieLab        = 8
    case iccLab        = 9
    case ituLab        = 10
}

/// Planar configuration.
public enum PlanarConfiguration: UInt16, Sendable {
    case chunky = 1
    case planar = 2
}

/// Sample format.
public enum SampleFormat: UInt16, Sendable {
    case unsignedInt = 1
    case signedInt   = 2
    case float       = 3
    case undefined   = 4
}

/// Resolution unit.
public enum ResolutionUnit: UInt16, Sendable {
    case none       = 1
    case inch       = 2
    case centimeter = 3
}

/// Orientation.
public enum Orientation: UInt16, Sendable {
    case topRowLeftColumn      = 1
    case topRowRightColumn     = 2
    case bottomRowRightColumn  = 3
    case bottomRowLeftColumn   = 4
    case leftRowTopColumn      = 5
    case rightRowTopColumn     = 6
    case rightRowBottomColumn  = 7
    case leftRowBottomColumn   = 8
}

/// Fill order.
public enum FillOrder: UInt16, Sendable {
    case lowerColumnHigherOrder = 1
    case lowerColumnLowerOrder  = 2
}

/// Thresholding.
public enum Thresholding: UInt16, Sendable {
    case none    = 1
    case ordered = 2
    case random  = 3
}

/// Differencing predictor.
public enum DifferencingPredictor: UInt16, Sendable {
    case none          = 1
    case horizontal    = 2
    case floatingPoint = 3
}

/// Subfile type.
public enum SubfileType: UInt16, Sendable {
    case full                = 1
    case reduced             = 2
    case singlePageMultiPage = 3
}

/// Gray response unit.
public enum GrayResponse: UInt16, Sendable {
    case tenths            = 1
    case hundredths        = 2
    case thousandths       = 3
    case tenThousandths    = 4
    case hundredThousandths = 5
}
