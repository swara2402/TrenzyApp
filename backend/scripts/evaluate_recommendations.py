"""Offline evaluation framework for Trenzy recommendation heuristics and trend scoring.

This evaluator measures recommendation quality (Precision@K, Recall@K, NDCG@K, MRR)
of Trenzy's rule-based / heuristic scoring pipelines against baseline models
(Global Popularity baseline and Random baseline).

Trenzy Ranking Formulas:
------------------------
1. Blend Social Preference Score:
   Score(p) = sum(swipe_weight(u, p))
   where swipe_weight: love = +2, like = +1, dislike = -1.

2. Attribute & Taxonomy Compatibility:
   Compatibility(u, p) = sum(w_i * Jaccard(u_preferences[i], p_attributes[i]))
   where i in {categories, styles, colors, occasions, brands}.

3. Trend Momentum Score:
   Trend(p, t) = alpha * views(p, t) + beta * saves(p, t) + gamma * blend_shares(p, t)
   with exponential time decay factor: exp(-lambda * delta_hours).

Metrics Evaluated:
------------------
- Precision@K: Fraction of top-K recommended items that are relevant to user interactions.
- Recall@K: Fraction of total relevant items retrieved in top-K recommendations.
- NDCG@K: Normalized Discounted Cumulative Gain accounting for rank positions.
- MRR (Mean Reciprocal Rank): 1 / rank_of_first_relevant_item.
"""
from __future__ import annotations

import math
import random
from typing import Any, Callable


def precision_at_k(recommended: list[str], relevant: set[str], k: int) -> float:
    """Calculate Precision@K."""
    if k <= 0:
        return 0.0
    top_k = recommended[:k]
    if not top_k:
        return 0.0
    hits = sum(1 for item in top_k if item in relevant)
    return hits / k


def recall_at_k(recommended: list[str], relevant: set[str], k: int) -> float:
    """Calculate Recall@K."""
    if not relevant or k <= 0:
        return 0.0
    top_k = recommended[:k]
    hits = sum(1 for item in top_k if item in relevant)
    return hits / len(relevant)


def dcg_at_k(recommended: list[str], relevant: set[str], k: int) -> float:
    """Calculate Discounted Cumulative Gain at K."""
    top_k = recommended[:k]
    dcg = 0.0
    for idx, item in enumerate(top_k):
        if item in relevant:
            dcg += 1.0 / math.log2(idx + 2)
    return dcg


def ndcg_at_k(recommended: list[str], relevant: set[str], k: int) -> float:
    """Calculate Normalized Discounted Cumulative Gain at K."""
    if not relevant or k <= 0:
        return 0.0
    actual_dcg = dcg_at_k(recommended, relevant, k)
    ideal_dcg = sum(1.0 / math.log2(i + 2) for i in range(min(len(relevant), k)))
    if ideal_dcg == 0.0:
        return 0.0
    return actual_dcg / ideal_dcg


def reciprocal_rank(recommended: list[str], relevant: set[str]) -> float:
    """Calculate Reciprocal Rank (1 / rank_of_first_hit)."""
    for idx, item in enumerate(recommended):
        if item in relevant:
            return 1.0 / (idx + 1)
    return 0.0


def generate_synthetic_interaction_dataset(
    num_users: int = 100,
    num_products: int = 500,
    categories: list[str] | None = None,
    seed: int = 42,
) -> tuple[dict[str, dict[str, Any]], dict[str, dict[str, Any]], dict[str, set[str]]]:
    """Generate deterministic synthetic user profiles, catalog, and ground-truth interactions."""
    rng = random.Random(seed)
    categories = categories or ["Dresses", "Tops", "Outerwear", "Footwear", "Accessories", "Denim"]

    products: dict[str, dict[str, Any]] = {}
    for i in range(num_products):
        pid = f"prod_{i:04d}"
        cat = rng.choice(categories)
        pop_score = rng.expovariate(0.05)  # Pareto-like popularity
        products[pid] = {
            "id": pid,
            "category": cat,
            "popularity": pop_score,
            "color": rng.choice(["black", "white", "blue", "beige", "red", "green"]),
            "style": rng.choice(["minimalist", "streetwear", "vintage", "classic", "boho"]),
        }

    users: dict[str, dict[str, Any]] = {}
    ground_truth: dict[str, set[str]] = {}

    for u in range(num_users):
        uid = f"user_{u:03d}"
        pref_cats = rng.sample(categories, k=rng.randint(1, 3))
        pref_style = rng.choice(["minimalist", "streetwear", "vintage", "classic", "boho"])
        pref_colors = rng.sample(["black", "white", "blue", "beige", "red", "green"], k=2)

        users[uid] = {
            "id": uid,
            "preferred_categories": pref_cats,
            "preferred_style": pref_style,
            "preferred_colors": pref_colors,
        }

        # User interacts with products matching their preferences + global popularity
        user_relevant = set()
        for pid, p in products.items():
            match_score = 0.0
            if p["category"] in pref_cats:
                match_score += 2.0
            if p["style"] == pref_style:
                match_score += 1.5
            if p["color"] in pref_colors:
                match_score += 1.0

            # Combined preference + popularity probability
            prob = 1.0 / (1.0 + math.exp(-(match_score + p["popularity"] * 0.05 - 3.0)))
            if rng.random() < prob:
                user_relevant.add(pid)

        # Ensure at least 1 relevant product per user for evaluation validity
        if not user_relevant:
            user_relevant.add(rng.choice(list(products.keys())))

        ground_truth[uid] = user_relevant

    return users, products, ground_truth


# Model 1: Random Baseline
def model_random(
    user: dict[str, Any], products: dict[str, dict[str, Any]], k: int = 10, seed: int = 123
) -> list[str]:
    rng = random.Random(seed + hash(user["id"]))
    all_ids = list(products.keys())
    return rng.sample(all_ids, min(k, len(all_ids)))


# Model 2: Global Popularity Baseline
def model_popularity(
    user: dict[str, Any], products: dict[str, dict[str, Any]], k: int = 10
) -> list[str]:
    sorted_pids = sorted(
        products.keys(), key=lambda pid: products[pid]["popularity"], reverse=True
    )
    return sorted_pids[:k]


# Model 3: Trenzy Hybrid Heuristic (Preference Match + Category + Decay + Popularity)
def model_trenzy_heuristic(
    user: dict[str, Any], products: dict[str, dict[str, Any]], k: int = 10
) -> list[str]:
    pref_cats = set(user.get("preferred_categories", []))
    pref_style = user.get("preferred_style", "")
    pref_colors = set(user.get("preferred_colors", []))

    scored = []
    for pid, p in products.items():
        score = 0.0
        # Category alignment
        if p["category"] in pref_cats:
            score += 3.0
        # Style persona match
        if p["style"] == pref_style:
            score += 2.0
        # Color match
        if p["color"] in pref_colors:
            score += 1.5
        # Popularity prior
        score += min(p["popularity"] * 0.05, 2.0)

        scored.append((pid, score))

    scored.sort(key=lambda item: item[1], reverse=True)
    return [pid for pid, _ in scored[:k]]


def evaluate_ranking_models(
    models: dict[str, Callable[[dict, dict, int], list[str]]],
    users: dict[str, dict[str, Any]],
    products: dict[str, dict[str, Any]],
    ground_truth: dict[str, set[str]],
    k_list: list[int] | None = None,
) -> dict[str, dict[str, float]]:
    """Evaluate multiple recommendation algorithms and compute average metrics across users."""
    k_list = k_list or [5, 10, 20]
    results: dict[str, dict[str, float]] = {}

    for model_name, model_fn in models.items():
        metrics_acc: dict[str, list[float]] = {
            f"P@{k}": [] for k in k_list
        }
        metrics_acc.update({f"R@{k}": [] for k in k_list})
        metrics_acc.update({f"NDCG@{k}": [] for k in k_list})
        metrics_acc["MRR"] = []

        max_k = max(k_list)
        for uid, user in users.items():
            relevant = ground_truth.get(uid, set())
            recs = model_fn(user, products, max_k)

            for k in k_list:
                metrics_acc[f"P@{k}"].append(precision_at_k(recs, relevant, k))
                metrics_acc[f"R@{k}"].append(recall_at_k(recs, relevant, k))
                metrics_acc[f"NDCG@{k}"].append(ndcg_at_k(recs, relevant, k))

            metrics_acc["MRR"].append(reciprocal_rank(recs, relevant))

        # Compute averages
        results[model_name] = {
            metric: sum(vals) / len(vals) if vals else 0.0
            for metric, vals in metrics_acc.items()
        }

    return results


def print_evaluation_report(results: dict[str, dict[str, float]]) -> None:
    """Format and print an evaluation summary table."""
    print("\n" + "=" * 80)
    print("           TRENZY RECOMMENDATION & TREND EVALUATION REPORT")
    print("=" * 80)

    all_metrics = list(next(iter(results.values())).keys())
    header = f"{'Model / Heuristic':<28} | " + " | ".join(f"{m:>8}" for m in all_metrics)
    print(header)
    print("-" * len(header))

    for model_name, metric_vals in results.items():
        row = f"{model_name:<28} | " + " | ".join(
            f"{metric_vals.get(m, 0.0):>8.4f}" for m in all_metrics
        )
        print(row)
    print("=" * 80 + "\n")


if __name__ == "__main__":
    users, products, ground_truth = generate_synthetic_interaction_dataset()
    models = {
        "Random Baseline": model_random,
        "Popularity Baseline": model_popularity,
        "Trenzy Hybrid Heuristic": model_trenzy_heuristic,
    }
    evaluation = evaluate_ranking_models(models, users, products, ground_truth)
    print_evaluation_report(evaluation)
