setwd("D:/claude-projects/fortune_teller")
suppressMessages({ library(shiny); library(bslib); library(httr2) })
for (f in list.files("R", full.names = TRUE)) source(f, encoding = "UTF-8")

Sys.setenv(ANTHROPIC_API_KEY = "sk-ant-DUMMY-FOR-SHAPE-CHECK")

dv    <- build_divination(c(9L, 8L, 7L, 6L, 8L, 7L))
brief <- format_hexagram_brief(dv, "要不要辭掉現在的工作？", cast_stamp(), 1L)

req <- .build_request(brief, with_fallback = TRUE)

cat("== URL ==\n"); print(req$url)
cat("\n== Method ==\n"); print(req$method)
cat("\n== Headers ==\n")
h <- req$headers
for (nm in names(h)) {
  v <- as.character(h[[nm]])
  if (nm == "x-api-key") v <- paste0(substr(v, 1, 10), "…(遮蔽)")
  cat(sprintf("  %-18s %s\n", nm, v))
}

cat("\n== Body (JSON) ==\n")
body <- req$body$data
j <- jsonlite::toJSON(body, auto_unbox = TRUE, pretty = TRUE)
# system prompt / user message 太長，只印骨架
shape <- body
shape$system <- paste0("<", nchar(body$system), " 字元的系統提示>")
shape$messages[[1]]$content <- paste0("<", nchar(body$messages[[1]]$content), " 字元的卦單>")
cat(jsonlite::toJSON(shape, auto_unbox = TRUE, pretty = TRUE), "\n")

cat("\n== 檢查 ==\n")
chk <- function(cond, msg) cat(if (isTRUE(cond)) "  ok   " else "  FAIL ", msg, "\n")
chk(identical(body$model, "claude-opus-5"),                "model = claude-opus-5")
chk(identical(body$thinking$type, "adaptive"),             "thinking = adaptive（Opus 5 不吃 budget_tokens）")
chk(is.null(body$thinking$budget_tokens),                  "未送已移除的 budget_tokens")
chk(!is.null(body$output_config$effort),                   "effort 放在 output_config 內")
chk(is.null(body$temperature) && is.null(body$top_p),      "未送 Opus 5 已移除的取樣參數")
chk(identical(body$messages[[1]]$role, "user"),            "只有一則 user 訊息，無 assistant prefill")
chk(identical(body$fallbacks, "default"),                  "fallbacks = default")
chk(identical(as.character(h[["anthropic-beta"]]), "server-side-fallback-2026-07-01"),
                                                           "備援 beta 標頭已帶")
chk(identical(as.character(h[["anthropic-version"]]), "2023-06-01"), "anthropic-version 正確")
chk(body$max_tokens >= 4000,                               "max_tokens 足夠容納 thinking + 回覆")

# 不帶備援時應該連 header 帶欄位都不出現
req2 <- .build_request(brief, with_fallback = FALSE)
chk(is.null(req2$body$data$fallbacks) && is.null(req2$headers[["anthropic-beta"]]),
    "關閉備援時 fallbacks 與 beta 標頭皆不送出（400 重試路徑）")

cat("\n== 回應解析（模擬 thinking block 在前） ==\n")
fake <- list(
  stop_reason = "end_turn",
  content = list(
    list(type = "thinking", thinking = ""),
    list(type = "text", text = "【籤解】\n第一段。"),
    list(type = "text", text = "【一句話】\n收。")
  ),
  usage = list(input_tokens = 100, output_tokens = 50)
)
txt <- .extract_text(fake)
chk(grepl("【籤解】", txt) && grepl("【一句話】", txt) && !grepl("^\\s*$", txt),
    "略過 thinking block，取出所有 text block")
cat("  取出：", gsub("\n", " / ", txt), "\n")
