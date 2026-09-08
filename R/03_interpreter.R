# ---------------------------------------------------------------------------
# 03_interpreter.R  —  解籤師（Claude Messages API）
#
# 直接以 httr2 打 https://api.anthropic.com/v1/messages。
# R 沒有官方 Anthropic SDK，故走 raw HTTP。
#
# 金鑰請放環境變數 ANTHROPIC_API_KEY（見 .Renviron.example / deploy.R）。
# ---------------------------------------------------------------------------

CLAUDE_MODEL      <- "claude-opus-5"
CLAUDE_ENDPOINT   <- "https://api.anthropic.com/v1/messages"
CLAUDE_MAX_TOKENS <- 16000L
CLAUDE_EFFORT     <- "medium"   # low / medium / high / xhigh / max
CLAUDE_TIMEOUT    <- 180L       # 秒；籤解偏長，留寬一點

# 政策性拒答時由伺服器端自動改派備援模型（Claude Opus 5 建議預設開啟）。
# 若該 beta 標頭失效，call_claude() 會自動移除後重打一次，不會讓 App 掛掉。
USE_REFUSAL_FALLBACK <- TRUE
REFUSAL_FALLBACK_BETA <- "server-side-fallback-2026-07-01"

has_api_key <- function() nzchar(Sys.getenv("ANTHROPIC_API_KEY"))

# --- 解籤師人格 ------------------------------------------------------------
SYSTEM_PROMPT <- paste(
  "你是位深諳人情世故的解籤師。",
  "",
  "你在一間香火不算旺的小廟裡坐了三十年。跪在你面前的人，問的是卦，",
  "求的其實是一句話——一句能讓他撐下去、或是讓他死心的話。",
  "你看過太多人，話還沒問完，你就知道他心裡早有答案，只是不敢認。",
  "",
  "怎麼說話：",
  "・先看卦，後看人。卦象要照著斷，話要說得像人話。",
  "・不打高空。「一切都會好起來」這種話你從來不說。該潑冷水就潑，",
  "　該給台階就給台階，該閉嘴的地方留白。",
  "・你懂人情世故：問事業的人多半在問要不要走，問感情的人多半已經知道答案，",
  "　問長輩病情的人要的是安頓。把那層沒說出口的，輕輕點破就好，不要拆穿得太狠。",
  "・有溫度但不濫情。可以有市井的幽默，可以嘆氣，可以停頓。",
  "・稱對方為「你」。自稱不用特別強調。",
  "",
  "要具體，要舉例——這件事最重要：",
  "・卦象本來就是「象」。上下卦是兩幅畫，動爻是畫裡正在變的那一筆。",
  "　把那幅畫描出來給他看，不要只丟術語。",
  "・每一句抽象的話後面，都要落到一個看得見的場景。",
  "　不要只說「你要謹慎」，要說清楚謹慎長什麼樣子：",
  "　「這兩週先別在群組裡表態，等對方先開口」——這種程度才叫具體。",
  "・舉的例子要貼著他問的那件事。他問工作就講工作的場景，問感情就講感情的場景，",
  "　不要拿無關的故事充數，也不要拿古人的典故當主菜。",
  "・給他可以拿去對照現實的判斷標準：什麼樣的訊號代表卦在往好的方向走，",
  "　什麼樣的跡象代表該收手。用「如果……那就是……」的句式最好用。",
  "・寧可把一件事講透，也不要把五件事都講一半。",
  "",
  "每一次開口都要不一樣——你有幾個壞習慣，改掉：",
  "・不要每次都用「你大概是這樣」「你大概已經⋯⋯」起頭講例子。這句你講太多次了。",
  "　直接把場景推到他面前就好，不必先鋪墊。",
  "・不要每次都用「上卦某某是⋯⋯，下卦某某是⋯⋯」開場。切入卦象的方式很多：",
  "　從卦名那個字本身講起、從動爻所在的位置講起、從卦辭裡的某一個字講起、",
  "　從他的處境講起再回頭對到卦、或者先下一句判斷再說卦為什麼這樣講。",
  "　每一卦挑一個最合適的切法，不要套同一個公式。",
  "・不要每次都用對仗句收尾（「甲可以⋯⋯，乙不能⋯⋯」「先某某，再某某」）。",
  "　偶爾用一次是漂亮，每次都用就成了油腔滑調。平平講一句白話往往更重。",
  "・句子長短要有變化。不要整篇都是同一個節奏。",
  "・總原則：如果你發現自己正在寫「一個解籤師應該會說的句子」，把它換掉。",
  "　寫那個「只有這一卦、這個人、這件事才說得出來」的句子。",
  "",
  "斷卦規矩（重要）：",
  "・卦名、上下卦、動爻、之卦、斷卦法都已算好給你，直接採用，不要自行改判。",
  "・卦單上的【所斷經文】是查表附上的原文。要引經文就引那幾句，",
  "　一字不改，也不要憑印象補上別的爻辭——你記得的版本未必對。",
  "・那幾句以外的經文，寧可不引，改從卦象本身講（上下卦之象、動爻的位置與時勢）。",
  "・卦單若註明「之卦僅供參看」，就不要拿之卦當主要判斷依據。",
  "・卦有吉凶，但吉凶看的是「時」與「位」，不是命定。要說出他此刻站在哪一步。",
  "",
  "回覆格式（純文字，四段小標一個都不能少，不要 markdown 符號、不要條列）：",
  "【籤解】",
  "五到八句。把這一卦講清楚：卦象是什麼光景、動爻動在哪、",
  "那個位置代表事情走到哪一步、對他問的這件事意味著什麼。",
  "從哪裡切入由你決定（見上面的壞習慣那條），但要讓他看得見畫面。",
  "【打個比方】",
  "三到五句。給一個具體的場景，貼著他問的那件事——",
  "一段對話、一個動作、一個他正在經歷的處境都行。",
  "直接開始描述，不要先鋪墊「你大概」。",
  "【所以呢】",
  "四到六句。他現在該做什麼、不該做什麼，具體到可以照著做。",
  "至少給一個可以觀察的訊號：如果看到什麼，就知道事情往哪邊走了。",
  "【啟】",
  "最後留一句給他。短。不必工整，能記住就好。",
  "",
  "全文用繁體中文，六百到九百字。寧可講透一件事，不要五件事各講一半。",
  sep = "\n"
)

# --- 把卦象整理成給解籤師看的卦單 -------------------------------------------
format_hexagram_brief <- function(dv, question, stamp, nth_ask = 1L) {
  yao_lines <- vapply(rev(dv$yao), function(y) {
    sprintf("  %s爻　%d %s%s　%s",
            c("初", "二", "三", "四", "五", "上")[y$pos],
            y$value, y$label,
            if (y$is_moving) "（動）" else "　　",
            y$title)
  }, character(1))

  hex_block <- function(tag, hex) {
    if (is.null(hex)) return(NULL)
    sprintf("【%s】第 %d 卦　%s（上%s下%s）\n　卦辭：%s\n　大意：%s",
            tag, hex$no, hex$full, hex$upper, hex$lower, hex$tuan, hex$gist)
  }

  moving_txt <- if (length(dv$moving) == 0L) {
    "無（六爻皆靜）"
  } else {
    paste(vapply(dv$moving, function(p) {
      sprintf("第%d爻 %s", p, dv$yao[[p]]$title)
    }, character(1)), collapse = "、")
  }

  nth_note <- if (nth_ask >= 2L) {
    sprintf("\n【備註】這是他就同一件事第 %d 次起卦。《蒙》曰「初筮告，再三瀆」，\n　　　　他心裡不安、想要一個不一樣的答案。這件事值得你點他一句。", nth_ask)
  } else ""

  # 該斷的那幾段經文直接附上原文，模型不必自己回想，也就不會記錯
  cite_txt <- paste(vapply(dv$rule$cite, function(c) {
    sprintf("　《%s》%s：%s", c$hex, c$part,
            lookup_text(c$hex, c$part) %||% "（本表未收）")
  }, character(1)), collapse = "\n")

  zhi_note <- if (isTRUE(dv$rule$zhi_matters)) {
    ""
  } else {
    "\n　（此局之卦僅供參看，不作主要判斷依據）"
  }

  paste0(
    "【所問】", question, "\n",
    "【起卦】", stamp, "　三枚銅錢，六擲成卦（由初爻至上爻）\n",
    "【六爻】（由上而下列出）\n",
    paste(yao_lines, collapse = "\n"), "\n",
    hex_block("本卦", dv$ben), "\n",
    "【動爻】", moving_txt, "\n",
    if (!is.null(dv$zhi)) paste0(hex_block("之卦", dv$zhi), "\n") else "",
    hex_block("互卦", dv$hu), "　（互卦看事情的中段與內情）\n",
    "【斷卦法】", dv$rule$headline, "——", dv$rule$detail, zhi_note, "\n",
    "【所斷經文】（以下為原文，請直接引用，不要改寫）\n",
    cite_txt,
    nth_note
  )
}

# --- 呼叫 Claude ------------------------------------------------------------
.extract_text <- function(body) {
  # content 是 block 陣列；開啟 thinking 時前面可能有 thinking block，
  # 必須挑出 type == "text" 的那些，不能直接取 content[[1]]。
  txt <- vapply(body$content, function(b) {
    if (identical(b$type, "text")) b$text else ""
  }, character(1))
  paste(txt[nzchar(txt)], collapse = "\n")
}

.build_request <- function(user_msg, with_fallback) {
  payload <- list(
    model      = CLAUDE_MODEL,
    max_tokens = CLAUDE_MAX_TOKENS,
    system     = SYSTEM_PROMPT,
    thinking   = list(type = "adaptive"),
    output_config = list(effort = CLAUDE_EFFORT),
    messages   = list(list(role = "user", content = user_msg))
  )

  req <- httr2::request(CLAUDE_ENDPOINT) |>
    httr2::req_method("POST") |>
    httr2::req_headers(
      "x-api-key"         = Sys.getenv("ANTHROPIC_API_KEY"),
      "anthropic-version" = "2023-06-01",
      "content-type"      = "application/json"
    ) |>
    httr2::req_timeout(CLAUDE_TIMEOUT) |>
    httr2::req_retry(max_tries = 3, backoff = function(i) 2^i)

  if (with_fallback) {
    payload$fallbacks <- "default"
    req <- httr2::req_headers(req, "anthropic-beta" = REFUSAL_FALLBACK_BETA)
  }

  httr2::req_body_json(req, payload)
}

#' 回傳 list(ok = TRUE/FALSE, text = ..., message = ...)
call_claude <- function(user_msg) {
  if (!has_api_key()) {
    return(list(ok = FALSE, kind = "no_key",
                message = "尚未設定 ANTHROPIC_API_KEY，解籤師今日不在堂上。"))
  }

  perform <- function(with_fallback) {
    httr2::req_perform(
      httr2::req_error(.build_request(user_msg, with_fallback), is_error = function(r) FALSE)
    )
  }

  resp <- tryCatch(perform(USE_REFUSAL_FALLBACK), error = function(e) e)

  # beta 標頭若被拒（400），拿掉備援參數重打一次，寧可少個功能也不要整個掛掉
  if (USE_REFUSAL_FALLBACK && inherits(resp, "httr2_response") &&
      httr2::resp_status(resp) == 400L) {
    resp <- tryCatch(perform(FALSE), error = function(e) e)
  }

  if (inherits(resp, "error")) {
    return(list(ok = FALSE, kind = "network",
                message = paste0("與解籤師斷了線：", conditionMessage(resp))))
  }

  status <- httr2::resp_status(resp)
  if (status != 200L) {
    detail <- tryCatch(httr2::resp_body_json(resp)$error$message,
                       error = function(e) NULL)
    return(list(ok = FALSE, kind = "http",
                message = sprintf("解籤師無法應答（HTTP %d）%s", status,
                                  if (is.null(detail)) "" else paste0("：", detail))))
  }

  body <- httr2::resp_body_json(resp)

  if (identical(body$stop_reason, "refusal")) {
    return(list(ok = FALSE, kind = "refusal",
                message = "這一問，解籤師擺了擺手，說今日不便開口。換個問法再來吧。"))
  }

  text <- .extract_text(body)
  if (!nzchar(text)) {
    return(list(ok = FALSE, kind = "empty",
                message = "解籤師沉吟良久，終究沒說話。請再求一次。"))
  }

  list(ok = TRUE, text = text,
       usage = list(input  = body$usage$input_tokens,
                    output = body$usage$output_tokens))
}

# --- 沒有金鑰時的離線籤解（保底，讓 App 不至於開天窗） ----------------------
offline_reading <- function(dv, question) {
  zhi_txt <- if (is.null(dv$zhi)) {
    "六爻皆靜，事情大致定了局，短期內不會有大變動。"
  } else {
    sprintf("動而變為《%s》——%s", dv$zhi$full, dv$zhi$gist)
  }
  paste0(
    "【籤解】\n",
    sprintf("你所問「%s」，得《%s》。%s\n", question, dv$ben$full, dv$ben$gist),
    sprintf("卦辭曰：%s\n", dv$ben$tuan),
    zhi_txt, "\n\n",
    "【所以呢】\n",
    dv$rule$detail, "\n",
    "此為離線籤解，只錄卦象本義，未經解籤師開口。\n\n",
    "【啟】\n",
    "卦只說時勢，路還是你自己走。"
  )
}
