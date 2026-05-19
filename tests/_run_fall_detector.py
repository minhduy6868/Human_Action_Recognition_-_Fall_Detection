from app.pipelines.fall_detection import FallDetector


def run():
    try:
        fd = FallDetector()
        res, conf = fd.update(None, "unknown", ts_ms=1000)
        assert res is False and conf == 0.0

        fd = FallDetector(drop_threshold=0.05, aspect_threshold=1.0, velocity_threshold=0.0, confirm_ms=500, candidate_window_ms=1000)
        ts = 1000
        pose = {"center": (0.5, 0.4), "aspect_ratio": 0.5}
        r, c = fd.update(pose, "standing", ts)
        assert not r

        ts += 50
        pose2 = {"center": (0.5, 0.8), "aspect_ratio": 1.3}
        r, c = fd.update(pose2, "lying", ts)
        assert not r

        ts += 600
        r, c = fd.update(pose2, "lying", ts)
        assert r is True and c > 0.0

    except AssertionError:
        print("TEST FAILED")
        raise
    else:
        print("TESTS PASSED")


if __name__ == '__main__':
    run()
