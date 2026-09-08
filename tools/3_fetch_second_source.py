# -*- coding: utf-8 -*-
"""
從易學網取回六十四卦的「經文原文」段落，作為 Wikisource 之外的第二個見證。

只取古籍原文（該站版權聲明明列為公共領域）。
站上 Jack 撰寫的解說、白話翻譯與考證受著作權保護，一律不取、不入庫。
"""
import json, os, re, sys, time, urllib.request

sys.stdout.reconfigure(encoding="utf-8")
S = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(S, "eee_raw.json")
UA = {"User-Agent": "Mozilla/5.0 (compatible; buxintang-research/1.0; personal I Ching app)"}

YAO = ["初九","初六","九二","六二","九三","六三",
       "九四","六四","九五","六五","上九","上六","用九","用六"]


def fetch(n):
    url = "https://www.eee-learning.com/book/neweee%d" % n
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=45) as r:
        return r.read().decode("utf-8", "replace")


def scripture_block(html):
    """抓經文那一段：卦辭 + 六條爻辭連在一起的那個段落。"""
    text = re.sub(r"<script.*?</script>|<style.*?</style>", "", html, flags=re.S)
    paras = re.findall(r"<p[^>]*>(.*?)</p>", text, re.S)
    best, best_hits = None, 0
    for p in paras:
        t = re.sub(r"<[^>]+>", "", p)
        t = t.replace("&nbsp;", "").replace("&amp;", "&")
        t = re.sub(r"\s+", "", t)
        hits = sum(1 for y in YAO if (y + "，") in t or (y + "：") in t)
        # 經文段的特徵：一段裡出現六個以上爻題，而且沒有《彖》《象》
        if hits > best_hits and "《" not in t and "曰" not in t:
            best, best_hits = t, hits
    return best if best_hits >= 6 else None


if __name__ == "__main__":
    data = json.load(open(CACHE, encoding="utf-8")) if os.path.exists(CACHE) else {}
    todo = [n for n in range(1, 65) if str(n) not in data]
    print("待抓 %d 卦" % len(todo))
    for n in todo:
        try:
            html = fetch(n)
            blk = scripture_block(html)
            data[str(n)] = blk
            print("  %2d  %s" % (n, (blk[:46] + "…") if blk else "!! 抓不到經文段"))
        except Exception as e:
            print("  %2d  失敗: %s" % (n, e))
            data[str(n)] = None
        time.sleep(1.5)
        json.dump(data, open(CACHE, "w", encoding="utf-8"), ensure_ascii=False, indent=1)

    ok = sum(1 for v in data.values() if v)
    print("\n成功取得 %d / 64" % ok)
