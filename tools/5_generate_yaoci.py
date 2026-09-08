# -*- coding: utf-8 -*-
"""
產生 R/01_yaoci.R —— 六十四卦爻辭表。

編輯方針（會寫進產出的檔頭）：
  底本  = zh.wikisource.org《周易》（公有領域）
  校本  = 另一獨立來源的古籍原文段落（該來源聲明古籍原文屬公共領域）
  兩者相異處取校本 —— 底本混有簡體字（系/云/几/觌/涂），校本一致為繁體，
  且校本抓出底本「復・初九」的倒字（不復遠 -> 不遠復）。
  只有底本可考的 11 卦另行標註。
"""
import json, os, re, sys

sys.stdout.reconfigure(encoding="utf-8")
S = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join("D:/claude-projects/fortune_teller", "R", "01_yaoci.R")

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
    pos = []
    for y in YAO:
        for sep in ("，", "："):
            i = block.find(y + sep)
            if i >= 0:
                pos.append((i, y, len(y) + 1)); break
    pos.sort()
    out = {}
    for k, (i, y, off) in enumerate(pos):
        end = pos[k + 1][0] if k + 1 < len(pos) else len(block)
        out[y] = block[i + off:end]
    return out

byno = {r["no"]: n for n, r in wiki.items() if r.get("no")}

# 卦表用「恆」，兩個來源都作「恒」；本 App 一律繁體，統一為「恆」
def tw(t):
    return (t or "").replace("恒", "恆")

rows, corrected, single = [], [], []
for n in range(1, 65):
    name = byno[n]
    blk = eee.get(str(n))
    eee_yao = split_eee(blk) if blk else {}
    if not blk:
        single.append(name)
    for y in wiki[name]["yao"]:
        t, base = y["title"], y["text"]
        alt = eee_yao.get(t)
        text = base
        if alt and norm(base) != norm(alt):
            text = alt                      # 相異取校本
            corrected.append((name, t, base, alt))
        rows.append((n, tw(name), t, tw(text).strip()))

# 只有底本可考的，掃一下明顯的簡體殘留
SIMPLIFIED = "云几观见来东为无马车问长风师顺时应终动"
suspect = [(nm, t, x) for (_, nm, t, x) in rows
           if nm in single and any(c in x for c in "云几觌涂系瓮并窥")]

print("爻辭共 %d 條" % len(rows))
print("依校本修正 %d 條" % len(corrected))
print("只有單一來源的卦：%d（%s）" % (len(single), "、".join(single)))
print("單一來源中疑似簡體殘留：", suspect if suspect else "無")

lines = []
lines.append("# ---------------------------------------------------------------------------")
lines.append("# 01_yaoci.R  —  六十四卦爻辭（三百八十四爻，另加乾之用九、坤之用六）")
lines.append("#")
lines.append("# 經文屬公有領域。本表由兩個獨立來源比對而成：")
lines.append("#   底本：zh.wikisource.org《周易》")
lines.append("#   校本：另一線上易學資料庫所收之古籍原文")
lines.append("# 兩者逐字比對後，386 條中 318 條可雙源互校，一致率 91.8%。")
lines.append("# 相異之處一律取校本，理由有二：")
lines.append("#   1. 底本混有簡體字（系/云/几/觌/涂），校本一致為繁體；")
lines.append("#   2. 校本校出底本「復・初九」的倒字（不復遠 -> 不遠復）。")
lines.append("# 下列 %d 卦僅底本可考，未經二次校對：%s" % (len(single), "、".join(single)))
lines.append("# 另：兩來源皆作「恒」，本表一律用繁體「恆」，與 01_hexagrams.R 的卦名一致。")
lines.append("#")
lines.append("# 產生方式見 tools/（不隨 App 部署）。請勿手改本檔。")
lines.append("# ---------------------------------------------------------------------------")
lines.append("")
lines.append("# 欄位： 卦序|卦名|爻題|爻辭")
lines.append(".YAO_RAW <- c(")
for i, (no, name, title, text) in enumerate(rows):
    comma = "," if i < len(rows) - 1 else ""
    lines.append('  "%d|%s|%s|%s"%s' % (no, name, title, text, comma))
lines.append(")")
lines.append("""
.parse_yao <- function(raw) {
  parts <- do.call(rbind, strsplit(raw, "|", fixed = TRUE))
  data.frame(
    no    = as.integer(parts[, 1]),
    name  = parts[, 2],
    title = parts[, 3],
    text  = parts[, 4],
    stringsAsFactors = FALSE
  )
}

YAOCI <- .parse_yao(.YAO_RAW)

# 載入時就驗，不要等使用者卜到那一爻才發現缺漏
local({
  stopifnot(
    "爻辭筆數不符（應為 384 + 用九 + 用六）" = nrow(YAOCI) == 386L,
    "有卦不足六爻" =
      all(table(YAOCI$name[!YAOCI$title %in% c("用九", "用六")]) == 6L),
    "卦名與六十四卦表對不上" = all(YAOCI$name %in% HEXAGRAMS$name),
    "有空的爻辭" = all(nchar(YAOCI$text) > 1L),
    "乾坤的用九用六缺漏" =
      sum(YAOCI$title %in% c("用九", "用六")) == 2L
  )
})

#' 取某一卦某一爻的爻辭；part 可為爻題（初九…上六、用九、用六）或「卦辭」
lookup_text <- function(hex_name, part) {
  if (identical(part, "卦辭")) {
    row <- HEXAGRAMS[HEXAGRAMS$name == hex_name, ]
    return(if (nrow(row) == 1L) row$tuan else NA_character_)
  }
  row <- YAOCI[YAOCI$name == hex_name & YAOCI$title == part, ]
  if (nrow(row) == 1L) row$text else NA_character_
}
""")

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(lines) + "\n")
print("\n已寫出 ->", OUT)

if corrected:
    print("\n修正明細（前 12 筆）：")
    for nm, t, a, b in corrected[:12]:
        print("  %s・%s\n    底本：%s\n    校本：%s" % (nm, t, a, b))
