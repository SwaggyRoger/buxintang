# ===========================================================================
#  部署到 shinyapps.io
#
#  在本機執行本檔即可。金鑰以 envVars 送到伺服器端的環境變數，
#  「不會」被打包進 bundle，也不會出現在原始碼裡。
# ===========================================================================

library(rsconnect)

APP_NAME  <- "buxintang"   # 網址會是 https://<你的帳號>.shinyapps.io/buxintang/
APP_TITLE <- "卜心堂"

# --- 1. 帳號設定（第一次才需要） -------------------------------------------
# 到 https://www.shinyapps.io/admin/#/tokens 取得，貼上後執行一次即可：
#
# rsconnect::setAccountInfo(
#   name   = "<你的帳號>",
#   token  = "<TOKEN>",
#   secret = "<SECRET>"
# )

# --- 2. 檢查金鑰 -----------------------------------------------------------
# 建議放在本專案的 .Renviron（見 .Renviron.example），R 啟動時自動讀入。
if (!nzchar(Sys.getenv("ANTHROPIC_API_KEY"))) {
  stop("找不到 ANTHROPIC_API_KEY。\n",
       "請先在專案根目錄建立 .Renviron 寫入金鑰，重啟 R session 後再部署。\n",
       "（沒有金鑰也能部署，但解籤師不會開口，只剩離線籤解。）")
}

# --- 3. 只打包需要的檔案 ---------------------------------------------------
#
# 金鑰怎麼上去：shinyapps.io 不支援 rsconnect 的 envVars（那是 Posit Connect
# 的功能，在這裡會直接報錯）。shinyapps.io 的做法是把 .Renviron 一起打包，
# 伺服器端 R 啟動時會自動讀取它。
#
# 代價要知道：金鑰因此存在部署包裡。它不會被公開存取（bundle 不對外提供
# 下載，對外只跑 Shiny app），但任何能登入這個 shinyapps.io 帳號的人都拿得到。
# 個人專案可以接受；要更嚴謹就得換到 Posit Connect。
app_files <- c(
  "app.R",
  ".Renviron",
  list.files("R",   full.names = TRUE, pattern = "[.]R$"),
  list.files("www", full.names = TRUE)
)
stopifnot("找不到 .Renviron，金鑰無法隨包上去" = file.exists(".Renviron"))
cat("將打包以下檔案：\n"); cat(paste0("  ", app_files, collapse = "\n"), "\n\n")

# --- 4. 部署 ---------------------------------------------------------------
rsconnect::deployApp(
  appDir      = ".",
  appName     = APP_NAME,
  appTitle    = APP_TITLE,
  appFiles    = app_files,
  forceUpdate = TRUE,
  launch.browser = FALSE
)

cat("\n完成。網址：https://", rsconnect::accountInfo()$name,
    ".shinyapps.io/", APP_NAME, "/\n", sep = "")
