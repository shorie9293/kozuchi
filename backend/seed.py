"""
Achievement definitions seeder for Kozuchi (打ち出の小槌).

Defines ~25 achievements across 9 criteria types. Run once to populate the
achievements table. Idempotent — skips existing keys.

Criteria types:
  - offering_count     : number of offerings (喜捨) made
  - total_donation     : cumulative total of offerings in yen
  - streak_days        : consecutive days with at least one offering
  - categories_used    : number of unique spending categories
  - satori_level       : SATORI enlightenment percentage reached (0-100)
  - guardians_tried    : number of unique guardians (守護神) tried
  - receipt_count      : number of receipts scanned via OCR
  - budget_set_count   : number of times a budget was configured
  - budget_perfect_days: consecutive days staying within budget
"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from database import SessionLocal, init_db
from models import Achievement

ACHIEVEMENTS = [
    # ── 喜捨回数 (offering_count) ──
    dict(key="first_offering", title="初めての喜捨",
         description="初めて喜捨（支出記録）を行った。すべての悟りはここから始まる。",
         criteria_type="offering_count", criteria_value=1, icon="🙏", sort_order=10),
    dict(key="offering_10", title="喜捨の修行者",
         description="喜捨を10回行った。日々の積み重ねが悟りへの道。",
         criteria_type="offering_count", criteria_value=10, icon="📿", sort_order=11),
    dict(key="offering_50", title="喜捨の求道者",
         description="喜捨を50回行った。執着を手放す心が育ってきた。",
         criteria_type="offering_count", criteria_value=50, icon="🎋", sort_order=12),
    dict(key="offering_100", title="喜捨の達人",
         description="喜捨を100回行った。もはや喜捨は日常の一部。",
         criteria_type="offering_count", criteria_value=100, icon="🌸", sort_order=13),

    # ── 累計金額 (total_donation) ──
    dict(key="total_10000", title="壱万円突破",
         description="累計喜捨額が1万円を超えた。小金槌の第一歩。",
         criteria_type="total_donation", criteria_value=10000, icon="💰", sort_order=20),
    dict(key="total_50000", title="伍万円突破",
         description="累計喜捨額が5万円を超えた。金銭感覚が研ぎ澄まされてきた。",
         criteria_type="total_donation", criteria_value=50000, icon="💎", sort_order=21),
    dict(key="total_100000", title="拾万円突破",
         description="累計喜捨額が10万円を超えた。大金槌の担い手たる資格。",
         criteria_type="total_donation", criteria_value=100000, icon="🔨", sort_order=22),
    dict(key="total_500000", title="伍拾万円突破",
         description="累計喜捨額が50万円を超えた。富を操る智慧、ここに極まる。",
         criteria_type="total_donation", criteria_value=500000, icon="👑", sort_order=23),
    dict(key="total_1000000", title="佰万円突破",
         description="累計喜捨額が100万円を超えた。打ち出の小槌、真の覚醒。",
         criteria_type="total_donation", criteria_value=1000000, icon="🌟", sort_order=24),

    # ── 連続記録 (streak_days) ──
    dict(key="streak_3", title="三日坊主ならず",
         description="3日連続で喜捨を記録した。継続は力なり。",
         criteria_type="streak_days", criteria_value=3, icon="🔥", sort_order=30),
    dict(key="streak_7", title="七日修行",
         description="7日連続で喜捨を記録した。一週間の精進。",
         criteria_type="streak_days", criteria_value=7, icon="🌅", sort_order=31),
    dict(key="streak_14", title="二週間の悟り道",
         description="14日連続で喜捨を記録。半月の積み重ね。",
         criteria_type="streak_days", criteria_value=14, icon="🌙", sort_order=32),
    dict(key="streak_30", title="月影の修行者",
         description="30日連続で喜捨を記録。一ヶ月、影の如く精進した。",
         criteria_type="streak_days", criteria_value=30, icon="🗓️", sort_order=33),
    dict(key="streak_100", title="百日回峰行",
         description="100日連続で喜捨を記録。千日回峰行の十分の一、されど偉業。",
         criteria_type="streak_days", criteria_value=100, icon="⛰️", sort_order=34),

    # ── カテゴリ制覇 (categories_used) ──
    dict(key="categories_3", title="三界の探求者",
         description="3つの異なるカテゴリで喜捨を行った。世界は広い。",
         criteria_type="categories_used", criteria_value=3, icon="🔍", sort_order=40),
    dict(key="categories_all", title="全カテゴリ制覇",
         description="すべてのカテゴリで喜捨を行った。支出の曼荼羅、ここに完成。",
         criteria_type="categories_used", criteria_value=999, icon="🌈", sort_order=41),

    # ── SATORIレベル (satori_level) ──
    dict(key="satori_25", title="初転法輪",
         description="SATORIゲージが25%に達した。悟りの第一段階。",
         criteria_type="satori_level", criteria_value=25, icon="🕯️", sort_order=50),
    dict(key="satori_50", title="縁起の理",
         description="SATORIゲージが50%に達した。万物の繋がりが見え始める。",
         criteria_type="satori_level", criteria_value=50, icon="☸️", sort_order=51),
    dict(key="satori_75", title="空の境地",
         description="SATORIゲージが75%に達した。色即是空、空即是色。",
         criteria_type="satori_level", criteria_value=75, icon="🌀", sort_order=52),
    dict(key="satori_100", title="大悟徹底",
         description="SATORIゲージが100%に達した。もはや金銭は数字にあらず。",
         criteria_type="satori_level", criteria_value=100, icon="✨", sort_order=53),

    # ── 守護神 (guardians_tried) ──
    dict(key="all_guardians", title="四天王との対話",
         description="4柱すべての守護神と対話した。大黒天・毘沙門天・弁財天・吉祥天。",
         criteria_type="guardians_tried", criteria_value=4, icon="🗿", sort_order=60),

    # ── レシート撮影 (receipt_count) ──
    dict(key="receipt_5", title="レシート収集家",
         description="レシートを5枚撮影した。デジタルの証左。",
         criteria_type="receipt_count", criteria_value=5, icon="📸", sort_order=70),
    dict(key="receipt_20", title="レシートの匠",
         description="レシートを20枚撮影した。もはやレシートを見れば金額が浮かぶ。",
         criteria_type="receipt_count", criteria_value=20, icon="🧾", sort_order=71),

    # ── 予算設定 (budget_set_count) ──
    dict(key="budget_master", title="予算設定の達人",
         description="3回以上予算を設定した。計画なき支出は迷走なり。",
         criteria_type="budget_set_count", criteria_value=3, icon="📊", sort_order=80),
    dict(key="budget_perfect_7", title="予算完全遵守",
         description="7日連続で予算内に収めた。規律こそ自由への鍵。",
         criteria_type="budget_perfect_days", criteria_value=7, icon="✅", sort_order=81),
]


def seed(db=None):
    """
    Seed the achievements table. Idempotent — skips keys that already exist.

    Args:
        db: optional existing session. If None, creates its own.

    Returns:
        int: number of achievements inserted (not skipped).
    """
    own_session = db is None
    if own_session:
        db = SessionLocal()

    try:
        existing_keys = {a.key for a in db.query(Achievement.key).all()}
        inserted = 0
        for a in ACHIEVEMENTS:
            if a["key"] in existing_keys:
                continue
            db.add(Achievement(**a))
            inserted += 1
        db.commit()
        return inserted
    finally:
        if own_session:
            db.close()


if __name__ == "__main__":
    init_db()
    n = seed()
    print(f"✅ Seeded {n} new achievements "
          f"({len(ACHIEVEMENTS) - n} already existed)")
