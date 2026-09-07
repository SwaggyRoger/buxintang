# 檔名: api.R
library(plumber)
library(httr2)
library(glue)

# 設定 API Key (建議設在 .Renviron 檔案裡: GEMINI_API_KEY="你的KEY")
# 這裡為了方便示範直接讀取，實際上請保護好你的 Key
api_key <- "<<REDACTED-請至 Google AI Studio 撤銷此金鑰>>"

#* @apiTitle 羅傑的易經 AI 解讀服務
#* @apiDescription 個人興趣專案：用 R 串接 Google Gemini

#* 解讀卦象
#* @param lines:string 卦象陣列 (請輸入逗號分隔，例如 "9,8,8,9,8,8")
#* @param question:string 使用者的問題
#* @post /divine
function(lines, question = "") {
  
  # 1. 處理輸入數據
  # 如果 lines 是字串 (JSON 傳輸時可能發生)，轉回數值
  if (is.character(lines)) lines <- as.numeric(unlist(strsplit(lines, ",")))
  
  lines_text <- paste(lines, collapse = ", ")
  
  # 2. 準備 Google Gemini 的 Payload
  url <- paste0(
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=",
    api_key
  )
  
  system_prompt <- "你是一位精通易經的智者。請根據使用者提供的六爻數字（6=老陰, 7=少陽, 8=少陰, 9=老陽，由初爻至上爻），判斷本卦、變卦，並結合使用者的問題給予指引。請用溫暖、玄妙但易懂的中文回答，字數控制在 200 字以內。"
  
  user_msg <- glue("卦象數據：[{lines_text}]。問題：{question}")
  
  # 3. 發送請求 (使用 httr2)
  req <- request(url) %>%
    req_method("POST") %>%
    req_headers("Content-Type" = "application/json") %>%
    req_body_json(list(
      contents = list(
        list(
          parts = list(
            list(text = paste(system_prompt, "\n\n", user_msg))
          )
        )
      )
    ))
  
  # 4. 處理回應
  tryCatch({
    resp <- req_perform(req)
    result_json <- resp_body_json(resp)
    
    # Gemini 的回傳結構比較深，需要這樣挖出來
    ai_text <- result_json$candidates[[1]]$content$parts[[1]]$text
    
    return(list(
      status = "success",
      answer = ai_text
    ))
    
  }, error = function(e) {
    return(list(status = "error", message = e$message))
  })
}