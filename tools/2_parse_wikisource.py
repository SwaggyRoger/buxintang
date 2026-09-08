# -*- coding: utf-8 -*-
"""
解析快取的 wikitext，取出每一卦的：卦序、上下卦、卦辭、六條爻辭（乾坤另有用九／用六）。

用 wiki 清單的前綴來抓，不靠內容比對——
  **<span color:blue>  = 卦辭
  *#<span color:blue>  = 爻辭
藍色 span 只標經文，傳文（彖／象／文言）沒有，所以不會混進來。
"""
import json, os, re, sys

sys.stdout.reconfigure(encoding="utf-8")
SCRATCH = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(SCRATCH, "wikisource_zhouyi.json")
OUT = os.path.join(SCRATCH, "zhouyi_parsed.json")

CN_NUM = {"一":1,"二":2,"三":3,"四":4,"五":5,"六":6,"七":7,"八":8,"九":9,"十":10}

def cn2int(s):
    if "十" not in s:
        return sum(CN_NUM[c] for c in s)
    a, _, b = s.partition("十")
    return (CN_NUM[a] if a else 1) * 10 + (CN_NUM[b] if b else 0)

def clean(t):
    t = re.sub(r"-\{(?:[A-Za-z-]+\|)?(.*?)\}-", r"\1", t)   # -{无}- / -{zh-hant|X}-
    t = re.sub(r"\{\{\*\|.*?\}\}", "", t)                    # {{*|一作太和}} 校記
    t = re.sub(r"\{\{.*?\}\}", "", t)
    t = re.sub(r"\[\[(?:[^\]|]*\|)?([^\]]*)\]\]", r"\1", t)
    t = re.sub(r"<[^>]+>", "", t)
    t = t.replace("'''", "").replace("''", "")
    t = re.sub(r"^[*#:;]+", "", t.strip())      # 去掉 wiki 清單前綴 ** 與 *#
    return re.sub(r"\s+", "", t).strip()

YAO_TITLES = ["初九","初六","九二","六二","九三","六三",
              "九四","六四","九五","六五","上九","上六","用九","用六"]

# 頁名與經文裡用字不同的
ALIAS = {"坎": ["習坎", "坎"], "恒": ["恆", "恒"]}


def parse(name, wt):
    rec = {"name": name}

    m = re.search(r"第([一二三四五六七八九十]+)卦", wt)
    rec["no"] = cn2int(m.group(1)) if m else None

    m = re.search(r"(?:-\{)?([乾坤震巽坎離艮兌])(?:\}-)?下(?:-\{)?([乾坤震巽坎離艮兌])(?:\}-)?上", wt)
    if m:
        rec["lower"], rec["upper"] = m.group(1), m.group(2)

    tuan, yao = None, []
    for raw in wt.split("\n"):
        line = raw.strip()
        if 'color:blue' not in line:
            continue
        body = clean(line)
        if not body or body == "易經：":
            continue

        if line.startswith("*#"):
            hit = next((t for t in YAO_TITLES
                        if body.startswith(t + "：") or body.startswith(t + "，")), None)
            if hit:
                yao.append({"title": hit, "text": body[len(hit) + 1:].strip()})
            else:
                yao.append({"title": None, "text": body})
        elif line.startswith("**") and tuan is None:
            for nm in ALIAS.get(name, [name]):
                if body.startswith(nm + "："):
                    body = body[len(nm) + 1:]
                    break
            tuan = body.strip()

    rec["tuan"] = tuan
    rec["yao"] = yao
    return rec


if __name__ == "__main__":
    data = json.load(open(CACHE, encoding="utf-8"))
    out, problems = {}, []
    for title, wt in data.items():
        name = title.split("/", 1)[1]
        r = parse(name, wt)
        out[name] = r
        want = 7 if name in ("乾", "坤") else 6
        if len(r["yao"]) != want:
            problems.append("%s: 爻辭 %d 條（應為 %d）" % (name, len(r["yao"]), want))
        for y in r["yao"]:
            if y["title"] is None:
                problems.append("%s: 有爻辭抓不到爻題 -> %s" % (name, y["text"][:26]))
        if not r["tuan"]:
            problems.append("%s: 抓不到卦辭" % name)
        if not r.get("lower"):
            problems.append("%s: 抓不到上下卦" % name)
        if not r.get("no"):
            problems.append("%s: 抓不到卦序" % name)

    print("解析 %d 卦，爻辭共 %d 條" % (len(out), sum(len(r["yao"]) for r in out.values())))
    if problems:
        print("\n仍有問題：")
        for p in problems:
            print("  ", p)
    else:
        print("結構全部符合預期（64 卦 × 6 爻 ＋ 用九 ＋ 用六 = 386）")

    json.dump(out, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("\n已寫出 ->", OUT)

    for n in ["履", "否", "坎", "艮"]:
        r = out[n]
        print("\n--- %s（第%s卦，%s下%s上）---" % (n, r["no"], r.get("lower"), r.get("upper")))
        print("  卦辭：", r["tuan"])
        for y in r["yao"]:
            print("  %s：%s" % (y["title"], y["text"]))
