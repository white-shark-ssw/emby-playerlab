from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"::error::{message}")


models = Path("Sources/Models/EmbyModels.swift").read_text()
client = Path("Sources/Networking/EmbyAPIClient.swift").read_text()
session = Path("Sources/Session/SessionStore.swift").read_text()
detail = Path("Sources/UI/EmbyMediaDetailView.swift").read_text()
metrics = Path("Sources/UI/ImmersiveUIComponents.swift").read_text()
project = Path("project.yml").read_text()

require('case dateCreated = "DateCreated"' in models and 'let dateCreated: String?' in models, "detail media summary must decode DateCreated")
for token in ['case width = "Width"', 'case height = "Height"', 'case bitRate = "BitRate"', 'case bitDepth = "BitDepth"', 'case channels = "Channels"', 'case sampleRate = "SampleRate"', 'case isDefault = "IsDefault"', 'case isForced = "IsForced"']:
    require(token in models, f"missing media stream metadata field: {token}")
require('init(from decoder: Decoder) throws' in models and 'realFrameRate = try? container.decode(Double.self' in models, "MediaStream metadata must use tolerant per-field decoding")
require('let serverName: String?' in client and 'serverName: String? = nil' in client, "EmbyAPIClient must carry an optional server display name")
require('serverName: stored.serverName' in session, "SessionStore must propagate server name into EmbyAPIClient")
require('@State private var mediaInfoExpanded = false' in detail and '@State private var showRawMediaPath = false' in detail, "detail media UI state missing")
require('Text("视频信息")' in detail and 'Image(systemName: "chevron.up")' in detail, "foldable media stream header missing")
require('withAnimation(.easeInOut(duration: 0.34)) { mediaInfoExpanded.toggle() }' in detail, "media stream fold must retain competitor-style animation timing")
require('ScrollView(.horizontal, showsIndicators: false)' in detail and 'mediaStreamCard(stream, ordinal: index)' in detail, "media stream cards must use a horizontal container")
require('mediaSourceSummarySection' in detail and 'showRawMediaPath.toggle()' in detail and 'source.path' in detail, "media source card must toggle between summary and raw STRM/media path")
require('@Published var mediaSources: [MediaSource] = []' in detail and 'await loadMediaMetadata(for: primaryPlayableItem)' in detail, "detail ViewModel must load PlaybackInfo metadata")
require(detail.count('client.playbackInfo(itemId:') >= 2, "actual play must still request a fresh PlaybackInfo instead of reusing detail metadata")
require('detailBackdropViewportHeight(width: width)' in detail and 'responseFactor: AdaptiveHeroRevealMetrics.detailCropResponseFactor' in detail, "frozen detail Hero geometry must remain intact")
require('static let detailCropResponseFactor: CGFloat = 0.90' in metrics, "frozen 0.90 detail crop response must remain unchanged")
require('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "Deployment Target must remain iOS 15.0")
print("detail media metadata invariants: OK")
