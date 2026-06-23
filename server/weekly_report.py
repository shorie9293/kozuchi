#!/usr/bin/env python3
"""
週次支出レポート生成モジュール (kozuchi backend)

提供機能:
  - 週間取引の集計（カテゴリ別TOP3）
  - SATORI変化計算（貯蓄率の週間差分）
  - ルールベースアドバイス生成
  - レポートのDB保存（スケジューラー向け）

用法:
    from weekly_report import generate_weekly_report
    report = generate_weekly_report(user_id='user_001', week_str='2026-W25')
"""

from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional

DB_PATH = Path.home() / "Takamagahara" / "utsushiyo" / "kozuchi" / "server" / "kozuchi.db"


# ── 週文字列パース ──────────────────────────────────────────

def parse_week(week_str: str) -> tuple[datetime, datetime]:
    """
    'YYYY-WWW' 形式の週文字列を (月曜日, 日曜日) の datetime に変換する。

    Example:
        parse_week('2026-W25') → (datetime(2026,6,15), datetime(2026,6,21))
    """
    # ISO週の月曜日を取得: '%G-W%V-%u' = ISO年-週-曜日(1=月曜)
    monday = datetime.strptime(f'{week_str}-1', '%G-W%V-%u')
    sunday = monday + timedelta(days=6, hours=23, minutes=59, seconds=59)
    return monday, sunday


def get_current_week_str() -> str:
    """今日を含むISO週の文字列を返す (例: '2026-W25')"""
    today = datetime.now()
    iso = today.isocalendar()
    return f'{iso[0]}-W{iso[1]:02d}'


# ── DB操作 ──────────────────────────────────────────────────

def _get_conn() -> sqlite3.Connection:
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    return conn


def get_week_transactions(
    conn: sqlite3.Connection,
    user_id: str,
    week_start: datetime,
    week_end: datetime,
) -> list[dict]:
    """指定週の取引データを取得する。"""
    rows = conn.execute(
        """
        SELECT amount, purpose, category, datetime
        FROM transactions
        WHERE user_id = ?
          AND datetime >= ?
          AND datetime <= ?
        ORDER BY datetime
        """,
        (
            user_id,
            week_start.strftime('%Y-%m-%d'),
            week_end.strftime('%Y-%m-%dT23:59:59'),
        ),
    ).fetchall()
    return [dict(r) for r in rows]


def _ensure_reports_table(conn: sqlite3.Connection) -> None:
    """weekly_reports テーブルが存在しなければ作成する。"""
    conn.execute("""
        CREATE TABLE IF NOT EXISTS weekly_reports (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            week TEXT NOT NULL,
            week_start TEXT NOT NULL,
            data TEXT NOT NULL,
            created_at TEXT NOT NULL DEFAULT (datetime('now')),
            UNIQUE(user_id, week)
        )
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_weekly_reports_user_week
        ON weekly_reports(user_id, week)
    """)
    conn.commit()


def store_report(
    conn: sqlite3.Connection,
    user_id: str,
    week_str: str,
    week_start: datetime,
    report: dict,
) -> None:
    """生成したレポートをDBに保存する（スケジューラー・キャッシュ用）。"""
    _ensure_reports_table(conn)
    conn.execute(
        """
        INSERT OR REPLACE INTO weekly_reports (user_id, week, week_start, data, created_at)
        VALUES (?, ?, ?, ?, datetime('now'))
        """,
        (user_id, week_str, week_start.strftime('%Y-%m-%d'), json.dumps(report, ensure_ascii=False)),
    )
    conn.commit()


def get_stored_report(
    conn: sqlite3.Connection,
    user_id: str,
    week_str: str,
) -> Optional[dict]:
    """保存済みのレポートを取得する（キャッシュ）。"""
    _ensure_reports_table(conn)  # 初回呼出時にテーブル自動作成
    row = conn.execute(
        "SELECT data FROM weekly_reports WHERE user_id = ? AND week = ?",
        (user_id, week_str),
    ).fetchone()
    if row:
        return json.loads(row['data'])
    return None


# ── 集計ロジック ────────────────────────────────────────────

def aggregate_weekly(transactions: list[dict]) -> dict:
    """
    週間取引を集計する。

    Returns:
        {
            'total_income': int,
            'total_expense': int,
            'savings': int,
            'savings_rate': float,     # 0.0〜1.0
            'transaction_count': int,
            'by_category': [{category, amount, percentage}, ...]  # 金額降順
        }
    """
    income = 0
    expense = 0
    cat_map: dict[str, int] = {}

    for t in transactions:
        amt = t['amount']
        if amt > 0:
            income += amt
        else:
            abs_amt = abs(amt)
            expense += abs_amt
            cat = t['category'] or '未分類'
            cat_map[cat] = cat_map.get(cat, 0) + abs_amt

    savings = income - expense
    savings_rate = round(savings / income, 3) if income > 0 else 0.0

    by_category = sorted(
        [
            {
                'category': cat,
                'amount': amt,
                'percentage': round((amt / expense * 100) if expense > 0 else 0, 1),
            }
            for cat, amt in cat_map.items()
        ],
        key=lambda x: x['amount'],
        reverse=True,
    )

    return {
        'total_income': income,
        'total_expense': expense,
        'savings': savings,
        'savings_rate': savings_rate,
        'transaction_count': len(transactions),
        'by_category': by_category,
    }


# ── SATORI変化計算 ─────────────────────────────────────────

def compute_satori_change(current: dict, previous: dict) -> dict:
    """
    今週と先週の貯蓄率を比較し、SATORI（悟り）の変化を計算する。

    SATORI = 貯蓄率（収入に対する貯蓄の割合）。
    高いほど「悟りが深い」（無駄遣いが少ない）状態。

    Returns:
        {
            'current_rate': float,
            'previous_rate': float,
            'delta': float,           # 貯蓄率の絶対変化
            'delta_percent': float,   # パーセンテージポイント変化
            'direction': 'increase' | 'decrease' | 'stable',
            'symbol': '↑↑' | '↑' | '→' | '↓' | '↓↓',
            'message': str,
        }
    """
    rate_current = current['savings_rate']
    rate_previous = previous['savings_rate']
    delta = round(rate_current - rate_previous, 3)

    if delta >= 0.05:
        direction = 'increase'
        symbol = '↑↑'
        message = '貯蓄率が大きく改善しました'
    elif delta >= 0.01:
        direction = 'increase'
        symbol = '↑'
        message = '貯蓄率がやや改善しました'
    elif delta <= -0.05:
        direction = 'decrease'
        symbol = '↓↓'
        message = '貯蓄率が大きく低下しました'
    elif delta <= -0.01:
        direction = 'decrease'
        symbol = '↓'
        message = '貯蓄率がやや低下しました'
    else:
        direction = 'stable'
        symbol = '→'
        message = '貯蓄率はほぼ横ばいです'

    return {
        'current_rate': rate_current,
        'previous_rate': rate_previous,
        'delta': delta,
        'delta_percent': round(delta * 100, 1),
        'direction': direction,
        'symbol': symbol,
        'message': message,
    }


# ── アドバイス生成（ルールベース）─────────────────────────

def generate_advice(
    current: dict,
    satori: dict,
    top_categories: list[dict],
) -> str:
    """
    支出パターンとSATORI変化から、日本語のアドバイスを生成する。

    ルール:
      1. 最大支出カテゴリが50%超 → 偏り警告
      2. SATORI低下時 → 自制を促す
      3. SATORI上昇時 → 称賛
      4. 支出総額が高額 → 注意喚起
    """
    parts: list[str] = []

    # 1. 支出カテゴリの偏り
    if top_categories:
        top_cat = top_categories[0]
        pct = top_cat['percentage']
        if pct > 50:
            parts.append(
                f"今週は「{top_cat['category']}」が支出の{pct:.0f}%を占めています。"
                "バランスを見直してみませんか？"
            )
        elif pct > 30 and len(top_categories) >= 2:
            parts.append(
                f"「{top_cat['category']}」への支出({pct:.0f}%)が目立ちます。"
                "来週は少し抑えてみるのも一手です。"
            )

    # 2. SATORIトレンド
    if satori['direction'] == 'decrease':
        if satori['delta'] < -0.05:
            parts.append(
                "貯蓄率が大きく低下しました。"
                "小さな出費も積もれば山——来週は「一分の徳」を意識してみましょう。"
            )
        else:
            parts.append(
                "貯蓄率がやや低下しています。"
                "無駄遣いがないか、一度振り返ってみてください。"
            )
    elif satori['direction'] == 'increase':
        if satori['delta'] > 0.05:
            parts.append(
                "素晴らしい！貯蓄率が大きく改善しました。"
                "この調子で「堅実の道」を歩み続けましょう。"
            )
        else:
            parts.append(
                "貯蓄率が改善しています。良い習慣が身についてきましたね。"
            )
    else:
        # stable
        if current['savings_rate'] > 0.3:
            parts.append("安定した貯蓄率を維持できています。このまま継続しましょう。")
        elif current['total_income'] > 0:
            parts.append("今週は先週とほぼ同じペース。安定は力なり——継続あるのみです。")
        else:
            parts.append("今週も無事に過ごせました。来週も堅実に参りましょう。")

    # 3. 支出総額（絶対額）チェック
    if current['total_expense'] > 80000:
        parts.append("支出総額が8万円を超えています。大きな買い物の前には「一晩置く」習慣を。")
    elif current['total_expense'] > 50000:
        parts.append("支出総額が5万円を超えました。予算を意識して過ごしましょう。")

    # 4. 取引がない場合
    if current['transaction_count'] == 0:
        return "今週は取引データがありません。日々の記録をつけることから始めましょう。"

    if not parts:
        return "今週も堅実に過ごせました。来週もこの調子で参りましょう。"

    return ' '.join(parts)


# ── メイン: 週次レポート生成 ───────────────────────────────

def generate_weekly_report(
    user_id: str,
    week_str: Optional[str] = None,
    conn: Optional[sqlite3.Connection] = None,
    use_cache: bool = True,
) -> dict:
    """
    ユーザーの週次支出レポートを生成する。

    Args:
        user_id: ユーザーID
        week_str: ISO週文字列 ('2026-W25')。None なら今週
        conn: 外部DB接続（None なら内部で生成）
        use_cache: True なら保存済みレポートを再利用

    Returns:
        {
            'user_id': str,
            'week': str,
            'period': {start, end},
            'summary': {total_income, total_expense, savings, savings_rate, transaction_count},
            'top_categories': [{rank, category, amount, percentage}, ...],  # 最大3件
            'satori': {current_rate, previous_rate, delta, delta_percent, direction, symbol, message},
            'advice': str,
            'generated_at': str,
            'cached': bool,
        }
    """
    if week_str is None:
        week_str = get_current_week_str()

    own_conn = conn is None
    if own_conn:
        conn = _get_conn()

    try:
        # キャッシュ確認
        if use_cache:
            cached = get_stored_report(conn, user_id, week_str)
            if cached:
                cached['cached'] = True
                return cached

        week_start, week_end = parse_week(week_str)
        prev_week_start = week_start - timedelta(weeks=1)
        prev_week_end = week_start - timedelta(seconds=1)
        prev_week_str = prev_week_start.strftime('%G-W%V')

        # 取引取得
        current_tx = get_week_transactions(conn, user_id, week_start, week_end)
        previous_tx = get_week_transactions(conn, user_id, prev_week_start, prev_week_end)

        # 集計
        current_agg = aggregate_weekly(current_tx)
        previous_agg = aggregate_weekly(previous_tx)

        # TOP3カテゴリ
        top_categories = current_agg['by_category'][:3]

        # SATORI変化
        satori = compute_satori_change(current_agg, previous_agg)

        # アドバイス
        advice = generate_advice(current_agg, satori, top_categories)

        report = {
            'user_id': user_id,
            'week': week_str,
            'period': {
                'start': week_start.strftime('%Y-%m-%d'),
                'end': (week_end - timedelta(hours=23, minutes=59, seconds=59)).strftime('%Y-%m-%d'),
            },
            'summary': {
                'total_income': current_agg['total_income'],
                'total_expense': current_agg['total_expense'],
                'savings': current_agg['savings'],
                'savings_rate': current_agg['savings_rate'],
                'transaction_count': current_agg['transaction_count'],
            },
            'top_categories': [
                {
                    'rank': i + 1,
                    'category': c['category'],
                    'amount': c['amount'],
                    'percentage': c['percentage'],
                }
                for i, c in enumerate(top_categories)
            ],
            'satori': satori,
            'advice': advice,
            'generated_at': datetime.now().isoformat(),
            'cached': False,
        }

        # 永続化
        store_report(conn, user_id, week_str, week_start, report)

        return report

    finally:
        if own_conn:
            conn.close()
