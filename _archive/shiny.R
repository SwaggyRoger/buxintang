library(shiny)
library(bslib)
library(httr2)
library(jsonlite)
library(ggplot2)

# --- 設定 Plumber API 地址 ---
API_URL <- "http://127.0.0.1:8000/divine"

ui <- page_fluid(
  # 1. 改用明亮主題 (例如 flatly, cosmo, yeti 都是白色系的)
  theme = bs_theme(version = 5, bootswatch = "flatly"),
  
  tags$head(
    tags$style(HTML("
      /* 2. 調整 CSS 適應白色背景 */
      .hex-container-box {
        background-color: #ffffff; /* 改成白底 */
        border: 2px solid #FFD700; /* 金色邊框保留，增加質感 */
        border-radius: 15px;
        padding: 20px;
        min-height: 400px;
        display: flex;
        align-items: center;
        justify-content: center;
        /* 改用柔和的深色陰影 */
        box-shadow: 0 5px 15px rgba(0, 0, 0, 0.1); 
      }
      
      .title-style { 
        color: #B8860B; /* 標題改用深金色 (Dark Goldenrod)，在白底較清晰 */
        font-weight: bold;
        margin-bottom: 20px;
        text-shadow: 1px 1px 2px rgba(0,0,0,0.1);
      }
    "))
  ),
  
  div(class = "container text-center py-5",
      # 標題套用新的樣式類別
      h1("太 乙 神 數 · AI", class = "title-style"),
      textInput("question", NULL, placeholder = "請輸入您的疑惑...", width = "100%"),
      br(),
      
      div(class = "row",
          div(class = "col-md-4 mb-3",
              div(class = "d-grid gap-3",
                  uiOutput("main_btn"),
                  actionButton("btn_reset", "重新開始", class = "btn btn-outline-secondary")
              )
          ),
          div(class = "col-md-8",
              div(class = "hex-container-box",
                  plotOutput("hex_plot", height = "350px") 
              )
          )
      ),
      uiOutput("ai_result")
  )
)

server <- function(input, output, session) {
  
  vals <- reactiveValues(lines = numeric(0), step = 0, result_text = NULL, loading = FALSE)
  
  # 1. 擲幣
  observeEvent(input$btn_toss, {
    req(vals$step < 6)
    toss <- sum(sample(c(2, 3), 3, replace = TRUE))
    vals$lines <- c(vals$lines, toss)
    vals$step <- vals$step + 1
  })
  
  # 2. 問 AI
  observeEvent(input$btn_ask, {
    req(input$question)
    vals$loading <- TRUE
    
    lines_str <- paste(vals$lines, collapse = ",")
    
    tryCatch({
      req <- request(API_URL) %>% req_method("POST") %>% req_url_query(lines = lines_str, question = input$question)
      resp <- req_perform(req)
      json_res <- resp_body_json(resp)
      vals$result_text <- as.character(unlist(json_res$answer))
    }, error = function(e) {
      vals$result_text <- paste("連線失敗：", e$message)
    })
    vals$loading <- FALSE
  })
  
  # 3. 重置
  observeEvent(input$btn_reset, {
    vals$lines <- numeric(0); vals$step <- 0; vals$result_text <- NULL
    updateTextInput(session, "question", value = "")
  })
  
  # 4. 按鈕
  output$main_btn <- renderUI({
    if(vals$loading) return(actionButton("d", "連線中...", disabled=T, class="btn btn-warning w-100"))
    if (vals$step < 6) {
      # 按鈕樣式微調，適應白底
      actionButton("btn_toss", paste0("⚡ 注入靈力 (第", vals$step + 1, "爻)"), class = "btn btn-warning w-100", style="font-weight:bold;")
    } else {
      actionButton("btn_ask", "🔮 請 AI 解卦", class = "btn btn-info w-100", style="font-weight:bold; color: white;")
    }
  })
  
  # 5. 核心：向量化 ggplot2 繪圖
  output$hex_plot <- renderPlot({
    
    # 背景透明
    par(bg = NA)
    
    if (length(vals$lines) == 0) {
      # ★★★ 關鍵修正：把 #666 改成 6碼的 #666666 ★★★
      return(ggplot() + theme_void() + annotate("text", x=0, y=0, label="等待靈力注入...", color="#666666", size=8))
    }
    
    # A. 準備資料
    df <- data.frame(
      y = 1:length(vals$lines),
      val = vals$lines
    )
    
    df$type <- ifelse(df$val %in% c(7, 9), "Yang", "Yin")
    df$is_moving <- df$val %in% c(6, 9)
    
    # 設定顏色 (變爻橘紅，靜爻金色)
    df$color <- ifelse(df$is_moving, "#FF4500", "#FFD700") 
    
    # B. 開始畫圖
    p <- ggplot() +
      scale_x_continuous(limits = c(0, 10)) +
      scale_y_continuous(limits = c(0.5, 6.5)) +
      theme_void() + 
      theme(
        plot.background = element_rect(fill = "transparent", color = NA),
        panel.background = element_rect(fill = "transparent", color = NA)
      )
    
    # C. 畫陽爻
    yang_df <- subset(df, type == "Yang")
    if(nrow(yang_df) > 0) {
      p <- p + geom_rect(data = yang_df, 
                         aes(xmin = 1, xmax = 9, ymin = y - 0.35, ymax = y + 0.35, fill = I(color)),
                         color = NA)
    }
    
    # D. 畫陰爻
    yin_df <- subset(df, type == "Yin")
    if(nrow(yin_df) > 0) {
      p <- p + geom_rect(data = yin_df, 
                         aes(xmin = 1, xmax = 4.2, ymin = y - 0.35, ymax = y + 0.35, fill = I(color)),
                         color = NA) +
        geom_rect(data = yin_df, 
                  aes(xmin = 5.8, xmax = 9, ymin = y - 0.35, ymax = y + 0.35, fill = I(color)),
                  color = NA)
    }
    
    # E. 畫變爻標記 (O/X)
    moving_df <- subset(df, is_moving)
    if(nrow(moving_df) > 0) {
      moving_df$label <- ifelse(moving_df$val == 9, "O", "X")
      p <- p + geom_text(data = moving_df, 
                         aes(x = 5, y = y, label = label), 
                         color = "white", size = 10, fontface = "bold")
    }
    
    p
    
  }, bg = "transparent")
  
  # 6. 結果顯示 (調整為白底樣式)
  output$ai_result <- renderUI({
    req(vals$result_text)
    # 背景改淺灰，文字改深色
    div(style = "background: #f8f9fa; border: 1px solid #FFD700; padding: 20px; border-radius: 10px; margin-top: 20px; text-align: left; color: #333;",
        h3("📜 大師解讀", style="color: #B8860B; border-bottom: 1px solid #ddd; padding-bottom: 10px;"),
        HTML(gsub("\n", "<br>", vals$result_text))
    )
  })
}

shinyApp(ui, server)