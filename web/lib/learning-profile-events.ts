/** Fired after learning profile is written so EIP and other views can refetch immediately. */
export const LEARNING_PROFILE_UPDATED = "deeptutor:learning-profile-updated";

export function notifyLearningProfileUpdated(): void {
  if (typeof window === "undefined") return;
  window.dispatchEvent(new CustomEvent(LEARNING_PROFILE_UPDATED));
}
