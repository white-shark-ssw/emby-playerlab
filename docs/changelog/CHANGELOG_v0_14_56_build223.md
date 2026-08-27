# OnePlayer 0.14.56 / Build223

- Diagnostic A/B only for Home vertical smoothness.
- Do not mount the root-level full-screen persistent carousel backdrop in the Home root ZStack.
- Hero artwork, carousel preload, automatic carousel behavior and horizontal interaction remain unchanged from the accepted main baseline.
- Purpose: isolate whether the always-mounted 1400px `scaleEffect(1.12)` + `blur(radius: 30)` persistent backdrop is a structural contributor to Home vertical hitching.
- This intentionally changes the immersive Home background appearance and is not a proposed final visual design.
