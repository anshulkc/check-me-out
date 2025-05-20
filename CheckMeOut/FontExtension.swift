import SwiftUI

extension Font {
    // Basic font with size
    static func tagesschrift(size: CGFloat) -> Font {
        return Font.custom("Tagesschrift-Regular", size: size)
    }
    
    static func bricolage(size: CGFloat) -> Font {
        return Font.custom("BricolageGrotesque_24pt-Regular", size: size)
    }
    
    static func poetsen(size: CGFloat) -> Font {
        return Font.custom("PoetsenOne-Regular", size: size)
    }
    
    static func lexend(size: CGFloat) -> Font {
        return Font.custom("Lexend-VariableFont_wght", size: size)
    }
    
    static func lato(size: CGFloat) -> Font {
        return Font.custom("Lato-Regular", size: size)
    }
    
    static func quicksand(size: CGFloat) -> Font {
        return Font.custom("Quicksand-Regular", size: size)
    }

    // Common text styles
    static var tagesschriftTitle: Font {
        return quicksand(size: 24)
    }
    
    static var tagesschriftTitle2: Font {
        return quicksand(size: 22)
    }
    
    static var tagesschriftTitle3: Font {
        return quicksand(size: 20)
    }
    
    static var tagesschriftHeadline: Font {
        return quicksand(size: 18)
    }
    
    static var tagesschriftSubheadline: Font {
        return poetsen(size: 16)
    }
    
    static var tagesschriftBody: Font {
        return poetsen(size: 14)
    }
    
    static var tagesschriftCaption: Font {
        return poetsen(size: 12)
    }
}
