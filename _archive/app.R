library(shiny)
library(tidyverse)
library(bslib)
#library(httr2) # 如果真的要串接 API 用，這裡先保留

# --- 模擬 AI 解讀函數 (這裡用假資料代替，您可以換成上一段的 API Call) ---
mock_ai_interpretation <- function(lines, question) {
  Sys.sleep(1.5) # 模擬 AI 思考時間
  return(paste0(
    "【AI 大師解讀】\n",
    "您卜出的卦象數字序列為：", paste(lines, collapse=","), "\n",
    "針對您的問題：「", question, "」\n\n",
    "卦象顯示目前的局勢如同初春的種子（範例），",
    "雖然表面平靜，但地底下充滿生機。",
    "建議您耐心等待，不要急於求成，就像農夫等待收穫一樣。"
  ))
}

# --- UI ---
ui <- page_fluid(
  theme = bs_theme(version = 5, bootswatch = "lux"),
  
  div(class = "container-fluid text-center", style = "max-width: 600px; margin-top: 30px;",
      
      h2("🔮 靈龜卜卦"),
      p(class = "text-muted", "誠心默念問題，親手擲出每一爻"),
      
      # 輸入問題區
      textInput("user_question", "請輸入您心中的疑惑：", placeholder = "例如：下個月的轉職運勢如何？"),
      
      hr(),
      
      # 視覺化區域
      div(style = "height: 400px; background-color: #f8f9fa; border-radius: 10px; padding: 20px;",
          plotOutput("hex_plot", height = "100%")
      ),
      
      br(),
      
      # 控制按鈕區 (動態顯示)
      uiOutput("action_controls"),
      
      br(),
      
      # 結果顯示區
      verbatimTextOutput("ai_result")
  )
)

# --- Server ---
server <- function(input, output, session) {
  
  # 1. 狀態管理：儲存目前的卦象進度
  vals <- reactiveValues(
    lines = numeric(0),       # 儲存擲出的數字 (6,7,8,9)
    current_step = 0,         # 目前擲到第幾爻 (0-6)
    status_msg = "請輸入問題後開始",
    is_analyzing = FALSE,
    final_result = NULL
  )
  
  # 2. 動態渲染按鈕介面
  output$action_controls <- renderUI({
    
    # 如果還沒輸入問題，禁止開始
    if (input$user_question == "") {
      return(div(class="alert alert-warning", "請先在上方輸入您的問題"))
    }
    
    # 如果正在擲卦 (0-5次)
    if (vals$current_step < 6) {
      btn_text <- paste("擲出第", vals$current_step + 1, "爻")
      return(
        actionButton("toss_btn", btn_text, 
                     class = "btn-primary btn-lg w-100", 
                     icon = icon("hand-holding-circle")) # 加上圖示增加儀式感
      )
    } 
    
    # 如果擲滿 6 次，但還沒看結果
    if (vals$current_step == 6 && is.null(vals$final_result)) {
      return(
        tagList(
          h4("卦象已成！", class="text-success"),
          actionButton("analyze_btn", "請 AI 大師解卦", class = "btn-success btn-lg w-100 mb-2"),
          actionButton("reset_btn", "重新起卦", class = "btn-outline-secondary w-100")
        )
      )
    }
    
    # 如果已經有結果
    if (!is.null(vals$final_result)) {
      return(
        actionButton("reset_btn", "再卜一卦", class = "btn-outline-dark w-100")
      )
    }
  })
  
  # 3. 擲爻邏輯 (按鈕事件)
  observeEvent(input$toss_btn, {
    req(vals$current_step < 6)
    
    # 模擬擲 3 枚硬幣
    # 正面(3), 反面(2)
    coins <- sample(c(2, 3), 3, replace = TRUE)
    toss_sum <- sum(coins) # 結果範圍 6,7,8,9
    
    # 更新狀態
    vals$lines <- c(vals$lines, toss_sum) # Append 到向量末端
    vals$current_step <- vals$current_step + 1
  })
  
  # 4. 解卦邏輯 (呼叫 AI)
  observeEvent(input$analyze_btn, {
    req(vals$current_step == 6)
    
    # 顯示讀取狀態
    id <- showNotification("正在連結天機...", type = "message", duration = NULL)
    on.exit(removeNotification(id), add = TRUE)
    
    # 呼叫 AI 函數 (或是 API)
    result <- mock_ai_interpretation(vals$lines, input$user_question)
    vals$final_result <- result
  })
  
  # 5. 重置邏輯
  observeEvent(input$reset_btn, {
    vals$lines <- numeric(0)
    vals$current_step <- 0
    vals$final_result <- NULL
    updateTextInput(session, "user_question", value = "") # 清空問題
  })
  
  # 6. 繪圖邏輯 (視覺化核心)
  output$hex_plot <- renderPlot({
    
    # 建立基礎底圖
    p <- ggplot() +
      scale_y_continuous(limits = c(0.5, 6.5), breaks = 1:6, name = "爻位 (由下而上)") +
      scale_x_continuous(limits = c(0, 10)) +
      theme_void() +
      theme(plot.background = element_rect(fill = "#f8f9fa", color = NA))
    
    # 如果還沒開始，顯示提示文字
    if (length(vals$lines) == 0) {
      p <- p + annotate("text", x=5, y=3.5, label="等待起卦...", size=6, color="gray")
      return(p)
    }
    
    # 建立數據框
    df <- tibble(
      y = 1:length(vals$lines), # 第幾次擲出，就對應 y 軸第幾層
      val = vals$lines
    ) %>%
      mutate(
        type = case_when(
          val %in% c(7, 9) ~ "Yang", # 陽
          val %in% c(6, 8) ~ "Yin"   # 陰
        ),
        is_moving = val %in% c(6, 9), # 變爻
        color = ifelse(is_moving, "#d35400", "#2c3e50") # 變爻用橘紅色標示
      )
    
    # 繪製每一爻
    for (i in 1:nrow(df)) {
      row <- df[i, ]
      y_pos <- row$y
      bar_color <- row$color
      
      if (row$type == "Yang") {
        # 陽爻：長實線
        p <- p + annotate("rect", xmin=2, xmax=8, ymin=y_pos-0.2, ymax=y_pos+0.2, fill=bar_color)
        if (row$is_moving) p <- p + annotate("point", x=5, y=y_pos, size=4, color="white") # 老陽標記
        
      } else {
        # 陰爻：斷開線
        p <- p + annotate("rect", xmin=2, xmax=4.5, ymin=y_pos-0.2, ymax=y_pos+0.2, fill=bar_color) +
          annotate("rect", xmin=5.5, xmax=8, ymin=y_pos-0.2, ymax=y_pos+0.2, fill=bar_color)
        if (row$is_moving) p <- p + annotate("text", x=5, y=y_pos, label="X", color=bar_color, fontface="bold", size=6) # 老陰標記
      }
    }
    
    return(p)
  })
  
  # 7. 顯示文字結果
  output$ai_result <- renderText({
    vals$final_result
  })
}

shinyApp(ui, server)