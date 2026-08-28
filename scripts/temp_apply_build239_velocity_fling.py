from pathlib import Path

p = Path('Sources/UI/EmbyHomeHeroV3.swift')
text = p.read_text()
old = 'onHorizontalEnded: { translation, predictedTranslation in finishNativeCarouselDrag(translation, predictedTranslation: predictedTranslation, width: width) },'
new = 'onHorizontalEnded: { translation, releaseVelocityX in finishNativeCarouselDrag(translation, releaseVelocityX: releaseVelocityX, width: width) },'
if text.count(old) != 1: raise SystemExit(f'unexpected Build239 Hero release call count: {text.count(old)}')
text = text.replace(old, new, 1)
p.write_text(text)
