# 啟動 API Server
library(plumber)
# 假設上面的程式碼存在 api.R
pr <- pr("D:/fortune_teller/FT_api.R")
pr_run(pr, port = 8000)