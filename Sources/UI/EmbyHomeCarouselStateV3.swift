import SwiftUI
import UIKit

final class V3HomeCarouselRuntimeState {
    var currentID: String?
    var fromID: String?
    var toID: String?
    var progress: CGFloat = 0
    var direction = 1
    var isDragging = false
    var tapSuppressedUntil = Date.distantPast
    var lastSettledAt = Date()

    private var itemIDs: [String] = []
    private var dragOriginSignedProgress: CGFloat = 0
    private var animationToken: UInt64 = 0
    private var committedTargetID: String?
    private var trailingID: String?
    private var rebasedCommittedDrag = false
    private weak var presentation: V3HomeCarouselPresentationBridge?

    init(currentID: String? = nil) { self.currentID = currentID }

    func bind(presentation: V3HomeCarouselPresentationBridge) {
        self.presentation = presentation
        presentation.present(visualState)
    }

    func synchronize(itemIDs: [String]) {
        self.itemIDs = itemIDs
        guard !itemIDs.isEmpty else {
            invalidateAnimation()
            currentID = nil
            fromID = nil
            toID = nil
            progress = 0
            direction = 1
            trailingID = nil
            rebasedCommittedDrag = false
            isDragging = false
            presentation?.stopAnimationAndPresent(visualState)
            return
        }

        var needsReset = false
        if let currentID, itemIDs.contains(currentID) {
        } else {
            currentID = itemIDs[0]
            needsReset = true
        }
        if let fromID, !itemIDs.contains(fromID) { needsReset = true }
        if let toID, !itemIDs.contains(toID) { needsReset = true }
        if (fromID == nil) != (toID == nil) { needsReset = true }
        if let fromID, fromID != currentID { needsReset = true }

        if needsReset {
            invalidateAnimation()
            fromID = nil
            toID = nil
            progress = 0
            direction = 1
            trailingID = nil
            rebasedCommittedDrag = false
            isDragging = false
            dragOriginSignedProgress = 0
            lastSettledAt = Date()
            presentation?.stopAnimationAndPresent(visualState)
        } else {
            presentation?.present(visualState)
        }
    }

    func neighborID(from itemID: String, direction: Int) -> String? {
        guard itemIDs.count > 1, let index = itemIDs.firstIndex(of: itemID) else { return nil }
        let next = (index + direction + itemIDs.count) % itemIDs.count
        return itemIDs[next]
    }

    func prepareHorizontalDrag(acquisitionTranslationX: CGFloat) -> Bool {
        guard let currentID, itemIDs.count > 1 else { return false }
        let requestedDirection = acquisitionTranslationX < 0 ? 1 : -1
        rebasedCommittedDrag = false
        if let oldFromID = fromID, let oldToID = toID {
            let wasCommitted = committedTargetID == oldToID
            invalidateAnimation()
            progress = presentation?.interruptAndReadProgress(fromID: fromID, toID: toID, direction: direction, fallback: progress) ?? progress
            // Continue to the next page from the visible position, without finishing the old animator.
            // A negative origin retains the outgoing page until the committed anchor reaches center.
            if wasCommitted, direction == requestedDirection, progress >= 0, itemIDs.count > 2, let nextID = neighborID(from: oldToID, direction: requestedDirection) {
                self.currentID = oldToID
                fromID = oldToID
                toID = nextID
                trailingID = oldFromID
                progress -= 1
                rebasedCommittedDrag = true
            } else if progress < 0 {
                rebasedCommittedDrag = true
            }
            dragOriginSignedProgress = CGFloat(direction) * progress
            isDragging = true
            presentation?.present(visualState)
            return true
        }
        trailingID = nil
        guard let targetID = neighborID(from: currentID, direction: requestedDirection) else { return false }
        fromID = currentID
        toID = targetID
        direction = requestedDirection
        progress = 0
        dragOriginSignedProgress = 0
        isDragging = true
        presentation?.present(visualState)
        return true
    }

    func updateDrag(translationX: CGFloat, width: CGFloat) {
        guard isDragging, let currentID else { return }
        let signedPosition = min(1, max(-1, dragOriginSignedProgress - translationX / max(1, width)))
        var nextDirection = direction
        if signedPosition > 0.0001 { nextDirection = 1 }
        else if signedPosition < -0.0001 { nextDirection = -1 }
        guard let targetID = neighborID(from: currentID, direction: nextDirection) else { return }
        trailingID = nil
        fromID = currentID
        toID = targetID
        direction = nextDirection
        progress = abs(signedPosition)
        V3HomeCarouselCadenceDiagnostics.shared.recordProgressPublish(progress)
        presentation?.present(visualState)
    }

    func finishDrag(actualTranslationX: CGFloat, releaseVelocityX: CGFloat?, width: CGFloat) {
        guard isDragging, toID != nil else {
            V3HomeCarouselCadenceDiagnostics.shared.end(reason: "ended-no-transition")
            return
        }
        let distanceProgress: CGFloat
        if rebasedCommittedDrag || abs(dragOriginSignedProgress) <= 0.0001 { distanceProgress = min(1, max(0, abs(actualTranslationX) / max(1, width))) }
        else { distanceProgress = progress }
        let releaseVelocity = releaseVelocityX ?? 0
        let releaseDirection = rebasedCommittedDrag && actualTranslationX != 0 ? (actualTranslationX < 0 ? 1 : -1) : direction
        let expectedSign: CGFloat = releaseDirection > 0 ? -1 : 1
        let directionalVelocity = releaseVelocity * expectedSign
        let velocityCommit = directionalVelocity >= 500
        let shouldCommit = distanceProgress >= 0.28 || velocityCommit
        DiagnosticsLogger.shared.app("HomeCarouselReleaseDecision", "actual_progress=\(String(format: "%.3f", distanceProgress)) release_velocity_x=\(String(format: "%.2f", releaseVelocity)) directional_velocity=\(String(format: "%.2f", directionalVelocity)) velocity_commit=\(velocityCommit) should_commit=\(shouldCommit)")
        isDragging = false
        if shouldCommit {
            if rebasedCommittedDrag, let currentID, let targetID = neighborID(from: currentID, direction: releaseDirection) {
                let signedPosition = CGFloat(direction) * progress
                direction = releaseDirection
                progress = signedPosition * CGFloat(direction)
                fromID = currentID
                toID = targetID
                trailingID = progress < 0 ? neighborID(from: currentID, direction: -direction) : nil
                presentation?.present(visualState)
            }
            if let targetID = toID { animateCommit(to: targetID) }
        } else { animateCancel() }
    }

    func cancelDrag() {
        guard isDragging else {
            V3HomeCarouselCadenceDiagnostics.shared.end(reason: "cancelled-no-transition")
            return
        }
        isDragging = false
        animateCancel()
    }

    func autoAdvanceIfNeeded(isHomeActive: Bool) {
        guard isHomeActive, !isDragging, toID == nil, itemIDs.count > 1 else { return }
        guard Date().timeIntervalSince(lastSettledAt) >= 6 else { return }
        guard let currentID, let targetID = neighborID(from: currentID, direction: 1) else { return }
        fromID = currentID
        toID = targetID
        direction = 1
        progress = 0
        presentation?.present(visualState)
        committedTargetID = targetID
        animate(to: 1, duration: 0.62, curve: .easeInOut) { [weak self] in self?.settle(on: targetID) }
    }

    func commitCurrentTransition(to targetID: String) {
        guard toID == targetID else { return }
        isDragging = false
        animateCommit(to: targetID)
    }

    func cancelCurrentTransition() {
        isDragging = false
        animateCancel()
    }

    func deactivate() {
        invalidateAnimation()
        fromID = nil
        toID = nil
        progress = 0
        direction = 1
        trailingID = nil
        rebasedCommittedDrag = false
        committedTargetID = nil
        isDragging = false
        dragOriginSignedProgress = 0
        presentation?.stopAnimationAndPresent(visualState)
    }

    private var visualState: V3HomeCarouselTransitionVisualState {
        V3HomeCarouselTransitionVisualState(currentID: currentID, fromID: fromID, toID: toID, direction: direction, progress: progress, trailingID: trailingID)
    }

    private func animateCommit(to targetID: String) {
        committedTargetID = targetID
        animate(to: 1, duration: 0.22, curve: .easeOut) { [weak self] in self?.settle(on: targetID) }
    }

    private func animateCancel() {
        committedTargetID = nil
        animate(to: 0, duration: 0.18, curve: .easeOut) { [weak self] in
            guard let self else { return }
            self.progress = 0
            self.fromID = nil
            self.toID = nil
            self.direction = 1
            self.trailingID = nil
            self.rebasedCommittedDrag = false
            self.dragOriginSignedProgress = 0
            self.lastSettledAt = Date()
            self.presentation?.present(self.visualState)
            V3HomeCarouselCadenceDiagnostics.shared.end(reason: "cancelled-settled")
        }
    }

    private func animate(to targetProgress: CGFloat, duration: TimeInterval, curve: UIView.AnimationCurve, completion: @escaping () -> Void) {
        animationToken &+= 1
        let token = animationToken
        let fromID = self.fromID
        let toID = self.toID
        let targetState = V3HomeCarouselTransitionVisualState(currentID: currentID, fromID: fromID, toID: toID, direction: direction, progress: targetProgress, trailingID: trailingID)
        let didStart = presentation?.animate(targetState, duration: duration, curve: curve) { [weak self] in
            guard let self, self.animationToken == token, self.fromID == fromID, self.toID == toID else { return }
            self.progress = targetProgress
            completion()
        } ?? false
        if !didStart, animationToken == token, self.fromID == fromID, self.toID == toID {
            progress = targetProgress
            completion()
        }
    }

    private func settle(on itemID: String) {
        currentID = itemID
        fromID = nil
        toID = nil
        progress = 0
        direction = 1
        trailingID = nil
        rebasedCommittedDrag = false
        committedTargetID = nil
        isDragging = false
        dragOriginSignedProgress = 0
        lastSettledAt = Date()
        presentation?.present(visualState)
        DiagnosticsLogger.shared.log("HomeCarousel", "settled item=\(itemID)")
        V3HomeCarouselCadenceDiagnostics.shared.end(reason: "settled")
    }

    private func invalidateAnimation() { animationToken &+= 1; committedTargetID = nil }
}

extension V3EmbyHomeView {
    var currentCarouselItemID: String? {
        get { carouselRuntimeState.currentID }
        nonmutating set { carouselRuntimeState.currentID = newValue }
    }

    var transitionFromID: String? {
        get { carouselRuntimeState.fromID }
        nonmutating set { carouselRuntimeState.fromID = newValue }
    }

    var transitionToID: String? {
        get { carouselRuntimeState.toID }
        nonmutating set { carouselRuntimeState.toID = newValue }
    }

    var transitionProgress: CGFloat {
        get { carouselRuntimeState.progress }
        nonmutating set { carouselRuntimeState.progress = newValue }
    }

    var transitionDirection: Int {
        get { carouselRuntimeState.direction }
        nonmutating set { carouselRuntimeState.direction = newValue }
    }

    var isCarouselDragging: Bool {
        get { carouselRuntimeState.isDragging }
        nonmutating set { carouselRuntimeState.isDragging = newValue }
    }

    var carouselTapSuppressedUntil: Date {
        get { carouselRuntimeState.tapSuppressedUntil }
        nonmutating set { carouselRuntimeState.tapSuppressedUntil = newValue }
    }

    func suppressCarouselTap() { carouselTapSuppressedUntil = Date().addingTimeInterval(0.30) }

    func openCurrentCarouselDetailIfAllowed() {
        guard transitionToID == nil, !isCarouselDragging, Date() >= carouselTapSuppressedUntil, let item = currentCarouselItem else { return }
        carouselDetailItem = item
        isCarouselDetailPresented = true
    }

    func completeInteractiveTransition(to targetID: String) { carouselRuntimeState.commitCurrentTransition(to: targetID) }
    func cancelInteractiveTransition() { carouselRuntimeState.cancelCurrentTransition() }
    func autoAdvanceCarouselIfNeeded() { carouselRuntimeState.autoAdvanceIfNeeded(isHomeActive: isHomeActive) }

    func synchronizeCarouselItems() {
        let items = model.carouselItems
        let ids = items.map(\.id)
        let idSet = Set(ids)
        carouselRuntimeState.bind(presentation: carouselPresentationBridge)
        carouselRuntimeState.synchronize(itemIDs: ids)
        carouselLogoByID = carouselLogoByID.filter { idSet.contains($0.key) }
        carouselLogoResolvedIDs.formIntersection(idSet)
        refreshCarouselPresentationItems()
        resolveCarouselLogosIfNeeded()
        onCarouselActiveChanged(!items.isEmpty)
    }

    func refreshCarouselPresentationItems() {
        let prepared = model.carouselItems.map { item in
            V3HomeCarouselPresentationItem(id: item.id, title: carouselHeroTitle(item), overview: item.overview, rating: item.communityRating, year: item.productionYear, officialRating: item.officialRating, typeTitle: v3MediaTypeTitle(item), heroURL: carouselImageURL(item), logoURL: carouselLogoURL(item))
        }
        carouselPresentationItems = prepared
        carouselPresentationBridge.configure(items: prepared)
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
                        refreshCarouselPresentationItems()
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

    func neighborCarouselItemID(from itemID: String, direction: Int) -> String? { carouselRuntimeState.neighborID(from: itemID, direction: direction) }

    func carouselImageURL(_ item: LibraryItem) -> URL? {
        client.imageURL(itemId: item.preferredPrimaryImageItemId, maxWidth: 1400, tag: item.preferredPrimaryImageTag)
    }

    func carouselLogoURL(_ item: LibraryItem) -> URL? {
        guard let logo = carouselLogoByID[item.id] else { return nil }
        return client.imageURL(itemId: item.id, imageType: "Logo", maxWidth: 900, index: logo.imageIndex)
    }
}
