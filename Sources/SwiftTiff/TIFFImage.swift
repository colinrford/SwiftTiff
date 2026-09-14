import Foundation

/// TIFF image containing one or more file directories (IFDs).
///
/// Each file directory represents a sub-image (e.g., full resolution,
/// thumbnail, overview). Most TIFFs have a single directory.
public struct TIFFImage: Sendable {
    /// The file directories in this image.
    public var fileDirectories: [TIFFFileDirectory]

    /// Create an empty image.
    public init() {
        self.fileDirectories = []
    }

    /// Create an image with a single file directory.
    public init(fileDirectory: TIFFFileDirectory) {
        self.fileDirectories = [fileDirectory]
    }

    /// Create an image with multiple file directories.
    public init(fileDirectories: [TIFFFileDirectory]) {
        self.fileDirectories = fileDirectories
    }

    /// The first (default) file directory.
    public var fileDirectory: TIFFFileDirectory {
        fileDirectories[0]
    }

    /// Size in bytes of the TIFF header and all IFD structures (without overflow values).
    public var sizeHeaderAndDirectories: Int {
        TIFF.headerBytes + fileDirectories.reduce(0) { $0 + $1.size }
    }

    /// Size in bytes of the TIFF header and all IFD structures including overflow values.
    public var sizeHeaderAndDirectoriesWithValues: Int {
        TIFF.headerBytes + fileDirectories.reduce(0) { $0 + $1.sizeWithValues }
    }
}
