from app.pipelines.action_model import ActionModel


def run():
    am = ActionModel(model_path="/none", labels=["standing"], input_size=3, hidden_size=0, num_layers=0, device="cpu", _model=None)
    label, conf = am.predict([[0.0, 0.0, 0.0]])
    assert label == "unknown" and conf == 0.0
    print("action_model fallback OK")


if __name__ == '__main__':
    run()
