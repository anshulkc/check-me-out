import SwiftUI

extension Font {
    // Basic font with size
    static func tagesschrift(size: CGFloat) -> Font {
        return Font.custom("Tagesschrift-Regular", size: size)
    }
    
    // Common text styles
    static var tagesschriftTitle: Font {
        return tagesschrift(size: 24)
    }
    
    static var tagesschriftTitle2: Font {
        return tagesschrift(size: 22)
    }
    
    static var tagesschriftTitle3: Font {
        return tagesschrift(size: 20)
    }
    
    static var tagesschriftHeadline: Font {
        return tagesschrift(size: 18)
    }
    
    static var tagesschriftSubheadline: Font {
        return tagesschrift(size: 16)
    }
    
    static var tagesschriftBody: Font {
        return tagesschrift(size: 14)
    }
    
    static var tagesschriftCaption: Font {
        return tagesschrift(size: 12)
    }
}
