# ---------------------------------------------------------------------------
# 02_casting.R  —  起卦、變卦、斷卦法
#
# 起卦法：三枚銅錢，擲六次，由初爻至上爻。
#   一擲三錢，字（陽面）計 3，背（陰面）計 2，合計得 6/7/8/9：
#     6 老陰（‑‑ ×）動爻，變陽
#     7 少陽（——）靜爻
#     8 少陰（‑‑）靜爻
#     9 老陽（—— ○）動爻，變陰
#   機率：6=1/8、7=3/8、8=3/8、9=1/8（金錢卦本法，非大衍筮法）
# ---------------------------------------------------------------------------

COIN_YANG <- 3L  # 字面
COIN_YIN  <- 2L  # 背面

#' 擲一爻：回傳三枚錢的正反與合數
toss_one <- function() {
  coins <- sample(c(COIN_YIN, COIN_YANG), 3L, replace = TRUE)
  list(coins = coins, value = as.integer(sum(coins)))
}

#' 爻的屬性
yao_info <- function(value) {
  list(
    value    = value,
    is_yang  = value %in% c(7L, 9L),
    is_moving = value %in% c(6L, 9L),
    label = switch(as.character(value),
                   "6" = "老陰", "7" = "少陽",
                   "8" = "少陰", "9" = "老陽")
  )
}

#' 六個擲值 -> 完整卦象（本卦、之卦、動爻、互卦、斷卦法）
build_divination <- function(values) {
  stopifnot(length(values) == 6L, all(values %in% 6:9))
  values <- as.integer(values)

  ben_lines  <- as.integer(values %in% c(7L, 9L))       # 本卦：老陽/少陽為陽
  moving     <- which(values %in% c(6L, 9L))            # 動爻位置（由下而上）
  zhi_lines  <- ben_lines
  zhi_lines[moving] <- 1L - zhi_lines[moving]           # 動爻變其反

  ben <- hex_lookup(ben_lines)
  zhi <- if (length(moving) > 0L) hex_lookup(zhi_lines) else NULL

  # 互卦：下互取 2,3,4 爻，上互取 3,4,5 爻
  hu <- hex_lookup(c(ben_lines[2:4], ben_lines[3:5]))

  list(
    values  = values,
    yao     = lapply(seq_len(6L), function(i) {
      info <- yao_info(values[i])
      info$pos   <- i
      info$title <- yao_title(i, info$is_yang)
      info
    }),
    ben     = ben,
    zhi     = zhi,
    hu      = hu,
    moving  = moving,
    rule    = zhuxi_rule(ben, zhi, moving)
  )
}

#' 朱熹《易學啟蒙》變占法：依動爻數決定該用哪段經文斷卦
zhuxi_rule <- function(ben, zhi, moving) {
  n <- length(moving)
  ttl <- function(hex, pos) yao_title(pos, hex$lines[pos] == 1L)

  if (n == 0L) {
    return(list(
      n = 0L,
      headline = "六爻不變",
      detail = sprintf("以本卦《%s》卦辭斷之。", ben$name),
      focus  = sprintf("%s卦辭", ben$name)
    ))
  }
  if (n == 1L) {
    p <- moving[1]
    return(list(
      n = 1L,
      headline = "一爻變",
      detail = sprintf("以本卦《%s》變爻「%s」之爻辭斷之。", ben$name, ttl(ben, p)),
      focus  = sprintf("%s・%s", ben$name, ttl(ben, p))
    ))
  }
  if (n == 2L) {
    lo <- moving[1]; hi <- moving[2]
    return(list(
      n = 2L,
      headline = "二爻變",
      detail = sprintf("以本卦《%s》兩變爻「%s」「%s」之爻辭斷之，以上爻「%s」為主。",
                       ben$name, ttl(ben, lo), ttl(ben, hi), ttl(ben, hi)),
      focus  = sprintf("%s・%s（主）、%s", ben$name, ttl(ben, hi), ttl(ben, lo))
    ))
  }
  if (n == 3L) {
    return(list(
      n = 3L,
      headline = "三爻變",
      detail = sprintf("以本卦《%s》與之卦《%s》兩卦辭參斷，本卦為貞（主），之卦為悔（次）。",
                       ben$name, zhi$name),
      focus  = sprintf("%s卦辭（貞）＋%s卦辭（悔）", ben$name, zhi$name)
    ))
  }
  if (n == 4L) {
    still <- setdiff(1:6, moving)          # 之卦中的兩個不變爻
    lo <- still[1]; hi <- still[2]
    return(list(
      n = 4L,
      headline = "四爻變",
      detail = sprintf("以之卦《%s》兩不變爻「%s」「%s」之爻辭斷之，以下爻「%s」為主。",
                       zhi$name, ttl(zhi, lo), ttl(zhi, hi), ttl(zhi, lo)),
      focus  = sprintf("%s・%s（主）、%s", zhi$name, ttl(zhi, lo), ttl(zhi, hi))
    ))
  }
  if (n == 5L) {
    p <- setdiff(1:6, moving)[1]
    return(list(
      n = 5L,
      headline = "五爻變",
      detail = sprintf("以之卦《%s》唯一不變爻「%s」之爻辭斷之。", zhi$name, ttl(zhi, p)),
      focus  = sprintf("%s・%s", zhi$name, ttl(zhi, p))
    ))
  }
  # n == 6
  if (ben$name == "乾") {
    return(list(n = 6L, headline = "六爻皆變",
                detail = "乾之六爻皆變，用「用九：見群龍无首，吉」斷之。",
                focus = "乾・用九"))
  }
  if (ben$name == "坤") {
    return(list(n = 6L, headline = "六爻皆變",
                detail = "坤之六爻皆變，用「用六：利永貞」斷之。",
                focus = "坤・用六"))
  }
  list(n = 6L, headline = "六爻皆變",
       detail = sprintf("六爻盡變，以之卦《%s》卦辭斷之。", zhi$name),
       focus  = sprintf("%s卦辭", zhi$name))
}

# --- 時辰 ------------------------------------------------------------------
SHICHEN <- c("子", "丑", "寅", "卯", "辰", "巳",
             "午", "未", "申", "酉", "戌", "亥")

# 起卦的時辰要是「問卦的人所在的時辰」，不是伺服器的時間。
# shinyapps.io 的機器跑 UTC，若不指定時區，台灣上午九點會被記成丑時。
# 這裡固定用台北時間（本 App 是繁體中文、面向台灣使用者）。
DIVINATION_TZ <- "Asia/Taipei"

#' 依 24 小時制回傳十二時辰（子時跨 23:00–01:00）
shichen_of <- function(t = Sys.time(), tz = DIVINATION_TZ) {
  h <- as.integer(format(t, "%H", tz = tz))
  SHICHEN[((h + 1L) %/% 2L) %% 12L + 1L]
}

#' 起卦落款：卜卦講究記下時、地、人；此處記時
cast_stamp <- function(t = Sys.time(), tz = DIVINATION_TZ) {
  sprintf("%s　%s時", format(t, "%Y年%m月%d日", tz = tz), shichen_of(t, tz))
}

# --- 卜不過三 --------------------------------------------------------------
# 《易・蒙》：「初筮告，再三瀆，瀆則不告。」
# 同一件事反覆起卦即為「瀆」，此處以問句正規化後計次。

normalize_question <- function(q) {
  q <- tolower(trimws(q))
  gsub("[[:space:][:punct:]，。？！、；：「」『』（）…—]", "", q)
}

#' 回傳此問題「即將是」第幾次起卦
ask_count <- function(ledger, question) {
  key <- normalize_question(question)
  if (nchar(key) == 0L) return(1L)
  as.integer(ledger[[key]] %||% 0L) + 1L
}

record_ask <- function(ledger, question) {
  key <- normalize_question(question)
  if (nchar(key) == 0L) return(ledger)
  ledger[[key]] <- as.integer(ledger[[key]] %||% 0L) + 1L
  ledger
}

`%||%` <- function(a, b) if (is.null(a)) b else a
