# Streamlit auth UI demo

Use this to verify Next.js marketing URLs redirect correctly.

```bash
pip install streamlit
streamlit run streamlit_auth/app.py
```

In `web/.env.local` (or repo-root `.env`):

```env
NEXT_PUBLIC_STREAMLIT_APP_URL=http://127.0.0.1:8501
```

The Next app sends users with `?mode=login` or `?mode=signup` (plus merged params such as `next`, `plan`). Read them via:

```python
mode = (st.query_params.get("mode") or "login").lower()
```
