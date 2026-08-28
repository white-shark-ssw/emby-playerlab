from pathlib import Path

hero = Path("Sources/UI/EmbyHomeHeroV3.swift")
hero_text = hero.read_text()
old_hero = '''            if let item = currentCarouselItem {
                carouselHeroArtwork(item: item, width: width, viewportHeight: viewportHeight)
                    .opacity(isCarouselDragging ? 1 : carouselOpacity(for: item.id))
                    .allowsHitTesting(false)
            }
            if !isCarouselDragging, let item = transitionTargetCarouselItem {
                carouselHeroArtwork(item: item, width: width, viewportHeight: viewportHeight)
                    .opacity(carouselOpacity(for: item.id))
                    .allowsHitTesting(false)
            }
'''
new_hero = '''            ForEach(carouselHeroResidentItems) { item in
                carouselHeroArtwork(item: item, width: width, viewportHeight: viewportHeight)
                    .opacity(carouselOpacity(for: item.id))
                    .allowsHitTesting(false)
            }
'''
if new_hero in hero_text:
    pass
elif old_hero in hero_text:
    hero.write_text(hero_text.replace(old_hero, new_hero, 1))
else:
    raise SystemExit("Build226 Hero mount block is neither Build225 baseline nor expected residency form")

state = Path("Sources/UI/EmbyHomeCarouselStateV3.swift")
state_text = state.read_text()
marker = '''    func carouselImageURL(_ item: LibraryItem) -> URL? {
'''
resident = '''    var carouselHeroResidentItems: [LibraryItem] {
        guard let currentID = currentCarouselItemID else { return [] }
        var ids = [currentID]
        if let previousID = neighborCarouselItemID(from: currentID, direction: -1), !ids.contains(previousID) { ids.append(previousID) }
        if let nextID = neighborCarouselItemID(from: currentID, direction: 1), !ids.contains(nextID) { ids.append(nextID) }
        return ids.compactMap { id in model.carouselItems.first { $0.id == id } }
    }

'''
if resident in state_text:
    pass
elif marker in state_text:
    state.write_text(state_text.replace(marker, resident + marker, 1))
else:
    raise SystemExit("Build226 carouselImageURL marker not found")
