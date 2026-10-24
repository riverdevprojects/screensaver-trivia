import Foundation

struct LocationCatalog {
    let locations: [Location]
    let error: String?

    init(bundle: Bundle = .main) {
        do {
            guard let url = bundle.url(forResource: "locations", withExtension: "json") else {
                throw CatalogError.missing
            }
            let data = try Data(contentsOf: url)
            locations = try JSONDecoder().decode([Location].self, from: data)
            error = nil
        } catch {
            locations = []
            self.error = "The location pack could not be loaded. Please reinstall the app."
        }
    }

    func location(_ id: String) -> Location? { locations.first { $0.id == id } }
    func count(in collection: Collection) -> Int {
        locations.filter { $0.collectionIDs.contains(collection.rawValue) }.count
    }
    static func mediaURL(_ id: String, extension ext: String) -> URL? {
        Bundle.main.url(forResource: id, withExtension: ext, subdirectory: "Media")
    }
    private enum CatalogError: Error { case missing }
}
