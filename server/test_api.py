#!/usr/bin/env python3
"""Flask APIの簡易結合テスト"""
import sys
import os
# Ensure we can import the server module
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import json
import server as server_module
app = server_module.app

with app.test_client() as client:
    # Test health
    resp = client.get('/api/health')
    assert resp.status_code == 200
    data = resp.get_json()
    assert data['status'] == 'ok'
    print(f'✅ Health: {data}')

    # Test transactions
    resp = client.get('/api/transactions?user_id=user_001&limit=3')
    data = resp.get_json()
    assert resp.status_code == 200
    assert 'data' in data
    print(f'✅ Transactions: {data["count"]}件')
    if data['data']:
        print(f'   First: {json.dumps(data["data"][0], ensure_ascii=False)}')

    # Test quest generation
    resp = client.post('/api/quests/generate', 
                       json={'user_id': 'user_001', 'seed': 42})
    data = resp.get_json()
    assert resp.status_code == 200
    assert 3 <= data['count'] <= 5, f"Expected 3-5, got {data['count']}"
    print(f'✅ Quests: {data["count"]}件 | week_start: {data["week_start"]}')
    for q in data['quests']:
        print(f'   [{q["id"]}] {q["difficulty_label"]:4s} | {q["category"]:6s} | '
              f'¥{q["target_amount"]:>5,} (avg ¥{q["recent_weekly_avg"]:>5,}) | '
              f'{q["guardian_deity"]}')
    
    # Test get quests for user
    resp = client.get('/api/quests/user_001')
    data = resp.get_json()
    assert resp.status_code == 200
    print(f'✅ Get quests: {data["count"]}件')

print('\n🎉 ALL API TESTS PASSED')
