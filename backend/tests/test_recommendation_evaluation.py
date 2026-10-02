"""Tests for recommendation evaluation metrics (Precision@K, Recall@K, NDCG@K, MRR)."""
import math
from scripts.evaluate_recommendations import (
    precision_at_k,
    recall_at_k,
    ndcg_at_k,
    reciprocal_rank,
    generate_synthetic_interaction_dataset,
    evaluate_ranking_models,
    model_random,
    model_popularity,
    model_trenzy_heuristic,
)


def test_precision_at_k():
    rec = ["p1", "p2", "p3", "p4", "p5"]
    rel = {"p1", "p3", "p9"}
    # Hits in top 5: p1, p3 -> 2/5 = 0.4
    assert precision_at_k(rec, rel, 5) == 0.4
    # Hits in top 2: p1 -> 1/2 = 0.5
    assert precision_at_k(rec, rel, 2) == 0.5
    assert precision_at_k([], rel, 5) == 0.0


def test_recall_at_k():
    rec = ["p1", "p2", "p3", "p4", "p5"]
    rel = {"p1", "p3", "p9", "p10"}
    # Hits in top 5: p1, p3 -> 2/4 = 0.5
    assert recall_at_k(rec, rel, 5) == 0.5
    assert recall_at_k(rec, set(), 5) == 0.0


def test_reciprocal_rank():
    rec = ["p2", "p3", "p1"]
    rel = {"p1"}
    # p1 is at index 2 (rank 3) -> 1/3
    assert math.isclose(reciprocal_rank(rec, rel), 1.0 / 3.0)
    assert reciprocal_rank(["p4", "p5"], rel) == 0.0


def test_ndcg_at_k():
    rec = ["p1", "p2", "p3"]
    rel = {"p1", "p2", "p3"}
    # Perfect ranking NDCG = 1.0
    assert math.isclose(ndcg_at_k(rec, rel, 3), 1.0)


def test_evaluation_pipeline():
    users, products, ground_truth = generate_synthetic_interaction_dataset(
        num_users=10, num_products=50
    )
    models = {
        "Random": model_random,
        "Popularity": model_popularity,
        "Trenzy": model_trenzy_heuristic,
    }
    results = evaluate_ranking_models(models, users, products, ground_truth, k_list=[5, 10])
    assert "Trenzy" in results
    assert "P@5" in results["Trenzy"]
    assert "NDCG@5" in results["Trenzy"]
    assert results["Trenzy"]["P@5"] > 0.0
