import sys

import requests

print('Testing react edit API...')
try:
    r = requests.post('http://127.0.0.1:8001/api/v1/co_writer/edit_react', json={
        'selected_text': 'This is a test paragraph to be rewritten. It contains extra   spaces.',
        'mode': 'rewrite'
    }, timeout=10)
    print('Status:', r.status_code)
    print(r.text)
except Exception as e:
    print('Request failed:', e)
    sys.exit(2)
