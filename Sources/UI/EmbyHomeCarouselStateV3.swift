import SwiftUI
import Combine
import UIKit

extension V3EmbyHomeView {
    func carouselDragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > abs(vertical) * 1.08, abs(horizontal) > 4 else { return }
                guard transitionToID == nil || isCarouselDragging else { return }
                guard let currentID = currentCarouselItemID, let targetID = neighborCarouselItemID(from: currentID, direction: horizontal < 0 ? 1 : -1) else { return }
                if !isCarouselDragging || transitionFromID != currentID || transitionToID != targetID {
                    transitionFromID = currentID
                    transitionToID = targetID
                    transitionProgress = 0
                    isCarouselDragging = true
                }
                transitionProgress = min(1, max(0, abs(horizontal) / max(1, width)))
            }
            .onEnded { value in
                guard isCarouselDragging, let targetID = transitionToID else { return }
                let predicted = abs(value.predictedEndTranslation.width)
                let shouldCommit = transitionProgress >= 0.28 || predicted >= width * 0.48
                isCarouselDragging = false
                if shouldCommit { completeInteractiveTransition(to: targetID) }
                else { cancelInteractiveTransition() }
            }
    }

    func completeInteractiveTransition(to targetID: String) {
        let fromID = transitionFromID
        withAnimation(.easeOut(duration: 0.22)) { transitionProgress = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.23) {
            guard transitionFromID == fromID, transitionToID == targetID else { return }
            settleCarousel(on: targetID)
        }
    }

    func cancelInteractiveTransition() {
        let fromID = transitionFromID
        let toID = transitionToID
        withAnimation(.easeOut(duration: 0.18)) { transitionProgress = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.19) {
            guard transitionFromID == fromID, transitionToID == toID, transitionProgress <= 0.001 else { return }
            transitionFromID = nil
            transitionToID = nil
            carouselLastSettledAt = Date()
        }
    }

    func autoAdvanceCarouselIfNeeded() {
        guard isHomeActive, !isCarouselDragging, transitionToID == nil, model.carouselItems.count > 1 else { return }
        guard Date().timeIntervalSince(carouselLastSettledAt) >= 6 else { return }
        guard let currentID = currentCarouselItemID, let targetID = neighborCarouselItemID(from: currentID, direction: 1) else { return }
        transitionFromID = currentID
        transitionToID = targetID
        transitionProgress = 0
        withAnimation(.easeInOut(duration: 0.62)) { transitionProgress = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.63) {
            guard transitionFromID == currentID, transitionToID == targetID else { return }
            settleCarousel(on: targetID)
        }
    }

    func settleCarousel(on itemID: String) {
        currentCarouselItemID = itemID
        transitionFromID = nil
        transitionToID = nil
        transitionProgress = 0
        isCarouselDragging = false
        carouselLastSettledAt = Date()
        DiagnosticsLogger.shared.log("HomeCarousel", "settled item=\(itemID)")
    }

    func synchronizeCarouselItems() {
        let items = model.carouselItems
        let ids = Set(items.map(\.id))
        if items.isEmpty {
            currentCarouselItemID = nil
            transitionFromID = nil
            transitionToID = nil
            transitionProgress = 0
            isCarouselDragging = false
            onCarouselActiveChanged(false)
            return
        }

        var needsTransitionReset = false
        if let currentID = currentCarouselItemID, ids.contains(currentID) {
        } else {
            currentCarouselItemID = items[0].id
            needsTransitionReset = true
        }
        if let fromID = transitionFromID, !ids.contains(fromID) { needsTransitionReset = true }
        if let toID = transitionToID, !ids.contains(toID) { needsTransitionReset = true }
        if (transitionFromID == nil) != (transitionToID == nil) { needsTransitionReset = true }
        if let fromID = transitionFromID, fromID != currentCarouselItemID { needsTransitionReset = true }
        if needsTransitionReset {
            transitionFromID = nil
            transitionToID = nil
            transitionProgress = 0
            isCarouselDragging = false
            carouselLastSettledAt = Date()
        }
        onCarouselActiveChanged(true)
    }

    var currentCarouselItem: LibraryItem? {
        guard let id = currentCarouselItemID else { return nil }
        return model.carouselItems.first { $0.id == id }
    }

    var transitionTargetCarouselItem: LibraryItem? {
        guard let id = transitionToID else { return nil }
        return model.carouselItems.first { $0.id == id }
    }

    var displayedCarouselItemID: String? {
        if let toID = transitionToID, transitionProgress >= 0.5 { return toID }
        return currentCarouselItemID
    }

    func carouselOpacity(for itemID: String) -> Double {
        if let fromID = transitionFromID, let toID = transitionToID {
            if itemID == fromID { return Double(1 - min(1, max(0, transitionProgress))) }
            if itemID == toID { return Double(min(1, max(0, transitionProgress))) }
            return 0
        }
        return itemID == currentCarouselItemID ? 1 : 0
    }

    func neighborCarouselItemID(from itemID: String, direction: Int) -> String? {
        let items = model.carouselItems
        guard items.count > 1, let index = items.firstIndex(where: { $0.id == itemID }) else { return nil }
        let next = (index + direction + items.count) % items.count
        return items[next].id
    }

    func carouselImageURL(_ item: LibraryItem) -> URL? {
        client.imageURL(itemId: item.preferredPrimaryImageItemId, maxWidth: 1400, tag: item.preferredPrimaryImageTag)
    }

    func updateCarouselImageMetrics(_ image: UIImage, itemID: String) {
        if carouselSourceSizeByID[itemID] != image.size { carouselSourceSizeByID[itemID] = image.size }
        let prefersLight = EmbyImageContrastAnalyzer.prefersLightForeground(for: image)
        guard carouselLightForegroundByID[itemID] != prefersLight else { return }
        withAnimation(.easeOut(duration: 0.18)) { carouselLightForegroundByID[itemID] = prefersLight }
    }

}
