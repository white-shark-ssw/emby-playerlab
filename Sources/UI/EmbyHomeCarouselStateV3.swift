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
                suppressCarouselTap()
                guard transitionToID == nil || isCarouselDragging else { return }
                let direction = horizontal < 0 ? 1 : -1
                guard let currentID = currentCarouselItemID, let targetID = neighborCarouselItemID(from: currentID, direction: direction) else { return }
                if !isCarouselDragging || transitionFromID != currentID || transitionToID != targetID {
                    transitionFromID = currentID
                    transitionToID = targetID
                    transitionProgress = 0
                    transitionDirection = direction
                    isCarouselDragging = true
                }
                transitionProgress = min(1, max(0, abs(horizontal) / max(1, width)))
            }
            .onEnded { value in
                guard isCarouselDragging, let targetID = transitionToID else { return }
                suppressCarouselTap()
                let predicted = abs(value.predictedEndTranslation.width)
                let shouldCommit = transitionProgress >= 0.28 || predicted >= width * 0.48
                isCarouselDragging = false
                if shouldCommit { completeInteractiveTransition(to: targetID) }
                else { cancelInteractiveTransition() }
            }
    }

    func suppressCarouselTap() {
        carouselTapSuppressedUntil = Date().addingTimeInterval(0.30)
    }

    func openCurrentCarouselDetailIfAllowed() {
        guard transitionToID == nil, !isCarouselDragging, Date() >= carouselTapSuppressedUntil, let item = currentCarouselItem else { return }
        carouselDetailItem = item
        isCarouselDetailPresented = true
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
            transitionDirection = 1
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
        transitionDirection = 1
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
        transitionDirection = 1
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
            transitionDirection = 1
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
            transitionDirection = 1
            isCarouselDragging = false
            carouselLastSettledAt = Date()
        }
        carouselLogoByID = carouselLogoByID.filter { ids.contains($0.key) }
        carouselLogoResolvedIDs.formIntersection(ids)
        resolveCarouselLogosIfNeeded()
        onCarouselActiveChanged(true)
    }

    func resolveCarouselLogosIfNeeded() {
        for item in model.carouselItems where !carouselLogoResolvedIDs.contains(item.id) {
            let itemID = item.id
            carouselLogoResolvedIDs.insert(itemID)
            Task {
                do {
                    let infos = try await client.imageInfos(itemId: itemID)
                    guard let logo = infos.first(where: { $0.imageType.caseInsensitiveCompare("Logo") == .orderedSame }) else { return }
                    await MainActor.run {
                        guard model.carouselItems.contains(where: { $0.id == itemID }) else { return }
                        carouselLogoByID[itemID] = logo
                    }
                } catch {
                    if !isEmbyRequestCancellation(error) { DiagnosticsLogger.shared.log("HomeCarousel", "logo lookup failed item=\(itemID): \(error.localizedDescription)") }
                }
            }
        }
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
            let blend = carouselBackdropBlendProgress(transitionProgress)
            if itemID == fromID { return Double(1 - blend) }
            if itemID == toID { return Double(blend) }
            return 0
        }
        return itemID == currentCarouselItemID ? 1 : 0
    }

    func carouselForegroundOpacity(for itemID: String) -> Double {
        if let fromID = transitionFromID, let toID = transitionToID { return itemID == fromID || itemID == toID ? 1 : 0 }
        return itemID == currentCarouselItemID ? 1 : 0
    }

    func carouselBackdropBlendProgress(_ rawProgress: CGFloat) -> CGFloat {
        let raw = min(1, max(0, rawProgress))
        let delayed = min(1, max(0, (raw - 0.08) / 0.92))
        return delayed * delayed * (3 - 2 * delayed)
    }

    func carouselForegroundOffset(for itemID: String, width: CGFloat) -> CGFloat {
        guard let fromID = transitionFromID, let toID = transitionToID else { return 0 }
        let direction = CGFloat(transitionDirection)
        let progress = min(1, max(0, transitionProgress))
        if itemID == fromID { return -direction * progress * width }
        if itemID == toID { return direction * (1 - progress) * width }
        return 0
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

    func carouselLogoURL(_ item: LibraryItem) -> URL? {
        guard let logo = carouselLogoByID[item.id] else { return nil }
        return client.imageURL(itemId: item.id, imageType: "Logo", maxWidth: 900, index: logo.imageIndex)
    }

    func updateCarouselImageMetrics(_ image: UIImage, itemID: String) {
        if carouselSourceSizeByID[itemID] != image.size { carouselSourceSizeByID[itemID] = image.size }
        let prefersLight = EmbyImageContrastAnalyzer.prefersLightForeground(for: image)
        guard carouselLightForegroundByID[itemID] != prefersLight else { return }
        withAnimation(.easeOut(duration: 0.18)) { carouselLightForegroundByID[itemID] = prefersLight }
    }
}
