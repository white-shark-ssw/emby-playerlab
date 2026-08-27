# OnePlayer 0.14.54 / Build221

- Diagnostic A/B only: retain Build219 120 Hz request and all Build215 carousel motion contracts.
- While the user is actively dragging, keep only the current full-screen blurred persistent backdrop at opacity 1 and do not mount the transition-target persistent image.
- Hero artwork still mounts/crossfades normally. On release, the existing persistent transition path resumes.
- Purpose: isolate the repeatable 50 ms display gaps observed ~19-25 ms after persistent 1400px image callbacks.
