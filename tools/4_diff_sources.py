# -*- coding: utf-8 -*-
"""
兩個獨立來源的經文比對：
  A = zh.wikisource.org 《周易》（已解析成結構化的卦辭／爻辭）
  B = 易學網 的經文原文段落（該站聲明古籍原文屬公共領域）

比對時把標點與常見異體字正規化，只看「字是否相同」。
標點本來就是後人所加，各版本不同，不算差異。
"""
import json, os, re, sys

sys.stdout.reconfigure(encoding="utf-8")
S = os.path.dirname(os.path.abspath(__file__))
wiki = json.load(open(os.path.join(S, "zhouyi_parsed.json"), encoding="utf-8"))
eee = json.load(open(os.path.join(S, "eee_raw.json"), encoding="utf-8"))

YAO = ["初九","初六","九二","六二","九三","六三",
       "九四","六四","九五","六五","上九","上六","用九","用六"]

PUNCT = "，。；：、！？「」『』（）·．"
VARIANT = [("無","无"),("恆","恒"),("羣","群"),("後","后"),("於","于"),
           ("巳","已"),("薦","荐"),("彙","彚"),("災","灾"),("凶","兇")]

def norm(t):
    t = re.sub("[%s\\s]" % PUNCT, "", t or "")
    for a, b in VARIANT:
        t = t.replace(a, b)
    return t

def split_eee(block):
    """把易學網那一整段拆成 卦辭 + 各爻辭"""
    pos = []
    for y in YAO:
        for sep in ("，", "："):
            i = block.find(y + sep)
            if i >= 0:
                pos.append((i, y, len(y) + 1))
                break
    pos.sort()
    if not pos:
        return None, {}
    tuan = block[:pos[0][0]]
    out = {}
    for k, (i, y, off) in enumerate(pos):
        end = pos[k + 1][0] if k + 1 < len(pos) else len(block)
        out[y] = block[i + off:end]
    return tuan, out

# 卦序 -> 卦名
byno = {r["no"]: n for n, r in wiki.items() if r.get("no")}

checked = agree = 0
mismatches = []
no_witness = []

for n in range(1, 65):
    name = byno.get(n)
    blk = eee.get(str(n))
    if not name:
        continue
    if not blk:
        no_witness.append("%d %s" % (n, name))
        continue
    _, eee_yao = split_eee(blk)
    for y in wiki[name]["yao"]:
        t = y["title"]
        if t not in eee_yao:
            mismatches.append((name, t, "易學網缺此爻", y["text"], ""))
            continue
        checked += 1
        a, b = norm(y["text"]), norm(eee_yao[t])
        if a == b:
            agree += 1
        else:
            mismatches.append((name, t, "字有差異", y["text"], eee_yao[t]))

print("=" * 76)
print("可交叉比對的爻辭：%d 條   完全一致：%d 條   一致率 %.1f%%"
      % (checked, agree, 100.0 * agree / checked if checked else 0))
print("只有單一來源（易學網 URL 規則不同，未取得）：%d 卦" % len(no_witness))
print("   ", "、".join(no_witness))
print("=" * 76)

if mismatches:
    print("\n差異明細（%d 筆）：" % len(mismatches))
    for nm, t, why, a, b in mismatches:
        print("\n  【%s・%s】%s" % (nm, t, why))
        print("    wikisource：", a)
        print("    易學網    ：", b)
