setwd("D:/claude-projects/fortune_teller")
suppressMessages({ library(shiny); library(bslib); library(httr2) })
for (f in list.files("R", full.names = TRUE)) source(f, encoding = "UTF-8")
invisible(source("app.R", encoding = "UTF-8"))

ok <- function(msg) cat("  ok  ", msg, "\n")
fail <- function(msg) { cat("  FAIL", msg, "\n"); assign("N_FAIL", get0("N_FAIL", ifnotfound = 0) + 1, .GlobalEnv) }
chk <- function(cond, msg) if (isTRUE(cond)) ok(msg) else fail(msg)

cat("\n== 1. 六十四卦表 ==\n")
chk(nrow(HEXAGRAMS) == 64, "64 筆")
chk(length(unique(HEXAGRAMS$key)) == 64, "上下卦組合唯一且齊全")
chk(all(nchar(HEXAGRAMS$tuan) > 2), "每卦皆有卦辭")

# 全 8x8 組合都查得到，且回查一致
bad <- character(0)
for (lo in 0:7) for (up in 0:7) {
  l3 <- as.integer(intToBits(lo))[1:3]; u3 <- as.integer(intToBits(up))[1:3]
  h <- hex_lookup(c(l3, u3))
  if (trigram_code(h$lines[1:3]) != lo || trigram_code(h$lines[4:6]) != up)
    bad <- c(bad, h$full)
}
chk(length(bad) == 0, "64 組上下卦皆可反查一致")

cat("\n== 2. 已知卦象校驗 ==\n")
known <- list(
  list(c(1,1,1,1,1,1), 1,  "乾為天"),
  list(c(0,0,0,0,0,0), 2,  "坤為地"),
  list(c(1,0,0,0,1,0), 3,  "水雷屯"),   # 下震 100, 上坎 010
  list(c(1,1,1,0,0,0), 11, "地天泰"),
  list(c(0,0,0,1,1,1), 12, "天地否"),
  list(c(1,0,1,0,1,0), 63, "水火既濟"),
  list(c(0,1,0,1,0,1), 64, "火水未濟"),
  list(c(0,0,0,0,0,1), 23, "山地剝"),   # 下坤 000, 上艮 001
  list(c(1,0,0,0,0,0), 24, "地雷復")
)
for (k in known) {
  h <- hex_lookup(k[[1]])
  chk(h$no == k[[2]] && h$full == k[[3]],
      sprintf("%s -> 第%d卦 %s (得 第%d卦 %s)",
              paste(k[[1]], collapse = ""), k[[2]], k[[3]], h$no, h$full))
}

cat("\n== 3. 動爻與之卦 ==\n")
# 乾卦六爻皆老陽 -> 之坤
dv <- build_divination(rep(9L, 6))
chk(dv$ben$name == "乾" && dv$zhi$name == "坤" && length(dv$moving) == 6,
    "六個老陽：乾 之 坤，六爻皆動")
chk(grepl("用九", dv$rule$detail), "乾六爻皆變 -> 用九")

dv <- build_divination(rep(6L, 6))
chk(dv$ben$name == "坤" && dv$zhi$name == "乾", "六個老陰：坤 之 乾")
chk(grepl("用六", dv$rule$detail), "坤六爻皆變 -> 用六")

dv <- build_divination(c(7L, 8L, 7L, 8L, 7L, 8L))
chk(is.null(dv$zhi) && length(dv$moving) == 0, "無動爻則無之卦")
chk(dv$rule$n == 0 && grepl("卦辭", dv$rule$detail), "六爻不變 -> 用本卦卦辭")

# 一爻變：初爻老陽，其餘少陰 -> 本卦 地雷復(24)，之卦 坤(2)
dv <- build_divination(c(9L, 8L, 8L, 8L, 8L, 8L))
chk(dv$ben$no == 24 && dv$zhi$no == 2, "一爻變：復 之 坤")
chk(dv$rule$n == 1 && grepl("初九", dv$rule$detail), "一爻變 -> 本卦初九爻辭")

cat("\n== 4. 朱熹變占法涵蓋 0-6 動爻 ==\n")
for (nmv in 0:6) {
  vals <- rep(8L, 6); if (nmv > 0) vals[seq_len(nmv)] <- 6L
  dv <- build_divination(vals)
  r <- dv$rule
  chk(r$n == nmv && nzchar(r$headline) && nzchar(r$detail) && nzchar(r$focus),
      sprintf("%d 爻變：%s — %s", nmv, r$headline, r$detail))
}

cat("\n== 5. 爻題 ==\n")
chk(yao_title(1, TRUE) == "初九", "初九")
chk(yao_title(1, FALSE) == "初六", "初六")
chk(yao_title(3, TRUE) == "九三", "九三")
chk(yao_title(5, FALSE) == "六五", "六五")
chk(yao_title(6, TRUE) == "上九", "上九")
chk(yao_title(6, FALSE) == "上六", "上六")

cat("\n== 6. 互卦 ==\n")
# 既濟 101010 -> 下互爻234=010(坎) 上互爻345=101(離) -> 火水未濟
dv <- build_divination(c(7L, 8L, 7L, 8L, 7L, 8L))
chk(dv$ben$full == "水火既濟" && dv$hu$full == "火水未濟", "既濟之互卦為未濟")

cat("\n== 7. 擲錢分布 ==\n")
set.seed(1)
v <- replicate(40000, toss_one()$value)
tb <- table(v) / length(v)
chk(all(names(tb) == c("6","7","8","9")), "只出現 6/7/8/9")
chk(abs(tb[["6"]] - .125) < .01 && abs(tb[["7"]] - .375) < .01 &&
    abs(tb[["8"]] - .375) < .01 && abs(tb[["9"]] - .125) < .01,
    sprintf("金錢卦機率 1/8,3/8,3/8,1/8 (實得 %s)",
            paste(sprintf("%.3f", tb), collapse = ",")))

cat("\n== 8. 時辰 ==\n")
h2s <- function(h) shichen_of(as.POSIXct(sprintf("2026-01-01 %02d:30:00", h),
                                        tz = "Asia/Taipei"))
chk(h2s(23) == "子" && h2s(0) == "子", "23:xx / 00:xx 為子時")
chk(h2s(1) == "丑" && h2s(2) == "丑", "01-03 為丑時")
chk(h2s(11) == "午" && h2s(12) == "午", "11-13 為午時")
chk(h2s(22) == "亥", "21-23 為亥時")

# 伺服器跑 UTC（shinyapps.io 就是），時辰仍要以台北時間為準
utc_instant <- as.POSIXct("2026-09-08 01:30:00", tz = "UTC")   # 台北 09:30
chk(shichen_of(utc_instant) == "巳",
    sprintf("UTC 01:30 -> 台北 09:30 -> 巳時（得 %s）", shichen_of(utc_instant)))
chk(grepl("2026年09月08日　巳時", cast_stamp(utc_instant)),
    sprintf("落款用台北日期時辰（得 %s）", cast_stamp(utc_instant)))
chk(DIVINATION_TZ == "Asia/Taipei", "起卦時區固定為 Asia/Taipei")

cat("\n== 9. 卜不過三 ==\n")
L <- list()
chk(ask_count(L, "該不該換工作？") == 1, "首問為第 1 次")
L <- record_ask(L, "該不該換工作？")
chk(ask_count(L, "該不該換工作?") == 2, "標點/全半形不同視為同一問")
L <- record_ask(L, "該不該換工作?")
chk(ask_count(L, " 該不該換工作 ") == 3, "空白不同視為同一問 -> 第 3 次即瀆")
chk(ask_count(L, "該不該分手？") == 1, "不同問題各自計數")

cat("\n== 10. 提示詞與卦單 ==\n")
dv <- build_divination(c(9L, 8L, 7L, 6L, 8L, 7L))
brief <- format_hexagram_brief(dv, "要不要辭掉現在的工作？", cast_stamp(), 2L)
chk(grepl("【本卦】", brief) && grepl("【之卦】", brief) &&
    grepl("【斷卦法】", brief) && grepl("【互卦】", brief), "卦單四大區塊齊備")
chk(grepl("第 2 次起卦", brief), "再筮已寫入卦單")
chk(grepl("深諳人情世故的解籤師", SYSTEM_PROMPT), "解籤師人格已定位")
chk(all(vapply(READING_HEADS, function(h) grepl(paste0("【", h, "】"), SYSTEM_PROMPT), logical(1))),
    "提示詞的四段小標與排版器認得的完全一致")
chk(grepl("舉例", SYSTEM_PROMPT) && grepl("六百到九百字", SYSTEM_PROMPT),
    "已要求舉例並放寬篇幅")
cat("\n---- 卦單樣本 ----\n"); cat(brief); cat("\n------------------\n")

cat("\n== 11. UI 渲染 ==\n")
mk <- function(stage, tosses, dv, nth = 1L)
  list(stage = stage, question = "要不要辭掉現在的工作？", tosses = tosses,
       dv = dv, stamp = cast_stamp(), nth = nth, reading = NULL, err = NULL)
tos <- lapply(c(9L, 8L, 7L, 6L, 8L, 7L), function(v) list(coins = c(3L,3L,3L), value = v))

render_ok <- function(lbl, expr) {
  r <- tryCatch({ h <- as.character(expr); nchar(h) > 50 }, error = function(e) { cat("   ", conditionMessage(e), "\n"); FALSE })
  chk(r, lbl)
}
render_ok("入堂",   view_threshold())
render_ok("落筆",   view_asking(NULL))
render_ok("擲卦(0)", view_casting(mk("casting", list(), NULL)))
render_ok("擲卦(3)", view_casting(mk("casting", tos[1:3], NULL, nth = 2L)))
render_ok("卦成",   view_formed(mk("formed", tos, dv)))
render_ok("沉吟",   view_pondering())
render_ok("瀆",     view_refused(mk("refused", list(), NULL, nth = 3L)))

sample_reading <- "【籤解】\n你問的這件事，卦上已經動了。\n第二句話。\n\n【打個比方】\n就像你已經把辭呈打好，只是還沒按下寄出。\n\n【所以呢】\n先別急著遞辭呈。\n\n【啟】\n走可以，但別是逃。"
v <- mk("read", tos, dv); v$reading <- sample_reading
render_ok("籤解", view_read(v))
h <- as.character(render_reading(sample_reading, stamp = cast_stamp()))
chk(grepl("block--main", h) && grepl("block--example", h) &&
    grepl("block--advice", h) && grepl("block--line", h),
    "籤解四段皆正確分區（含【打個比方】）")
chk(grepl("錄於", h), "落款在籤紙內")
h2 <- as.character(render_reading("完全沒照格式的一段話。", stamp = "x"))
chk(grepl("reading__body", h2), "未照格式時素排不開天窗")

cat("\n== 12. 離線籤解 ==\n")
off <- offline_reading(dv, "要不要辭掉現在的工作？")
chk(grepl("【籤解】", off) && grepl("【啟】", off), "離線籤解格式完整")

cat("\n== 13. 爻辭表 ==\n")
chk(nrow(YAOCI) == 386L, sprintf("386 條（384 爻 + 用九 + 用六），實得 %d", nrow(YAOCI)))
chk(all(table(YAOCI$name[!YAOCI$title %in% c("用九","用六")]) == 6L), "每卦皆足六爻")
chk(setequal(YAOCI$name, HEXAGRAMS$name), "卦名與六十四卦表完全一致")
chk(all(nchar(YAOCI$text) > 1L), "沒有空的爻辭")
chk(identical(lookup_text("乾", "初九"), "潛龍勿用。"), "乾初九")
chk(identical(lookup_text("坤", "用六"), "利永貞。"), "坤用六")
chk(grepl("^不遠復", lookup_text("復", "初九")),
    sprintf("復初九為「不遠復」而非倒字（得 %s）", lookup_text("復", "初九")))
chk(is.na(lookup_text("乾", "六二")), "乾沒有六二，查無回 NA")
chk(!any(grepl("[云几觌涂瓮窥牀]", YAOCI$text)), "無簡體殘留字")

cat("\n== 14. 變占法：每一種動爻組合都要查得到經文 ==\n")
bad <- character(0)
set.seed(20260908)
for (trial in 1:400) {
  v <- sample(6:9, 6, replace = TRUE)
  d <- build_divination(v)
  for (ct in d$rule$cite) {
    txt <- lookup_text(ct$hex, ct$part)
    if (is.na(txt) || !nzchar(txt)) bad <- c(bad, sprintf("%s・%s", ct$hex, ct$part))
  }
  if (!is.logical(d$rule$zhi_matters)) bad <- c(bad, "zhi_matters 非邏輯值")
}
chk(length(bad) == 0,
    if (length(bad)) paste("查不到經文：", paste(unique(bad), collapse = ", "))
    else "400 次隨機起卦，所有引用的經文都查得到")

cat("\n== 15. 變占規則細節 ==\n")
d <- build_divination(c(9L, 8L, 8L, 8L, 8L, 8L))
chk(d$rule$n == 1L && isFALSE(d$rule$zhi_matters), "一爻變：之卦不必理會")
d <- build_divination(c(9L, 9L, 8L, 8L, 8L, 8L))
chk(grepl("下爻", d$rule$detail) && grepl("貞", d$rule$detail),
    "二爻變：下爻為貞（主）、上爻為悔")
chk(length(d$rule$cite) == 2L &&
    all(vapply(d$rule$cite, function(ct) ct$hex, "") == d$ben$name),
    "二爻變：兩條依據都在本卦")
d <- build_divination(c(9L, 9L, 9L, 9L, 8L, 8L))
chk(d$rule$cite[[1]]$hex == d$zhi$name && d$rule$cite[[1]]$part == "卦辭",
    "四爻變：以之卦卦辭為貞（主）")
d <- build_divination(c(9L, 9L, 9L, 9L, 9L, 8L))
chk(d$rule$cite[[1]]$hex == d$zhi$name, "五爻變：同樣以之卦為貞")
chk(identical(zhuxi_rule, divination_rule), "舊名 zhuxi_rule 仍可用")

cat("\n== 16. 卦單附上經文 ==\n")
d <- build_divination(c(9L, 8L, 7L, 6L, 8L, 7L))
b <- format_hexagram_brief(d, "測試", cast_stamp(), 1L)
chk(grepl("【所斷經文】", b), "卦單含【所斷經文】區塊")
for (ct in d$rule$cite)
  chk(grepl(lookup_text(ct$hex, ct$part), b, fixed = TRUE),
      sprintf("卦單內含《%s》%s 的原文", ct$hex, ct$part))
chk(grepl("不要改寫", b), "卦單明示經文不得改寫")
chk(grepl("一字不改", SYSTEM_PROMPT) && grepl("憑印象", SYSTEM_PROMPT) &&
    grepl("所斷經文", SYSTEM_PROMPT),
    "提示詞要求照卦單的【所斷經文】一字不改地引，不得憑印象補")

cat("\n== 17. 完整 UI 物件 ==\n")
render_ok("page_fluid", ui)

nf <- get0("N_FAIL", ifnotfound = 0)
cat(sprintf("\n=====  %s  =====\n", if (nf == 0) "全部通過" else paste(nf, "項失敗")))
if (nf > 0) quit(status = 1)
