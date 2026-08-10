import Foundation

struct EmbyImageInfo: Decodable, Hashable, Identifiable {
    let imageType: String
    let imageIndex: Int?
    let path: String?
    let filename: String?
    let height: Int?
    let width: Int?
    let size: Int64?

    var id: String { "\(imageType)|\(imageIndex ?? 0)|\(filename ?? path ?? "")" }

    enum CodingKeys: String, CodingKey {
        case imageType = "ImageType"
        case imageIndex = "ImageIndex"
        case path = "Path"
        case filename = "Filename"
        case height = "Height"
        case width = "Width"
        case size = "Size"
    }
}
