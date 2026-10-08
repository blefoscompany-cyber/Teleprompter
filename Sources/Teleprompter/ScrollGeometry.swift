import CoreGraphics

struct ScrollGeometry: Equatable {
    let contentHeight: CGFloat
    let viewportHeight: CGFloat
    let topInset: CGFloat
    let bottomInset: CGFloat
    var minimum: CGFloat { -topInset }
    var maximum: CGFloat { max(minimum, contentHeight + bottomInset - viewportHeight) }
    var isReady: Bool { viewportHeight > 1 && contentHeight > 1 && maximum > minimum }
    func advanced(from offset: CGFloat, speed: Double, elapsed: Double) -> CGFloat {
        let position = min(maximum, max(minimum, offset))
        return min(maximum, position + CGFloat(max(0, speed) * min(0.1, max(0, elapsed))))
    }
}
