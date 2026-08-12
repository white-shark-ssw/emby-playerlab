from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)

path = Path("Sources/UI/EmbyMediaDetailView.swift")
text = path.read_text()
text = replace_once(
    text,
    "            .offset(y: stretch > 0 ? 0 : backdropPinOffset)\n\n            LinearGradient(",
    "            .offset(y: stretch > 0 ? 0 : backdropPinOffset)\n            .frame(width: width, height: visualHeight, alignment: .top)\n\n            LinearGradient(",
    "top-align clear backdrop inside taller foreground Hero",
)
old_button = '''                                Button {
                                    model.selectEpisodeRange(range.startOffset)
                                    if let target = model.episode(at: range.startOffset) {
                                        withAnimation(.easeInOut(duration: 0.32)) { proxy.scrollTo(target.id, anchor: .leading) }
                                    }
                                } label: {
                                    Text(range.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(model.selectedEpisodeRangeOffset == range.startOffset ? .white : .primary)
                                        .padding(.horizontal, 11)
                                        .frame(height: 31)
                                        .background(model.selectedEpisodeRangeOffset == range.startOffset ? Color.blue : Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.06))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
'''
new_button = '''                                Button { jumpToEpisodeRange(range, proxy: proxy) } label: {
                                    Text(range.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(model.selectedEpisodeRangeOffset == range.startOffset ? .white : .primary)
                                        .padding(.horizontal, 11)
                                        .frame(height: 31)
                                        .background(model.selectedEpisodeRangeOffset == range.startOffset ? Color.blue : Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.06))
                                        .clipShape(Capsule())
                                        .frame(minHeight: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
'''
text = replace_once(text, old_button, new_button, "replace range button action and hit target")
anchor = '''    private func episodePreviewCard(_ episode: LibraryItem) -> some View {
'''
helper = '''    private func jumpToEpisodeRange(_ range: EmbyEpisodeRange, proxy: ScrollViewProxy) {
        model.selectEpisodeRange(range.startOffset)
        guard let target = model.episode(at: range.startOffset) else { return }
        DispatchQueue.main.async {
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) { proxy.scrollTo(target.id, anchor: .leading) }
        }
    }

'''
text = replace_once(text, anchor, helper + anchor, "add deterministic range jump helper")
path.write_text(text)

check_path = Path("scripts/check_adaptive_hero_reveal.py")
check = check_path.read_text()
marker = 'require("viewportHeight: backdropVisualHeight" in detail, "detail clear-backdrop mask was coupled back to foreground height")\n'
insert = marker + 'require(".offset(y: stretch > 0 ? 0 : backdropPinOffset)\\n            .frame(width: width, height: visualHeight, alignment: .top)" in detail, "detail clear backdrop must occupy the taller Hero layout while staying top-aligned")\n'
check = replace_once(check, marker, insert, "add top alignment regression")
check_path.write_text(check)

range_check = '''from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"::error::{message}")


detail = Path("Sources/UI/EmbyMediaDetailView.swift").read_text()
project = Path("project.yml").read_text()
require("Button { jumpToEpisodeRange(range, proxy: proxy) }" in detail, "episode range buttons must use the deterministic jump helper")
require(".frame(minHeight: 44)" in detail and ".contentShape(Rectangle())" in detail, "episode range buttons need a 44pt minimum tap target")
require("private func jumpToEpisodeRange(_ range: EmbyEpisodeRange, proxy: ScrollViewProxy)" in detail, "deterministic range jump helper is missing")
require("DispatchQueue.main.async" in detail, "range jump must run after the current SwiftUI update cycle")
require("transaction.animation = nil" in detail, "range jump must not depend on interruptible scroll animation")
require("proxy.scrollTo(target.id, anchor: .leading)" in detail, "range jump must directly target the requested episode")
require("withAnimation(.easeInOut(duration: 0.32)) { proxy.scrollTo" not in detail, "old interruptible animated range jump must stay removed")
require('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "Deployment Target must remain iOS 15.0")
print("detail episode range jump invariants: OK")
'''
Path("scripts/check_detail_episode_range_jump.py").write_text(range_check)
