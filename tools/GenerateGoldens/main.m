//
//  main.m
//  GenerateGoldens
//
//  Decodes each fixture TIFF with the ObjC reference implementation
//  (NGA tiff-ios) and writes a golden JSON file matching the schema in
//  Tests/SwiftTiffTests/ParityGolden.swift.
//
//  Built and run by generate.sh; not part of the Swift package.
//

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import <TIFF/TIFFReader.h>
#import <TIFF/TIFFImage.h>
#import <TIFF/TIFFFileDirectory.h>
#import <TIFF/TIFFFileDirectoryEntry.h>
#import <TIFF/TIFFRasters.h>
#import <TIFF/TIFFFieldTagTypes.h>
#import <TIFF/TIFFFieldTypes.h>

static NSString * const kGenerator = @"tiff-ios 4.0.3";

#pragma mark - Exact doubles

// NSJSONSerialization does not print doubles with round-trip precision, so
// doubles are carried through serialization as tagged strings and spliced
// back in as the shortest representation that parses to the same value.
static NSString * const kDoublePrefix = @"__double:";

static NSString *jsonDouble(double value) {
    char buf[32];
    for (int precision = 1; precision <= 17; precision++) {
        snprintf(buf, sizeof buf, "%.*g", precision, value);
        if (strtod(buf, NULL) == value) {
            break;
        }
    }
    return [NSString stringWithFormat:@"%@%s", kDoublePrefix, buf];
}

static NSData *spliceDoubles(NSData *json) {
    NSString *text = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
    NSString *pattern = [NSString stringWithFormat:@"\"%@([^\"]*)\"", kDoublePrefix];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    text = [regex stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"$1"];
    return [text dataUsingEncoding:NSUTF8StringEncoding];
}

#pragma mark - Entries

/// Flatten an entry's values into the golden { ints | doubles | strings } shape.
static NSDictionary *goldenValues(TIFFFileDirectoryEntry *entry) {
    NSObject *values = [entry values];
    NSArray *list = [values isKindOfClass:[NSArray class]] ? (NSArray *)values : @[values];

    switch ([entry fieldType]) {
        case TIFF_FIELD_ASCII:
            return @{ @"strings": list };
        case TIFF_FIELD_FLOAT:
        case TIFF_FIELD_DOUBLE: {
            // Widen FLOAT to double, matching Double(Float) on the Swift side.
            NSMutableArray *doubles = [NSMutableArray arrayWithCapacity:list.count];
            for (NSNumber *n in list) {
                [doubles addObject:jsonDouble([n doubleValue])];
            }
            return @{ @"doubles": doubles };
        }
        default: {
            NSMutableArray *ints = [NSMutableArray arrayWithCapacity:list.count];
            for (NSNumber *n in list) {
                [ints addObject:[NSNumber numberWithLongLong:[n longLongValue]]];
            }
            return @{ @"ints": ints };
        }
    }
}

static NSArray *goldenEntries(TIFFFileDirectory *dir) {
    NSArray<TIFFFileDirectoryEntry *> *sorted = [[[dir entries] array]
        sortedArrayUsingComparator:^NSComparisonResult(TIFFFileDirectoryEntry *a, TIFFFileDirectoryEntry *b) {
            int ta = [TIFFFieldTagTypes tagId:[a fieldTag]];
            int tb = [TIFFFieldTagTypes tagId:[b fieldTag]];
            return ta < tb ? NSOrderedAscending : (ta > tb ? NSOrderedDescending : NSOrderedSame);
        }];

    NSMutableArray *out = [NSMutableArray array];
    for (TIFFFileDirectoryEntry *entry in sorted) {
        [out addObject:@{
            @"tag": @([TIFFFieldTagTypes tagId:[entry fieldTag]]),
            @"type": @([TIFFFieldTypes value:[entry fieldType]]),
            @"count": @([entry typeCount]),
            @"scalar": [[entry values] isKindOfClass:[NSArray class]] ? @NO : @YES,
            @"values": goldenValues(entry)
        }];
    }
    return out;
}

static void setIfPresent(NSMutableDictionary *dict, NSString *key, id value) {
    if (value != nil) {
        dict[key] = value;
    }
}

static NSDictionary *goldenDirectory(TIFFFileDirectory *dir) {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"width"] = [dir imageWidth] ?: @0;
    d[@"height"] = [dir imageHeight] ?: @0;
    d[@"bitsPerSample"] = [dir bitsPerSample] ?: @[];
    d[@"samplesPerPixel"] = @([dir samplesPerPixel]);
    d[@"compression"] = [dir compression] ?: @1;
    d[@"photometricInterpretation"] = [dir photometricInterpretation] ?: @0;
    d[@"planarConfiguration"] = [dir planarConfiguration] ?: @1;
    setIfPresent(d, @"rowsPerStrip", [dir rowsPerStrip]);
    setIfPresent(d, @"tileWidth", [dir tileWidth]);
    setIfPresent(d, @"tileHeight", [dir tileHeight]);
    setIfPresent(d, @"stripOffsets", [dir stripOffsets]);
    setIfPresent(d, @"stripByteCounts", [dir stripByteCounts]);
    d[@"entries"] = goldenEntries(dir);
    return d;
}

#pragma mark - Rasters

static void appendLE(NSMutableData *data, uint64_t v, int bytes) {
    uint8_t buf[8];
    for (int i = 0; i < bytes; i++) {
        buf[i] = (uint8_t)((v >> (i * 8)) & 0xFF);
    }
    [data appendBytes:buf length:bytes];
}

/// Canonical little-endian encoding of one sample, mirroring
/// appendCanonical in ParityTests.swift.
static void appendCanonical(NSMutableData *data, NSNumber *value, int bitsPerSample, int sampleFormat) {
    if (sampleFormat == 3 && bitsPerSample == 32) {
        uint32_t bits;
        float f = [value floatValue];
        memcpy(&bits, &f, 4);
        appendLE(data, bits, 4);
    } else if (sampleFormat == 3 && bitsPerSample == 64) {
        uint64_t bits;
        double f = [value doubleValue];
        memcpy(&bits, &f, 8);
        appendLE(data, bits, 8);
    } else if (sampleFormat == 2) {
        appendLE(data, (uint64_t)[value longLongValue], bitsPerSample / 8);
    } else if (bitsPerSample == 8 || bitsPerSample == 16 || bitsPerSample == 32) {
        appendLE(data, [value unsignedLongLongValue], bitsPerSample / 8);
    } else {
        [NSException raise:@"Unsupported" format:@"sampleFormat=%d bitsPerSample=%d", sampleFormat, bitsPerSample];
    }
}

static NSString *hex(const unsigned char *digest) {
    NSMutableString *s = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [s appendFormat:@"%02x", digest[i]];
    }
    return s;
}

static NSDictionary *goldenRasters(TIFFFileDirectory *dir, TIFFRasters *rasters) {
    int w = [rasters width];
    int h = [rasters height];
    int samples = [rasters samplesPerPixel];
    NSArray<NSNumber *> *formats = [dir sampleFormat];

    NSMutableArray *hashes = [NSMutableArray array];
    for (int s = 0; s < samples; s++) {
        int bits = [[rasters bitsPerSample][s] intValue];
        int format = formats != nil ? [formats[s] intValue] : 1;
        NSMutableData *bytes = [NSMutableData dataWithCapacity:w * h * (bits / 8)];
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                appendCanonical(bytes, [rasters pixelSampleAtSample:s andX:x andY:y], bits, format);
            }
        }
        unsigned char digest[CC_SHA256_DIGEST_LENGTH];
        CC_SHA256(bytes.bytes, (CC_LONG)bytes.length, digest);
        [hashes addObject:hex(digest)];
    }

    // Same coordinates as buildSpotChecks in ParityBootstrap.swift:
    // corners, center, then one point per strip/tile boundary.
    NSMutableArray<NSArray<NSNumber *> *> *coords = [NSMutableArray arrayWithArray:@[
        @[@0, @0], @[@(w - 1), @0], @[@0, @(h - 1)], @[@(w - 1), @(h - 1)], @[@(w / 2), @(h / 2)]
    ]];
    if ([dir isTiled] && [[dir tileWidth] intValue] > 0 && [[dir tileHeight] intValue] > 0) {
        int tw = [[dir tileWidth] intValue];
        int th = [[dir tileHeight] intValue];
        for (int y = th; y < h; y += th) {
            for (int x = 0; x < w; x += tw) {
                [coords addObject:@[@(x), @(y)]];
            }
        }
    } else if ([[dir rowsPerStrip] intValue] > 0) {
        int rps = [[dir rowsPerStrip] intValue];
        for (int y = rps; y < h; y += rps) {
            [coords addObject:@[@0, @(y)]];
        }
    }

    NSMutableArray *spots = [NSMutableArray array];
    for (NSArray<NSNumber *> *c in coords) {
        int x = [c[0] intValue];
        int y = [c[1] intValue];
        for (int s = 0; s < samples; s++) {
            [spots addObject:@{
                @"x": @(x), @"y": @(y), @"sample": @(s),
                @"value": jsonDouble([[rasters pixelSampleAtSample:s andX:x andY:y] doubleValue])
            }];
        }
    }

    return @{ @"sha256PerSample": hashes, @"spotChecks": spots };
}

#pragma mark - Main

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 3) {
            fprintf(stderr, "usage: %s <fixtures-dir> <goldens-dir>\n", argv[0]);
            return 2;
        }
        NSString *fixturesDir = [NSString stringWithUTF8String:argv[1]];
        NSString *goldensDir = [NSString stringWithUTF8String:argv[2]];
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm createDirectoryAtPath:goldensDir withIntermediateDirectories:YES attributes:nil error:nil];

        NSArray *names = [[fm contentsOfDirectoryAtPath:fixturesDir error:nil]
            sortedArrayUsingSelector:@selector(compare:)];
        int failures = 0;

        for (NSString *name in names) {
            NSString *ext = [name pathExtension];
            if (![ext isEqualToString:@"tiff"] && ![ext isEqualToString:@"tif"]) {
                continue;
            }
            @autoreleasepool {
                NSString *path = [fixturesDir stringByAppendingPathComponent:name];
                NSMutableArray *images = [NSMutableArray array];
                @try {
                    TIFFImage *tiff = [TIFFReader readTiffFromFile:path];
                    NSArray *dirs = [tiff fileDirectories];
                    for (NSUInteger i = 0; i < dirs.count; i++) {
                        TIFFFileDirectory *dir = dirs[i];
                        NSMutableDictionary *image = [NSMutableDictionary dictionary];
                        image[@"index"] = @(i);
                        image[@"directory"] = goldenDirectory(dir);
                        // Rasters are omitted when the reference cannot decode
                        // them (e.g. JPEG compression); directory parity still applies.
                        @try {
                            image[@"rasters"] = goldenRasters(dir, [dir readRasters]);
                        } @catch (NSException *e) {
                            printf("  %s[%lu]: no rasters (%s)\n", name.UTF8String, (unsigned long)i, e.reason.UTF8String);
                        }
                        [images addObject:image];
                    }
                } @catch (NSException *e) {
                    fprintf(stderr, "FAILED %s: %s\n", name.UTF8String, e.reason.UTF8String);
                    failures++;
                    continue;
                }

                NSDictionary *golden = @{ @"source": name, @"generator": kGenerator, @"images": images };
                NSError *error = nil;
                NSData *json = [NSJSONSerialization dataWithJSONObject:golden
                                                               options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                                 error:&error];
                NSString *out = [goldensDir stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"json"]];
                if (json == nil || ![spliceDoubles(json) writeToFile:out atomically:YES]) {
                    fprintf(stderr, "FAILED writing %s: %s\n", out.UTF8String, error.description.UTF8String);
                    failures++;
                    continue;
                }
                printf("wrote %s\n", out.UTF8String);
            }
        }
        return failures == 0 ? 0 : 1;
    }
}
