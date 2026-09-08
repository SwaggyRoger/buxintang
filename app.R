# ===========================================================================
#  卜心堂 — 六爻金錢卦・解籤問心
#
#  單一 app.R 進入點，R/ 目錄由 Shiny 自動載入（Shiny >= 1.5）。
#  部署：見 deploy.R（rsconnect::deployApp，金鑰以 envVars 帶上去，不進 bundle）
# ===========================================================================

library(shiny)
library(bslib)
library(httr2)

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
ui <- bslib::page_fluid(
  theme = buxin_theme(),
  head_assets(),
  htmltools::div(class = "wrap", uiOutput("stage")),
  htmltools::div(
    class = "colophon",
    "卦以決疑，不以代決。所斷者時勢，所行者在你。", htmltools::br(),
    "解籤師由 Claude 扮演，聊備一格，非專業建議。"
  )
)

# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------
server <- function(input, output, session) {

  vals <- reactiveValues(
    stage    = "threshold",
    question = "",
    tosses   = list(),      # 每次擲出的 list(coins=, value=)
    dv       = NULL,        # build_divination() 的結果
    stamp    = NULL,
    nth      = 1L,          # 此問題是第幾次起卦
    reading  = NULL,
    err      = NULL,
    hint     = NULL
  )

  ledger <- reactiveVal(list())   # 卜不過三的帳：問題 -> 次數

  # --- 入堂 ---------------------------------------------------------------
  observeEvent(input$enter, {
    vals$stage <- "asking"
    vals$hint  <- NULL
  })

  # --- 落筆起卦 -----------------------------------------------------------
  observeEvent(input$begin, {
    q <- trimws(input$question %||% "")

    if (nchar(q) < 4L) {
      vals$hint <- "問得太輕了。把心裡真正在意的那件事寫清楚一點，卦才接得住。"
      return()
    }

    n <- ask_count(ledger(), q)

    # 《易・蒙》：初筮告，再三瀆，瀆則不告。
    if (n >= 3L) {
      vals$question <- q
      vals$nth      <- n
      vals$stage    <- "refused"
      return()
    }

    # 這裡先不記帳：中途離座不該算一次。等六爻成卦才入帳（見擲爻處）。
    vals$question <- q
    vals$nth      <- n
    vals$tosses   <- list()
    vals$dv       <- NULL
    vals$reading  <- NULL
    vals$err      <- NULL
    vals$hint     <- NULL
    vals$stamp    <- cast_stamp()
    vals$stage    <- "casting"
  })

  # --- 擲爻 ---------------------------------------------------------------
  observeEvent(input$toss, {
    req(length(vals$tosses) < 6L)
    vals$tosses <- c(vals$tosses, list(toss_one()))

    if (length(vals$tosses) == 6L) {
      vals$dv    <- build_divination(vapply(vals$tosses, `[[`, integer(1), "value"))
      vals$stage <- "formed"
      ledger(record_ask(ledger(), vals$question))   # 卦成，這一問才入帳
    }
  })

  # --- 請解籤師開口 -------------------------------------------------------
  observeEvent(input$ask_master, {
    req(vals$dv)

    # onFlushed 的 callback 不在反應情境裡，在裡面讀 reactiveValues 會直接報錯，
    # 所以要用的值一律先在這裡取出來帶進去（寫入 reactiveValues 則不受限）。
    brief <- format_hexagram_brief(vals$dv, vals$question, vals$stamp, vals$nth)
    dv_now <- vals$dv
    q_now  <- vals$question

    vals$stage <- "pondering"
    vals$err   <- NULL

    # 先把「沉吟中」flush 到瀏覽器，再送出這一趟同步的 API 請求
    session$onFlushed(function() {
      # 這裡若拋例外會直接帶走整個 R process，一定要接住
      res <- tryCatch(call_claude(brief), error = function(e) {
        list(ok = FALSE, kind = "unexpected",
             message = paste0("解籤途中出了岔子：", conditionMessage(e)))
      })

      if (isTRUE(res$ok)) {
        vals$reading <- res$text
      } else {
        vals$err     <- res$message
        vals$reading <- tryCatch(offline_reading(dv_now, q_now),
                                 error = function(e) "卦已成，但籤解未能寫就。請再求一次。")
      }
      vals$stage <- "read"
    }, once = TRUE)
  })

  # --- 收卦 ---------------------------------------------------------------
  observeEvent(input$close_rite, {
    vals$question <- ""
    vals$tosses   <- list()
    vals$dv       <- NULL
    vals$reading  <- NULL
    vals$err      <- NULL
    vals$hint     <- NULL
    vals$stamp    <- NULL
    vals$nth      <- 1L
    vals$stage    <- "asking"   # 問句欄由 renderUI 重建，值自然是空的
  })

  # =========================================================================
  # 版面
  # =========================================================================
  output$stage <- renderUI({
    switch(vals$stage,
           threshold = view_threshold(),
           asking    = view_asking(vals$hint),
           casting   = view_casting(vals),
           formed    = view_formed(vals),
           pondering = view_pondering(),
           read      = view_read(vals),
           refused   = view_refused(vals),
           view_threshold())
  })
}

# ---------------------------------------------------------------------------
# 各階段版面
# ---------------------------------------------------------------------------

view_threshold <- function() {
  htmltools::div(
    class = "stage",
    ember(),
    htmltools::div(
      class = "brand",
      htmltools::h1(class = "brand__name", APP_NAME),
      htmltools::p(class = "brand__tag", APP_TAGLINE),
      htmltools::div(
        class = "brand__creed",
        "不誠不占．不疑不占．不義不占", htmltools::br(),
        "卦不過三"
      )
    ),
    ink_rule(),
    htmltools::div(
      style = "text-align:center",
      quiet(
        "卦不會替你決定。", htmltools::br(),
        "它只是把你心裡早就知道、卻不肯承認的那件事，", htmltools::br(),
        "換一個你聽得進去的說法。"
      )
    ),
    htmltools::div(
      style = "margin-top:3.2rem",
      actionButton("enter", "淨手・入座", class = "btn-rite")
    )
  )
}

view_asking <- function(hint) {
  htmltools::div(
    class = "stage",
    htmltools::div(class = "asked",
                   htmltools::div(class = "asked__label", "心之所疑")),
    htmltools::div(
      class = "ask-field",
      textAreaInput(
        "question", label = NULL, rows = 4, width = "100%",
        placeholder = "落筆於此。\n說得越具體，卦答得越準。"
      )
    ),
    quiet(
      "問一事，成一卦。落筆之後，不再更改。", htmltools::br(),
      "同一件事，至多再問一次；第三次，籤師便不再開口。"
    ),
    if (!is.null(hint)) htmltools::div(class = "notice", hint),
    htmltools::div(
      style = "margin-top:2.6rem",
      actionButton("begin", "心念既定・起卦", class = "btn-rite")
    )
  )
}

view_casting <- function(vals) {
  n     <- length(vals$tosses)
  yao   <- lapply(seq_along(vals$tosses), function(i) {
    info <- yao_info(vals$tosses[[i]]$value)
    info$pos   <- i
    info$title <- yao_title(i, info$is_yang)
    info
  })
  last  <- if (n > 0L) vals$tosses[[n]]$coins else NULL

  htmltools::div(
    class = "stage",
    asked_block(vals),
    if (vals$nth == 2L) re_ask_omen(),
    hexagram_lines(yao, show_title = TRUE),
    coins_html(last),
    htmltools::div(class = "toss-count",
                   sprintf("第 %s 擲・共六擲",
                           c("一", "二", "三", "四", "五", "六")[n + 1L])),
    # 起卦不可中止：六爻必須親手擲滿，中途沒有離座的按鈕。
    actionButton("toss", if (n == 0L) "擲" else "再擲",
                 class = "btn-rite btn-toss"),
    quiet(htmltools::div(style = "margin-top:1.6rem;text-align:center",
                         "三枚銅錢。字為陽，背為陰。", htmltools::br(),
                         "一擲成一爻，由下而上，六擲成卦。", htmltools::br(),
                         "卦既起，不中止。"))
  )
}

view_formed <- function(vals) {
  dv <- vals$dv
  htmltools::div(
    class = "stage",
    asked_block(vals),
    seal(paste0(dv$ben$full, "　", if (is.null(dv$zhi)) "六爻不變" else paste0("之　", dv$zhi$full))),
    htmltools::div(
      class = paste0("gua-pair", if (!is.null(dv$zhi)) " is-two" else ""),
      hexagram_card(dv$ben, dv$yao, "本卦", accent = "gold"),
      if (!is.null(dv$zhi)) {
        zhi_yao <- lapply(seq_len(6L), function(i) {
          yang <- dv$zhi$lines[i] == 1L
          list(is_yang = yang, is_moving = FALSE, pos = i,
               title = yao_title(i, yang))
        })
        hexagram_card(dv$zhi, zhi_yao, "之卦", accent = "cinnabar")
      }
    ),
    htmltools::div(
      class = "rule",
      htmltools::div(class = "rule__head", paste0("斷卦法・", dv$rule$headline)),
      htmltools::div(class = "rule__body", dv$rule$detail),
      htmltools::div(class = "rule__focus", paste0("主要依據：", dv$rule$focus))
    ),
    htmltools::div(
      class = "rule",
      htmltools::div(class = "rule__head", "互卦"),
      htmltools::div(class = "rule__body",
                     paste0(dv$hu$full, "——", dv$hu$gist)),
      htmltools::div(class = "rule__focus", "互卦看的是事情的中段與檯面下的內情。")
    ),
    if (!has_api_key()) htmltools::div(
      class = "notice",
      "尚未設定 ANTHROPIC_API_KEY，籤師今日不在堂上。",
      "仍可取得依卦辭生成的離線籤解。"
    ),
    htmltools::div(
      style = "margin-top:2.6rem",
      actionButton("ask_master", "請解籤師開口", class = "btn-rite"),
      actionButton("close_rite", "不必了，收卦", class = "btn-ghost")
    )
  )
}

# 沉吟時的旁白。整副打亂後依序播，一輪之內不重複——
# 解籤要等四十秒上下，若只抽五句輪播，同一句會在一次等待裡轉三遍。
PONDERING_LINES <- c(
  "籤師接過你的卦。",
  "他把六爻由下往上排開，看了很久。",
  "香燒到一半。",
  "他抬眼看了你一下，又低下頭去。",
  "他嘆了口氣，像是想起了什麼人。",
  "他用指節敲了兩下桌面。",
  "他把上卦和下卦分開看，又合起來看。",
  "廟外有機車騎過去。",
  "他問了一句什麼，但沒有等你回答。",
  "他伸手把香灰撥平。",
  "「這卦我上個月才見過一次。」他說。",
  "他沒說話，只是把茶杯挪開了一點。",
  "他盯著動的那一爻，手指停在那裡。",
  "他翻了翻抽屜，沒找到什麼，又關上。",
  "外頭天色暗了一階。",
  "他笑了一下，那笑不是給你的。",
  "他把老花眼鏡推上去，又拉下來。",
  "他重新數了一遍爻位，從初爻數起。",
  "他把籤紙壓在鎮紙下面。",
  "他倒了茶，沒有給你。",
  "供桌上的燭火歪了一下。",
  "他看了一眼門口，好像在等誰。",
  "「你這個卦啊。」他停在這裡。",
  "他把袖子往上捲了一折。",
  "遠處有人在燒金紙。",
  "他用手指在桌上畫了三橫，又抹掉。",
  "他搖了搖頭，不是否定，是在想清楚什麼。",
  "「不急。」他說，然後就沒有下文了。",
  "他把香插正。",
  "牆上的日曆還翻在上個月。",
  "他咳了一聲，喝了口茶。",
  "他把卦紙轉了個方向，換一邊看。",
  "有隻貓從供桌底下走過去。",
  "他望向窗外，那裡沒有什麼可看的。",
  "他數著念珠，數到一半停了。",
  "「這個位置。」他點了點紙上某一處。",
  "他把眼鏡摘下來擦了擦。",
  "電風扇轉到底，又慢慢轉回來。",
  "他沉默的時間比你以為的長。",
  "他重新讀了一次你寫的字。",
  "他把兩隻手交握，擱在桌上。",
  "外面的雨聲小了一點。"
)

view_pondering <- function() {
  # 整副打亂全部送出去，由 ritual.js 一句一句換；
  # 四十句以上足以撐過任何一次等待而不重複。
  htmltools::div(
    class = "stage pondering",
    htmltools::div(class = "smoke",
                   htmltools::span(), htmltools::span(), htmltools::span()),
    htmltools::div(
      class = "pondering__lines",
      lapply(sample(PONDERING_LINES), htmltools::span)
    )
  )
}

view_read <- function(vals) {
  dv <- vals$dv
  htmltools::div(
    class = "stage",
    asked_block(vals),
    htmltools::div(
      style = "text-align:center;font-size:.78rem;letter-spacing:.26em;color:#6B6155",
      paste0(dv$ben$full,
             if (!is.null(dv$zhi)) paste0("　之　", dv$zhi$full) else "　六爻不變")
    ),
    if (!is.null(vals$err)) htmltools::div(class = "notice", vals$err),
    render_reading(vals$reading, stamp = vals$stamp),
    htmltools::div(
      style = "margin-top:3rem",
      actionButton("close_rite", "收卦・再問一事", class = "btn-rite")
    ),
    quiet(htmltools::div(
      style = "margin-top:2rem;text-align:center",
      "同一件事不必再問。真要再問，也只剩一次。"
    ))
  )
}

view_refused <- function(vals) {
  htmltools::div(
    class = "stage",
    ember(),
    htmltools::div(class = "asked",
                   htmltools::div(class = "asked__label", "所問"),
                   htmltools::div(class = "asked__text", vals$question)),
    htmltools::div(
      class = "omen",
      htmltools::strong("初筮告，再三瀆，瀆則不告。"), htmltools::br(),
      "《易・蒙》卦辭。這件事你已經問過兩回了。",
      "卦沒有變，是你不肯信。第三次，籤師不會開口。",
      htmltools::br(), htmltools::br(),
      "把事情放一放，或者換一個你真正想問的問題。"
    ),
    htmltools::div(
      style = "margin-top:2.4rem",
      actionButton("close_rite", "換一件事", class = "btn-rite")
    )
  )
}

# --- 共用小塊 --------------------------------------------------------------

asked_block <- function(vals) {
  htmltools::div(
    class = "asked",
    htmltools::div(class = "asked__label", "所問"),
    htmltools::div(class = "asked__text", vals$question),
    htmltools::div(class = "quiet", style = "margin-top:.9rem",
                   paste0("起卦於　", vals$stamp %||% cast_stamp()))
  )
}

re_ask_omen <- function() {
  htmltools::div(
    class = "omen",
    htmltools::strong("再筮。"),
    "同一件事你問第二回了。《蒙》曰「初筮告，再三瀆」——",
    "卦會答，但答的多半還是同一句話。這一次，聽進去。"
  )
}

shinyApp(ui, server)
