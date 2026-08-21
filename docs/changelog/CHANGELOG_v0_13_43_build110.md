# OnePlayer 0.13.43 / Build110

- Preserve frozen 2 MiB AVIO request-size fix.
- Preserve Build103-109 compatibility and seek-latency changes.
- Fix Build109 continuous-seek session timing conflict: precise settle now waits 550ms of input silence instead of 280ms, while burst classification remains 450ms.
- User seek input remains immediate; no debounce is added.
- Deployment Target remains iOS 15.0.
