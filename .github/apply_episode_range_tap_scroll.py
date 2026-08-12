from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, got {count}")
    return text.replace(old, new, 1)


detail_path = Path("Sources/UI/EmbyMediaDetailView.swift")
detail = detail_path.read_text()
old_chip = '''                            ForEach(model.episodeRanges) { range in
                                Button { jumpToEpisodeRange(range, proxy: proxy) } label: {
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
                            }
'''
new_chip = '''                            ForEach(model.episodeRanges) { range in
                                Text(range.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(model.selectedEpisodeRangeOffset == range.startOffset ? .white : .primary)
                                    .padding(.horizontal, 11)
                                    .frame(height: 31)
                                    .background(model.selectedEpisodeRangeOffset == range.startOffset ? Color.blue : Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.06))
                                    .clipShape(Capsule())
                                    .frame(minHeight: 44)
                                    .contentShape(Rectangle())
                                    .highPriorityGesture(TapGesture().onEnded { jumpToEpisodeRange(range, proxy: proxy) })
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityAction { jumpToEpisodeRange(range, proxy: proxy) }
                            }
'''
detail = replace_once(detail, old_chip, new_chip, "episode range chip")
old_jump = '''    private func jumpToEpisodeRange(_ range: EmbyEpisodeRange, proxy: ScrollViewProxy) {
        model.selectEpisodeRange(range.startOffset)
        guard let target = model.episode(at: range.startOffset) else { return }
        DispatchQueue.main.async {
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) { proxy.scrollTo(target.id, anchor: .leading) }
        }
    }
'''
new_jump = '''    private func jumpToEpisodeRange(_ range: EmbyEpisodeRange, proxy: ScrollViewProxy) {
        let previousOffset = model.selectedEpisodeRangeOffset
        DiagnosticsLogger.shared.log("EpisodeRangeJump", "tap fromOffset=\\(previousOffset) toOffset=\\(range.startOffset) title=\\(range.title)")
        model.selectEpisodeRange(range.startOffset)
        guard let target = model.episode(at: range.startOffset) else {
            DiagnosticsLogger.shared.log("EpisodeRangeJump", "target-missing offset=\\(range.startOffset)")
            return
        }
        DispatchQueue.main.async {
            DiagnosticsLogger.shared.log("EpisodeRangeJump", "scroll target=\\(target.id) offset=\\(range.startOffset)")
            withAnimation(.easeInOut(duration: 0.32)) { proxy.scrollTo(target.id, anchor: .leading) }
        }
    }
'''
detail = replace_once(detail, old_jump, new_jump, "episode range jump")
detail_path.write_text(detail)

check_path = Path("scripts/check_detail_episode_range_jump.py")
check = check_path.read_text()
old_check = '''require("Button { jumpToEpisodeRange(range, proxy: proxy) }" in detail, "episode range buttons must use the deterministic jump helper")
require(".frame(minHeight: 44)" in detail and ".contentShape(Rectangle())" in detail, "episode range buttons need a 44pt minimum tap target")
require("private func jumpToEpisodeRange(_ range: EmbyEpisodeRange, proxy: ScrollViewProxy)" in detail, "deterministic range jump helper is missing")
require("DispatchQueue.main.async" in detail, "range jump must run after the current SwiftUI update cycle")
require("transaction.animation = nil" in detail, "range jump must not depend on interruptible scroll animation")
require("proxy.scrollTo(target.id, anchor: .leading)" in detail, "range jump must directly target the requested episode")
require("withAnimation(.easeInOut(duration: 0.32)) { proxy.scrollTo" not in detail, "old interruptible animated range jump must stay removed")
'''
new_check = '''require(".highPriorityGesture(TapGesture().onEnded { jumpToEpisodeRange(range, proxy: proxy) })" in detail, "episode range taps must have priority over the parent horizontal ScrollView")
require(".frame(minHeight: 44)" in detail and ".contentShape(Rectangle())" in detail, "episode range controls need a 44pt minimum tap target")
require(".accessibilityAddTraits(.isButton)" in detail and ".accessibilityAction { jumpToEpisodeRange(range, proxy: proxy) }" in detail, "episode range controls must preserve button accessibility")
require("private func jumpToEpisodeRange(_ range: EmbyEpisodeRange, proxy: ScrollViewProxy)" in detail, "range jump helper is missing")
require("DispatchQueue.main.async" in detail, "range jump must run after the current SwiftUI update cycle")
require("withAnimation(.easeInOut(duration: 0.32)) { proxy.scrollTo(target.id, anchor: .leading) }" in detail, "range jump must restore real horizontal animated movement")
require("transaction.animation = nil" not in detail, "non-animated range jump must stay removed")
require('DiagnosticsLogger.shared.log("EpisodeRangeJump", "tap' in detail, "range tap diagnostics are missing")
require('DiagnosticsLogger.shared.log("EpisodeRangeJump", "scroll' in detail, "range scroll diagnostics are missing")
'''
check = replace_once(check, old_check, new_check, "range jump checker")
check_path.write_text(check)
