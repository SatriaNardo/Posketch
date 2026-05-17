import SwiftUI

struct ARContext: Identifiable {
    let id = UUID()
    var image: UIImage? = nil
}

struct PoseModel: Identifiable, Hashable {
    let id = UUID()
    let poseName: String
    let category: String
    //let backgroundImage: UIImage?
    let thumbnailImage: UIImage?
    let fileURL: URL?
    let dateAdded: Date
}

enum SortType: String, CaseIterable {
    case newest = "Newest First"
    case oldest = "Oldest First"
    case az = "A to Z"
    case za = "Z to A"
}
