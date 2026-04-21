// BikeLanes/Services/ExifService.swift
import Foundation
import ImageIO
import CoreLocation

struct PhotoMetadata {
    var coordinates: CLLocationCoordinate2D?
    var horizontalAccuracy: Double?
    var heading: CLLocationDirection?
    var observedAt: Date?
}

struct ExifService {
    enum Error: Swift.Error { case cannotReadImage }

    func read(url: URL) throws -> PhotoMetadata {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any]
        else { throw Error.cannotReadImage }

        var meta = PhotoMetadata()

        // GPS
        if let gps = props[kCGImagePropertyGPSDictionary as String] as? [String: Any],
           let lat = gps[kCGImagePropertyGPSLatitude as String] as? Double,
           let lng = gps[kCGImagePropertyGPSLongitude as String] as? Double {
            let latRef = (gps[kCGImagePropertyGPSLatitudeRef as String] as? String) ?? "N"
            let lngRef = (gps[kCGImagePropertyGPSLongitudeRef as String] as? String) ?? "E"
            meta.coordinates = .init(
                latitude:  latRef == "S" ? -lat : lat,
                longitude: lngRef == "W" ? -lng : lng
            )
            meta.horizontalAccuracy = gps[kCGImagePropertyGPSHPositioningError as String] as? Double
            if let dir = gps[kCGImagePropertyGPSImgDirection as String] as? Double {
                meta.heading = dir
            }
        }

        // Exif date/time
        if let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let str = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            let f = DateFormatter()
            f.dateFormat = "yyyy:MM:dd HH:mm:ss"
            f.timeZone = .current
            meta.observedAt = f.date(from: str)
        }

        return meta
    }
}
