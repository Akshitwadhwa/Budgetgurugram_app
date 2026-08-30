def evaluate_zero_result(found: int, last_successful_found: int) -> str:
    """A broken source must degrade to stale data, never empty data."""
    if found == 0 and last_successful_found > 0:
        return "suspect"
    return "ok"
