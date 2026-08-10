import SwiftUI

extension View {
    func frame(width: CGFloat, minHeight: CGFloat, alignment: Alignment = .center) -> some View {
        self.frame(width: width, alignment: alignment).frame(minHeight: minHeight, alignment: alignment)
    }
}
