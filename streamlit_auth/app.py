"""Minimal external auth UI demo for Next.js marketing redirects.

Run:
    pip install streamlit
    streamlit run streamlit_auth/app.py

Point Next.js `NEXT_PUBLIC_STREAMLIT_APP_URL` at http://127.0.0.1:8501 (or your URL).

Marketing/login URLs append ``mode=login`` or ``mode=signup`` and merge ``next``, ``plan``, etc.
"""

from __future__ import annotations

import streamlit as st

st.set_page_config(page_title="DeepTutor Auth (demo)", layout="centered")

mode_raw = st.query_params.get("mode") or "login"
mode = mode_raw.lower() if isinstance(mode_raw, str) else "login"

st.title("DeepTutor · External auth (demo)")
st.caption("Replace this stub with your real SSO / signup flow.")

with st.expander("Incoming query params (debug)", expanded=False):
    st.json(dict(st.query_params))

if mode == "signup":
    st.subheader("Sign up")
    st.info(
        "This is ``mode=signup``. Capture ``plan``, ``next``, etc. from the URL if needed."
    )
elif mode == "login":
    st.subheader("Sign in")
    st.info(
        "This is ``mode=login``. After authentication, redirect users back to the Next "
        "app (see ``next`` query param) with your session cookie or token flow."
    )
else:
    st.warning(f"Unknown mode `{mode}` — expected `login` or `signup`.")

st.markdown(
    "[DeepTutor web docs](/) · Configure ``NEXT_PUBLIC_STREAMLIT_APP_URL`` in ``web/.env.local``."
)
