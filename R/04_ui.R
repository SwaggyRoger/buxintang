# ---------------------------------------------------------------------------
# 04_ui.R  —  主題、卦象元件、籤解排版
# ---------------------------------------------------------------------------

APP_NAME    <- "卜心堂"
APP_TAGLINE <- "六爻金錢卦・解籤問心"

# --- 主題 ------------------------------------------------------------------
buxin_theme <- function() {
  bslib::bs_theme(
    version   = 5,
    bg        = "#0B0908",
    fg        = "#FFFFFF",
    primary   = "#C9A227",
    secondary = "#C4C4C4",
    base_font = bslib::font_collection(
      "Noto Serif TC", "Songti TC", "PMingLiU", "serif"
    ),
    "font-size-base" = "1rem",
    "body-bg"        = "#0B0908",
    "border-radius"  = "2px"
  )
}

head_assets <- function() {
  htmltools::tags$head(
    htmltools::tags$link(rel = "preconnect", href = "https://fonts.googleapis.com"),
    htmltools::tags$link(rel = "preconnect", href = "https://fonts.gstatic.com",
                         crossorigin = NA),
    htmltools::tags$link(
      rel  = "stylesheet",
      href = paste0("https://fonts.googleapis.com/css2",
                    "?family=Noto+Serif+TC:wght@400;500;600;900",
                    "&display=swap")
    ),
    htmltools::tags$link(rel = "stylesheet", href = "styles.css"),
    htmltools::tags$script(src = "ritual.js", defer = NA),
    htmltools::tags$title(paste0(APP_NAME, "・", APP_TAGLINE)),
    htmltools::tags$meta(name = "viewport",
                         content = "width=device-width, initial-scale=1")
  )
}

# --- 爻與卦的視覺 ----------------------------------------------------------

#' 單一爻。y 為 NULL 時畫尚未擲出的虛位。
yao_row <- function(y, delay_i = 0L, show_title = TRUE) {
  # 不列爻題時「不輸出」爻題元素，而不是把它藏起來：
  # grid 是按子元素順序落欄的，藏起來（display:none）會讓後面的欄位整排位移。
  title_tag <- function(txt) if (show_title) htmltools::div(class = "yao__title", txt)

  if (is.null(y)) {
    return(htmltools::div(
      class = "yao yao--pending",
      title_tag(" "),
      # 未擲之爻畫成一整條虛線：還沒定陰陽，不該長得像陰爻
      htmltools::div(class = "yao__glyph", htmltools::tags$i(class = "bar-full")),
      htmltools::div(class = "yao__mark", " ")
    ))
  }

  bars <- if (isTRUE(y$is_yang)) {
    list(htmltools::tags$i(class = "bar-full"))
  } else {
    list(htmltools::tags$i(), htmltools::tags$i())
  }

  # 老陽記 ○，老陰記 ✕ —— 傳統卦紙上的動爻記號
  mark <- if (isTRUE(y$is_moving)) (if (isTRUE(y$is_yang)) "○" else "✕") else " "

  htmltools::div(
    class = paste0("yao ",
                   if (isTRUE(y$is_yang)) "yao--yang" else "yao--yin",
                   if (isTRUE(y$is_moving)) " is-moving" else ""),
    style = sprintf("--i:%d", delay_i),
    title_tag(if (is.null(y$title)) " " else y$title),
    htmltools::div(class = "yao__glyph", bars),
    htmltools::div(class = "yao__mark", mark)
  )
}

#' 畫一卦（由上而下：上爻 → 初爻），未擲出者留虛位
hexagram_lines <- function(yao_list, total = 6L, show_title = TRUE) {
  rows <- lapply(total:1L, function(pos) {
    y <- if (pos <= length(yao_list)) yao_list[[pos]] else NULL
    yao_row(y, delay_i = total - pos, show_title = show_title)
  })
  htmltools::div(
    class = paste0("hexagram", if (!show_title) " hexagram--bare"),
    rows
  )
}

#' 一張卦牌（六爻 + 卦名 + 卦辭）
hexagram_card <- function(hex, yao_list, tag, accent = "gold", show_tuan = TRUE) {
  sym <- function(nm) TRIGRAMS$symbol[match(nm, TRIGRAMS$name)]
  htmltools::div(
    class = paste0("guacard guacard--", accent),
    htmltools::div(class = "guacard__tag", tag),
    hexagram_lines(yao_list, show_title = FALSE),
    htmltools::div(
      class = "guacard__name",
      htmltools::span(class = "guacard__no", sprintf("第 %d 卦", hex$no)),
      htmltools::div(class = "guacard__full", hex$full),
      htmltools::div(class = "guacard__tri",
                     sprintf("上%s %s　下%s %s",
                             hex$upper, sym(hex$upper),
                             hex$lower, sym(hex$lower)))
    ),
    if (show_tuan)
      htmltools::div(class = "guacard__tuan",
                     htmltools::div(class = "label", "卦辭"),
                     htmltools::div(class = "text", hex$tuan),
                     htmltools::div(class = "gist", hex$gist))
  )
}

#' 龜殼。casting = TRUE 時播「搖三下、往左傾倒」的動畫；
#' 因為每擲一次 renderUI 會重建這個節點，動畫自然重播。
shell_html <- function(casting = FALSE) {
  htmltools::div(
    class = paste0("shell", if (casting) " is-casting"),
    htmltools::div(class = "shell__dome"),
    htmltools::div(class = "shell__rim")
  )
}

#' 三枚銅錢（字為陽，背為陰）
coins_html <- function(coins = NULL) {
  faces <- if (is.null(coins)) rep(NA_integer_, 3L) else coins
  htmltools::div(
    class = "coins",
    lapply(seq_len(3L), function(i) {
      f   <- faces[i]
      cls <- if (is.na(f)) "coin coin--blank"
             else if (f == COIN_YANG) "coin coin--yang"
             else "coin coin--yin"
      htmltools::div(
        class = cls, style = sprintf("--c:%d", i - 1L),
        htmltools::span(if (is.na(f)) "" else if (f == COIN_YANG) "字" else "背")
      )
    })
  )
}

# --- 小元件 ----------------------------------------------------------------

#' 一支蠟燭。burn 0 = 全新、1 = 燒盡；擲卦時隨爻數往下燒，
#' 所以它同時是進度，不只是裝飾。
candle <- function(burn = 0, small = FALSE) {
  htmltools::div(
    class = paste0("candle", if (small) " candle--sm"),
    style = sprintf("--burn:%.3f", max(0, min(1, burn))),
    htmltools::div(class = "candle__flame"),
    htmltools::div(class = "candle__wick"),
    htmltools::div(class = "candle__wax"),
    htmltools::div(class = "candle__base")
  )
}

ember    <- function() htmltools::div(class = "ember", htmltools::div(class = "ember__glow"))
seal     <- function(text) htmltools::div(class = "seal", htmltools::span(text))
ink_rule <- function() htmltools::div(class = "ink-rule")
quiet    <- function(...) htmltools::div(class = "quiet", ...)

# --- 籤解排版 --------------------------------------------------------------

# 必須與 03_interpreter.R 的 SYSTEM_PROMPT 回覆格式完全一致，
# 對不上的話那一段不會被分區，小標會變成正文裡的一行字。
# tests/test-divination.R 有一項專門檢查這件事。
READING_HEADS <- c("籤解", "打個比方", "所以呢", "啟")

#' 把解籤師的回覆切成三段來排版。
#' R 的 strsplit 不支援零寬 lookahead 切割（零長比對會被逐字元拆開），
#' 因此先插哨符再切；取段用 nchar/substring，避開多位元組的索引位移。
render_reading <- function(txt, stamp = NULL) {
  txt <- gsub("\r\n", "\n", txt, fixed = TRUE)

  stamp_tag <- if (!is.null(stamp))
    htmltools::div(class = "reading__stamp", paste0("錄於　", stamp))

  marker <- paste0("【(?:", paste(READING_HEADS, collapse = "|"), ")】")
  marked <- gsub(paste0("(", marker, ")"), "\x01\\1", txt, perl = TRUE)
  parts  <- trimws(unlist(strsplit(marked, "\x01", fixed = TRUE)))
  parts  <- parts[nzchar(parts)]

  headed <- grepl(paste0("^", marker), parts)

  # 解籤師若沒照格式回，整段素排，不要開天窗
  if (!any(headed)) {
    return(htmltools::div(
      class = "reading",
      htmltools::div(class = "reading__body",
                     lapply(split_paragraphs(txt), htmltools::tags$p)),
      stamp_tag
    ))
  }

  blocks <- lapply(parts[headed], function(p) {
    m        <- regmatches(p, regexpr("^【[^】]+】", p))
    head_txt <- gsub("[【】]", "", m)
    body_txt <- trimws(substring(p, nchar(m) + 1L))
    cls <- switch(head_txt,
                  "籤解"     = "block block--main",
                  "打個比方" = "block block--example",
                  "所以呢"   = "block block--advice",
                  "啟"       = "block block--line",
                  "block")
    htmltools::div(
      class = cls,
      htmltools::div(class = "block__head", head_txt),
      htmltools::div(class = "block__body",
                     lapply(split_paragraphs(body_txt), htmltools::tags$p))
    )
  })

  htmltools::div(class = "reading", blocks, stamp_tag)
}

split_paragraphs <- function(x) {
  parts <- trimws(unlist(strsplit(x, "\n+")))
  parts[nzchar(parts)]
}
