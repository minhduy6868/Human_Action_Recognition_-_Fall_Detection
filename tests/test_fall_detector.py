from app.pipelines.fall_detection import FallDetector


def test_no_pose_returns_false():
    fd = FallDetector()
    res, conf = fd.update(None, "unknown", ts_ms=1000)
    assert res is False
    assert conf == 0.0


def test_simple_fall_flow():
    fd = FallDetector(drop_threshold=0.05, aspect_threshold=1.0, velocity_threshold=0.0, confirm_ms=500, candidate_window_ms=1000)
    # initial standing at y=0.4
    ts = 1000
    pose = {"center": (0.5, 0.4), "aspect_ratio": 0.5}
    r, c = fd.update(pose, "standing", ts)
    assert not r

    # sudden drop to y=0.8 (large positive delta)
    ts += 50
    pose2 = {"center": (0.5, 0.8), "aspect_ratio": 1.3}
    r, c = fd.update(pose2, "lying", ts)
    # candidate should be set but may not confirm yet
    assert not r

    # remain lying for > confirm_ms
    ts += 600
    r, c = fd.update(pose2, "lying", ts)
    assert r is True
    assert c > 0.0
