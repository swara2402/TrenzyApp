"""Quality gate evaluation for recommendation and search models."""

import logging
from dataclasses import dataclass, field
from typing import Dict, List, Any, Optional

from ..config.settings import EVALUATION_GATES

logger = logging.getLogger(__name__)


@dataclass
class GateCheckResult:
    """Detailed result of gate evaluation."""
    passed: bool
    failures: List[str] = field(default_factory=list)
    gate_details: Dict[str, Dict[str, Any]] = field(default_factory=dict)
    model_version: str = "unknown"

    def summary(self) -> str:
        status = "PASSED" if self.passed else "FAILED"
        lines = [f"=== Model Quality Gate: {status} (Model: {self.model_version}) ==="]
        for metric, details in self.gate_details.items():
            check_status = "PASS" if details["passed"] else "FAIL"
            lines.append(
                f"  [{check_status}] {metric}: actual={details['actual']:.4f}, "
                f"threshold={details['threshold']:.4f} ({details['comparison']})"
            )
        if self.failures:
            lines.append("\nFailures:")
            for f in self.failures:
                lines.append(f"  - {f}")
        return "\n".join(lines)


class ModelQualityGates:
    """Enforces strict evaluation gates before model promotion."""

    def __init__(self, thresholds: Optional[Dict[str, float]] = None):
        self.thresholds = thresholds or EVALUATION_GATES

    def evaluate(
        self,
        metrics: Dict[str, float],
        model_version: str = "candidate",
        total_interactions: int = 0,
    ) -> GateCheckResult:
        """Evaluate model metrics against gate thresholds."""
        failures = []
        gate_details = {}

        # First gate: Data volume sufficiency
        if total_interactions < 1000:
            failures.append(
                f"INSUFFICIENT REAL DATA: Model evaluated on {total_interactions} interactions. "
                "Minimum required is 1,000 real positive user interactions."
            )

        # Gate: Precision@10
        min_p10 = self.thresholds.get("min_precision_at_10", 0.15)
        p10 = metrics.get("precision_at_10", 0.0)
        p10_pass = p10 >= min_p10
        gate_details["precision_at_10"] = {
            "actual": p10, "threshold": min_p10, "comparison": ">=", "passed": p10_pass
        }
        if not p10_pass:
            failures.append(f"Precision@10 {p10:.4f} < threshold {min_p10:.4f}")

        # Gate: Recall@10
        min_r10 = self.thresholds.get("min_recall_at_10", 0.20)
        r10 = metrics.get("recall_at_10", 0.0)
        r10_pass = r10 >= min_r10
        gate_details["recall_at_10"] = {
            "actual": r10, "threshold": min_r10, "comparison": ">=", "passed": r10_pass
        }
        if not r10_pass:
            failures.append(f"Recall@10 {r10:.4f} < threshold {min_r10:.4f}")

        # Gate: NDCG@10
        min_ndcg = self.thresholds.get("min_ndcg_at_10", 0.25)
        ndcg = metrics.get("ndcg_at_10", 0.0)
        ndcg_pass = ndcg >= min_ndcg
        gate_details["ndcg_at_10"] = {
            "actual": ndcg, "threshold": min_ndcg, "comparison": ">=", "passed": ndcg_pass
        }
        if not ndcg_pass:
            failures.append(f"NDCG@10 {ndcg:.4f} < threshold {min_ndcg:.4f}")

        # Gate: Hit Rate@10
        min_hr = self.thresholds.get("min_hit_rate_at_10", 0.30)
        hr = metrics.get("hit_rate_at_10", 0.0)
        hr_pass = hr >= min_hr
        gate_details["hit_rate_at_10"] = {
            "actual": hr, "threshold": min_hr, "comparison": ">=", "passed": hr_pass
        }
        if not hr_pass:
            failures.append(f"Hit Rate@10 {hr:.4f} < threshold {min_hr:.4f}")

        # Gate: Catalog Coverage
        min_cov = self.thresholds.get("min_catalog_coverage", 0.10)
        cov = metrics.get("catalog_coverage", 0.0)
        cov_pass = cov >= min_cov
        gate_details["catalog_coverage"] = {
            "actual": cov, "threshold": min_cov, "comparison": ">=", "passed": cov_pass
        }
        if not cov_pass:
            failures.append(f"Catalog coverage {cov:.4f} < threshold {min_cov:.4f}")

        passed = len(failures) == 0
        return GateCheckResult(
            passed=passed,
            failures=failures,
            gate_details=gate_details,
            model_version=model_version,
        )
