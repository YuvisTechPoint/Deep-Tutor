"use client";

import {
  type ReactNode,
  useCallback,
  useEffect,
  useId,
  useRef,
  useSyncExternalStore,
} from "react";
import { createPortal } from "react-dom";
import { AnimatePresence, motion } from "framer-motion";

export interface AppModalProps {
  open: boolean;
  onClose: () => void;
  children: ReactNode;
  /** Called when backdrop is clicked; default same as onClose */
  onBackdropClick?: () => void;
  /** `id` of the visible dialog title element (for `aria-labelledby`) */
  dialogTitleId?: string;
  /** `id` of the dialog description element (for `aria-describedby`) */
  dialogDescriptionId?: string;
  /** Screen-reader label for the dimmed backdrop dismiss control */
  backdropAriaLabel?: string;
}

export function AppModal({
  open,
  onClose,
  children,
  onBackdropClick,
  dialogTitleId,
  dialogDescriptionId,
  backdropAriaLabel = "Close",
}: AppModalProps) {
  const isClient = useSyncExternalStore(
    () => () => {},
    () => true,
    () => false,
  );
  const panelRef = useRef<HTMLDivElement>(null);
  const autoId = useId();
  const fallbackTitleId = `${autoId}-title`;
  const titleId = dialogTitleId ?? fallbackTitleId;

  const handleEscape = useCallback(
    (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    },
    [onClose],
  );

  useEffect(() => {
    if (!open) return;
    document.addEventListener("keydown", handleEscape);
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", handleEscape);
      document.body.style.overflow = prev;
    };
  }, [open, handleEscape]);

  useEffect(() => {
    if (!open) return;
    const t = window.setTimeout(() => {
      const root = panelRef.current;
      if (!root) return;
      const focusable = root.querySelector<HTMLElement>(
        'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])',
      );
      (focusable ?? root).focus();
    }, 0);
    return () => window.clearTimeout(t);
  }, [open]);

  if (!isClient || typeof document === "undefined") return null;

  const backdrop = onBackdropClick ?? onClose;

  return createPortal(
    <AnimatePresence>
      {open ? (
        <div
          className="fixed inset-0 z-[240] flex items-center justify-center p-4 sm:p-6"
          role="presentation"
        >
          <motion.button
            type="button"
            aria-label={backdropAriaLabel}
            className="absolute inset-0 bg-black/55 backdrop-blur-[2px]"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.2 }}
            onClick={backdrop}
          />
          <motion.div
            ref={panelRef}
            role="dialog"
            aria-modal="true"
            aria-labelledby={titleId}
            aria-describedby={dialogDescriptionId}
            tabIndex={-1}
            className="relative z-10 w-full max-w-md overflow-hidden rounded-2xl border border-[var(--border)] bg-[var(--card)] text-[var(--card-foreground)] shadow-[0_24px_64px_-12px_rgba(0,0,0,0.45)] outline-none ring-1 ring-black/5 dark:ring-white/5"
            initial={{ opacity: 0, scale: 0.96, y: 10 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.96, y: 10 }}
            transition={{ type: "spring", damping: 28, stiffness: 360 }}
            onClick={(e) => e.stopPropagation()}
          >
            {children}
          </motion.div>
        </div>
      ) : null}
    </AnimatePresence>,
    document.body,
  );
}
