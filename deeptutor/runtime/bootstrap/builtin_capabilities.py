"""Built-in capability class paths."""

BUILTIN_CAPABILITY_CLASSES: dict[str, str] = {
    "chat": "deeptutor.capabilities.chat:ChatCapability",
    "deep_solve": "deeptutor.capabilities.deep_solve:DeepSolveCapability",
    "deep_question": "deeptutor.capabilities.deep_question:DeepQuestionCapability",
    "deep_research": "deeptutor.capabilities.deep_research:DeepResearchCapability",
    "study_plan": "deeptutor.capabilities.study_plan:StudyPlanCapability",
    "math_animator": "deeptutor.capabilities.math_animator:MathAnimatorCapability",
    "visualize": "deeptutor.capabilities.visualize:VisualizeCapability",
    # AI Tutor Platform — multi-model specialist capabilities
    "coding_mentor": "deeptutor.capabilities.coding_mentor:CodingMentorCapability",
    "assessment": "deeptutor.capabilities.assessment:AssessmentCapability",
    "career_agent": "deeptutor.capabilities.career_agent:CareerAgentCapability",
}
