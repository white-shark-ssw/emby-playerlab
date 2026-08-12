from pathlib import Path

path = Path("Sources/UI/EmbyMediaDetailView.swift")
text = path.read_text()
start_marker = "    private func primaryPlayButtonLabel(width: CGFloat) -> some View {"
end_marker = "\n    @ViewBuilder\n    private func heroIdentity"
start = text.index(start_marker)
end = text.index(end_marker, start)
new_block = '''    private func primaryPlayButtonLabel(width: CGFloat) -> some View {
        let progress = CGFloat(min(max(0, model.primaryPlayButtonProgress), 1))
        let foreground = Color.black.opacity(0.82)
        let shape = RoundedRectangle(cornerRadius: 25, style: .continuous)
        return ZStack {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    shape.fill(Color.white.opacity(0.82))
                    if model.primaryPlayButtonShowsResume && progress > 0 {
                        Rectangle()
                            .fill(Color.white.opacity(0.24))
                            .frame(width: proxy.size.width * progress)
                    }
                }
                .clipShape(shape)
            }

            HStack(spacing: 12) {
                if model.isResolvingPlayback {
                    ProgressView().tint(foreground)
                } else {
                    Image(systemName: "play.fill").font(.system(size: 15, weight: .bold))
                }

                if model.isResolvingPlayback {
                    Text(model.primaryPlayButtonTitle).font(.system(size: 18, weight: .semibold))
                } else if model.primaryPlayButtonShowsResume {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("继续播放").font(.system(size: 18, weight: .bold))
                        if let position = model.primaryPlayButtonPositionText {
                            Text("上次播放到：\(position)").font(.system(size: 12.5, weight: .medium))
                        }
                    }
                } else {
                    Text("播放").font(.system(size: 18, weight: .semibold))
                }
            }
            .foregroundColor(foreground)
        }
        .frame(width: width, height: 50)
        .clipShape(shape)
    }
'''
text = text[:start] + new_block + text[end:]
path.write_text(text)
