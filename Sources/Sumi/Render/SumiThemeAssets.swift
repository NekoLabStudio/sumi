import Foundation

struct SumiResolvedAsset {
    var publicPath: String
    var kind: SumiResolvedAssetKind
}

enum SumiResolvedAssetKind {
    case external
    case publicPath
    case file(URL, publicPath: String?)
}
