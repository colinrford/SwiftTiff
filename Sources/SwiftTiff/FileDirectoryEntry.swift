import Foundation

/// Typed value stored in an IFD entry.
public enum EntryValue: Sendable, Equatable {
    case byte(UInt8)
    case ascii(String)
    case short(UInt16)
    case long(UInt32)
    case rational(numerator: UInt32, denominator: UInt32)
    case sbyte(Int8)
    case undefined(Data)
    case sshort(Int16)
    case slong(Int32)
    case srational(numerator: Int32, denominator: Int32)
    case float(Float)
    case double(Double)
    case array([EntryValue])
}

/// A single TIFF Image File Directory entry.
public struct FileDirectoryEntry: Sendable {
    /// The tag identifying this entry.
    public let fieldTag: FieldTagType
    /// The data type of the entry's values.
    public let fieldType: FieldType
    /// The number of values.
    public let typeCount: Int
    /// The entry's value(s).
    public let values: EntryValue

    public init(
        fieldTag: FieldTagType,
        fieldType: FieldType,
        typeCount: Int,
        values: EntryValue
    ) {
        self.fieldTag = fieldTag
        self.fieldType = fieldType
        self.typeCount = typeCount
        self.values = values
    }

    /// Total size in bytes: the 12-byte IFD entry + any overflow values.
    /// ObjC: `sizeWithValues` → `TIFF_IFD_ENTRY_BYTES + sizeOfValues`
    public var sizeWithValues: Int {
        TIFF.ifdEntryBytes + sizeOfValues
    }

    /// Size of values that don't fit in the 12-byte IFD entry.
    /// Per TIFF spec: if `fieldType.byteCount * typeCount <= 4`, values fit inline
    /// and this returns 0. Otherwise returns the full value byte count.
    /// ObjC: `sizeOfValues`
    public var sizeOfValues: Int {
        let valueBytes = fieldType.byteCount * typeCount
        return valueBytes > 4 ? valueBytes : 0
    }
}
