from pathlib import Path

s = Path("Sources/UI/EmbyServerRootViewV3.swift").read_text()
project = Path("project.yml").read_text()

assert 'header(immersive: true)\n                                .padding(.top, geometry.safeAreaInsets.top)' not in s
assert 'V3MediaManagementView(preferences: model.preferences, carouselEnabled: model.carouselEnabled)' in s
assert '@Published var carouselEnabled: Bool' in s
assert 'guard carouselEnabled else { return [] }' in s
assert 'osplayer.home.carousel-enabled.' in s
assert 'UserDefaults.standard.set(carouselEnabled, forKey: carouselEnabledKey)' in s
assert 'Text("一键控制首页沉浸轮播，关闭不会清除下方媒体库选择")' in s
media = s[s.index('private struct V3MediaManagementView'):s.index('private struct V3HeroCard')]
assert 'if let type = preference.collectionType' not in media
assert media.count('Text("首页").font(.caption2).foregroundColor(.secondary)') == 1
assert media.count('Text("轮播").font(.caption2).foregroundColor(.secondary)') == 1
assert '} header: {' in media
assert 'Toggle("首页", isOn: $preference.showOnHome)' in media
assert 'Toggle("轮播", isOn: $preference.includeInCarousel)' in media
assert 'IPHONEOS_DEPLOYMENT_TARGET: "15.0"' in project
print("Home UI polish checks passed")
