# -*- coding: utf-8 -*-
"""
從 zh.wikisource.org 取回《周易》六十四卦的卦辭與爻辭。

文本本身是公有領域。批次查詢 + 退避，避免打爆 API。
抓回來的原始 wikitext 存成快取，之後解析都用快取，不重複請求。
"""
import json, os, sys, time, urllib.parse, urllib.request

sys.stdout.reconfigure(encoding="utf-8")

SCRATCH = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(SCRATCH, "wikisource_zhouyi.json")
UA = {"User-Agent": "buxintang-research/1.0 (personal I Ching Shiny app; low volume)"}

HEX_NAMES = [
    "乾", "坤", "屯", "蒙", "需", "訟", "師", "比",
    "小畜", "履", "泰", "否", "同人", "大有", "謙", "豫",
    "隨", "蠱", "臨", "觀", "噬嗑", "賁", "剝", "復",
    "无妄", "大畜", "頤", "大過", "坎", "離", "咸", "恒",
    "遯", "大壯", "晉", "明夷", "家人", "睽", "蹇", "解",
    "損", "益", "夬", "姤", "萃", "升", "困", "井",
    "革", "鼎", "震", "艮", "漸", "歸妹", "豐", "旅",
    "巽", "兌", "渙", "節", "中孚", "小過", "既濟", "未濟",
]


def api(params, tries=6):
    url = "https://zh.wikisource.org/w/api.php?" + urllib.parse.urlencode(params)
    delay = 2.0
    for attempt in range(tries):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=45) as r:
                return json.loads(r.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            if e.code in (429, 503) and attempt < tries - 1:
                print("      HTTP %d，等 %.0fs 重試" % (e.code, delay))
                time.sleep(delay)
                delay *= 2
                continue
            raise
    raise RuntimeError("retries exhausted")


def fetch_all():
    if os.path.exists(CACHE):
        with open(CACHE, encoding="utf-8") as f:
            data = json.load(f)
        print("使用既有快取：%d 頁" % len(data))
        return data

    titles = ["周易/" + n for n in HEX_NAMES]
    out = {}
    BATCH = 10
    for i in range(0, len(titles), BATCH):
        chunk = titles[i:i + BATCH]
        print("  取 %2d-%2d ..." % (i + 1, i + len(chunk)))
        d = api({"action": "query", "prop": "revisions", "rvprop": "content",
                 "rvslots": "main", "titles": "|".join(chunk), "format": "json"})
        for _, pg in d["query"]["pages"].items():
            if "revisions" not in pg:
                print("      !! 缺頁:", pg.get("title"))
                continue
            out[pg["title"]] = pg["revisions"][0]["slots"]["main"]["*"]
        time.sleep(2.0)

    with open(CACHE, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    print("已快取 %d 頁 -> %s" % (len(out), CACHE))
    return out


if __name__ == "__main__":
    data = fetch_all()
    print("\n取得頁數：", len(data))
    missing = [n for n in HEX_NAMES if "周易/" + n not in data]
    print("缺少：", missing if missing else "無")

    for probe in ["周易/乾", "周易/屯", "周易/坤"]:
        print("\n" + "=" * 70)
        print(probe)
        print("=" * 70)
        print(data[probe][:1400])
