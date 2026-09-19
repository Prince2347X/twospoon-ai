"""Per-connection delivery policy; times are monotonic seconds."""

RATES = {'full': 10.0, 'degraded': 2.0, 'minimal': 0.5}
LEVELS = tuple(RATES)


class DeliveryTier:
    def __init__(self, now: float):
        self.automatic = 'full'
        self.override: str | None = None
        self.last_report = now
        self.candidate: str | None = None
        self.streak = 0

    @property
    def name(self) -> str:
        return self.override or self.automatic

    @property
    def rate(self) -> float:
        return RATES[self.name]

    def force(self, name: str | None) -> None:
        if name is not None and name not in RATES:
            raise ValueError('Unknown delivery tier')
        self.override = name

    def tick(self, now: float) -> None:
        if now - self.last_report > 15:
            self.automatic = 'minimal'
            self.candidate, self.streak = None, 0

    def report(self, latency_ms: float, jitter_ms: float, now: float) -> None:
        self.last_report = now
        level = LEVELS.index(self.automatic)
        if latency_ms >= 800 or jitter_ms >= 180:
            target = 2
        elif latency_ms >= 250 or jitter_ms >= 60:
            target = max(level, 1)
        else:
            target = level
        # Recovery uses lower thresholds and only improves one tier at a time.
        if level == 2 and latency_ms < 500 and jitter_ms < 100:
            target = 1
        elif level == 1 and latency_ms < 180 and jitter_ms < 40:
            target = 0
        if target == level:
            self.candidate, self.streak = None, 0
            return
        name = LEVELS[target]
        self.streak = self.streak + 1 if name == self.candidate else 1
        self.candidate = name
        required = 2 if target > level else 4
        if self.streak >= required:
            self.automatic = name
            self.candidate, self.streak = None, 0
