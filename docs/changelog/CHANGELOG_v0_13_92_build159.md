# OnePlayer 0.13.92 Build159

PiP lifecycle correction: defer Home until system PiP didStart, switch MPV VO gpu-next↔null without disabling the video track, and keep PiP SampleBuffer timebase aligned across ±10s seeks.

Release validation keeps PlayerController/UnifiedTransport/MPV seek semantics frozen while testing the new PiP renderer lifecycle.

Final candidate validates immediate didStart Home handoff, VO suspension and PiP seek clock continuity on iOS 17.0.
