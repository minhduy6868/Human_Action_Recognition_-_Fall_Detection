from app.pipelines.fall_model import FallModel


def run():
    # simulate a FallModel instance with no xgboost available
    fm = FallModel(model_path="/nonexistent", _model=None)
    score = fm.predict([0.0, 0.1, 0.2])
    assert score == 0.0
    print("fall_model predict fallback OK")


if __name__ == '__main__':
    run()
