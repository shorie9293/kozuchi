#!/usr/bin/env python3
"""DB初期化スクリプト"""
import sys
sys.path.insert(0, '.')
from server import init_db, seed_demo_data
init_db()
seed_demo_data()
print('DB initialized OK')
