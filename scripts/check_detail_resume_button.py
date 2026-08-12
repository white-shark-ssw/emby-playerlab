from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"::error::{message}")


detail = Path("Sources/UI/EmbyMediaDetailView.swift").read_text()
metrics = Path("Sources/UI/ImmersiveUIComponents.swift").read_text()
project = Path("project.yml").read_text()

require('Text("音视频字幕信息")' in detail, "media stream title must remain present")
require('if mediaInfoExpanded {' in detail and '.transition(.opacity.combined(with: .move(edge: .top)))' in detail, "media stream expand transition must remain animated")
media_section = detail.split('private var mediaStreamInfoSection: some View {', 1)[1].split('private func mediaStreamCard', 1)[0]
require('.clipped()' in media_section, "expanded media stream content must be clipped below its title")
require('private func primaryPlayButtonLabel(width: CGFloat) -> some View' in detail, "detail must use the dedicated resume-aware play button label")
require('Text("继续播放")' in detail and 'Text("上次播放到：\\(position)")' in detail, "resume button must use the requested two-line copy")
require('var primaryPlayButtonShowsResume: Bool' in detail and 'guard !displayedPlayed' in detail, "watched state must immediately suppress resume presentation")
require('var primaryPlayButtonProgress: Double' in detail and 'playable.playbackProgress' in detail, "resume button progress must come from the actual playback percentage")
require('var primaryPlayButtonPositionText: String?' in detail and 'playbackPositionTicks' in detail, "resume subtitle must come from the actual Emby playback position")
require('return primaryPlayButtonShowsResume ? "继续播放" : "播放"' in detail, "primary play title must refresh immediately between resume and plain play")
require('.frame(width: width, height: 50)' in detail, "resume treatment must not change the frozen Hero button height")
require('static let detailCropResponseFactor: CGFloat = 0.90' in metrics, "frozen detail Hero crop response must remain unchanged")
require('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "Deployment Target must remain iOS 15.0")
print("detail resume button and clipped media reveal invariants: OK")
