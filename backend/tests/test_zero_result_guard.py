from worker.guards import evaluate_zero_result


def test_zero_after_successful_run_is_suspect():
    assert evaluate_zero_result(found=0, last_successful_found=40) == "suspect"


def test_zero_on_first_run_is_ok():
    assert evaluate_zero_result(found=0, last_successful_found=0) == "ok"


def test_nonzero_is_ok():
    assert evaluate_zero_result(found=12, last_successful_found=40) == "ok"
