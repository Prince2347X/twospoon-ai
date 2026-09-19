from backend.market.tiers import DeliveryTier


def test_hysteresis_requires_two_bad_and_four_good_reports():
    tier = DeliveryTier(now=0)
    tier.report(400, 90, now=2)
    assert tier.name == 'full'
    tier.report(400, 90, now=4)
    assert tier.name == 'degraded'
    for now in [6, 8, 10]:
        tier.report(50, 5, now=now)
        assert tier.name == 'degraded'
    tier.report(50, 5, now=12)
    assert tier.name == 'full'


def test_missing_reports_and_override_are_per_client():
    first, second = DeliveryTier(now=0), DeliveryTier(now=0)
    first.force('full')
    first.tick(now=16)
    second.tick(now=16)
    assert first.name == 'full'
    assert second.name == 'minimal'
    first.force(None)
    first.tick(now=17)
    assert first.name == 'minimal'


def test_fluctuation_resets_candidate_and_recovery_uses_lower_threshold():
    tier = DeliveryTier(now=0)
    for now, latency in enumerate([300, 50, 300, 50, 300, 50]):
        tier.report(latency, 0, now=now)
    assert tier.name == 'full'
    tier.report(900, 200, now=7)
    tier.report(900, 200, now=9)
    assert tier.name == 'minimal'
    for now in range(10, 20):
        tier.report(600, 100, now=now)
    assert tier.name == 'minimal'
    for now in range(20, 24):
        tier.report(300, 40, now=now)
    assert tier.name == 'degraded'
