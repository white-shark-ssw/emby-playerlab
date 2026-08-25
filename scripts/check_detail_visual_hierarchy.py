from pathlib import Path

detail = Path('Sources/UI/EmbyMediaDetailView.swift').read_text()

expected_order = '''                                castSection
                                tagSection
                                stillsSection
                                similarSection
                                mediaStreamInfoSection
                                mediaSourceSummarySection'''
assert expected_order in detail
assert 'Text("音视频字幕信息")' not in detail
assert 'Text("视频信息").font(.system(size: 19, weight: .bold)).foregroundColor(.primary)' in detail

headers = [
    'Text("即将播放").font(.system(size: 19, weight: .bold)).fixedSize()',
    'Text("季").font(.system(size: 19, weight: .bold)).padding(.horizontal, 20)',
    'Text("演职人员").font(.system(size: 19, weight: .bold)).padding(.horizontal, 20)',
    'Text("标签").font(.system(size: 19, weight: .bold))',
    'Text("剧照").font(.system(size: 19, weight: .bold)).padding(.horizontal, 20)',
    'Text(model.isSeries ? "更多类似" : "相似作品").font(.system(size: 19, weight: .bold)).padding(.horizontal, 20)',
]
for header in headers:
    assert header in detail

assert 'Text(model.displayEpisodeTitle(episode)).font(.system(size: 19' not in detail
assert 'fallbackHeroTitle(width: width)' in detail
print('Detail visual hierarchy checks passed')
