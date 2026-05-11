"""Learning plan generator.

Derives a deterministic, dependency-aware roadmap from the learner's profile
(target_path + goals + experience_level + weekly_hours). The output mirrors the
roadmap UI: phases ↦ milestones ↦ resources.

This is intentionally rule-based for two reasons:

1.  The canonical model routing (Qwen2.5-32B) is configured per-installation
    and the API token may not be present in local-dev. We must not return
    fabricated AI output as if it were real.
2.  Once an HF inference endpoint is provisioned, the planner can call the
    ``deep_solve`` capability to enrich the plan asynchronously; until then the
    deterministic plan is clearly labelled as a *baseline*.
"""

from deeptutor.services.learning_plan.planner import (
    build_plan,
    list_plan_templates,
    plan_signature,
    update_milestone_status,
)

__all__ = ["build_plan", "list_plan_templates", "plan_signature", "update_milestone_status"]
