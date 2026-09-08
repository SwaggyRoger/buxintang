# 卜心堂

> 六爻金錢卦・解籤問心

一個 R Shiny 的卜卦 App。使用者親手擲滿六次銅錢成卦，
由 Claude 扮演的「解籤師」依實際卦象斷卦。

---

## 這是什麼

- **起卦法**：三枚銅錢，擲六次，由初爻至上爻（金錢卦／文王卦本法）。
  字為陽計 3、背為陰計 2，合數 6/7/8/9 對應老陰／少陽／少陰／老陽，
  機率 1/8、3/8、3/8、1/8。
- **斷卦**：算出本卦、之卦（動爻變後）、互卦，並依**朱熹《易學啟蒙》變占法**
  決定該用哪段經文（六爻不變用卦辭、一爻變用該變爻爻辭、……、
  六爻皆變乾用「用九」坤用「用六」）。
- **解籤**：把卦名、卦辭、動爻爻題、之卦、互卦、斷卦法整理成一張「卦單」，
  交給 Claude Opus 5 解讀。模型不需要自己從數字推卦，推卦是 R 這邊算好的。
  籤解固定四段、六百到九百字：

  | 段 | 內容 |
  |---|---|
  | 【籤解】 | 把上下卦的畫面描出來，動爻動在哪、代表事情的哪個階段 |
  | 【打個比方】 | 舉一個貼著提問者處境的具體情境，把卦理落到地上 |
  | 【所以呢】 | 具體到可以照做的建議，並給出可觀察的訊號 |
  | 【啟】 | 一句帶得走的話 |

  模型設定在 `R/03_interpreter.R` 最上面：`CLAUDE_EFFORT` 預設 `"medium"`
  （一次解籤約 35–55 秒）。改成 `"high"` 會多花三成時間，實測句式與字數
  差異不大；`"low"` 會更快但明顯變淺。

  提示詞裡另有一段「壞習慣」清單，明文禁止幾個會讓多次求籤看起來像同一篇的
  公式：用「你大概⋯」開場舉例、用「上卦X是⋯下卦Y是⋯」開場斷卦、
  每次都用對仗句收尾。切入卦象的角度要每卦不同（卦名字義／動爻位置／
  卦辭某字／先下判斷再回頭說卦）。
- **卜不過三**：《易・蒙》「初筮告，再三瀆，瀆則不告」。
  同一件事第二次起卦會出現提醒，第三次籤師不開口。

---

## 跑起來

```bash
Rscript -e "shiny::runApp('.', port = 7788, launch.browser = TRUE)"
```

需要的套件只有三個：`shiny`、`bslib`、`httr2`。

### 設定 Claude 金鑰

複製 `.Renviron.example` 為 `.Renviron`，填入金鑰，重啟 R session：

```
ANTHROPIC_API_KEY=sk-ant-...
```

沒設金鑰 App 一樣能跑，只是解籤師「不在堂上」，會給一份依卦辭生成的
**離線籤解**（卦象仍然是真的，只是沒有人味）。

> 金鑰只存在 `.Renviron`，已被 `.gitignore` 擋住，不會進 git。
> 要換金鑰改這個檔就好，程式碼裡沒有任何硬寫的金鑰。
> （部署時它會隨包上 shinyapps.io，原因見下面的部署段。）

---

## 部署到 shinyapps.io

```bash
Rscript deploy.R
```

**金鑰怎麼上去**：shinyapps.io **不支援** `rsconnect` 的 `envVars`
（那是 Posit Connect 的功能，在 shinyapps.io 會直接報錯
`shinyapps.io does not support setting envVars`）。
這裡的做法是把 `.Renviron` 一起打包，伺服器端 R 啟動時會自動讀取。

> 代價要知道：金鑰因此存在部署包裡。它不對外公開（bundle 不提供下載，
> 對外只跑 Shiny app），但任何能登入這個 shinyapps.io 帳號的人都拿得到。
> 個人專案可以接受；要更嚴謹得換 Posit Connect。
>
> `.Renviron` 仍然**不會進 git**（`.gitignore` 擋著），只進部署包。

> 這個版本沒有第二個服務行程。舊版需要另外開一個 plumber API（`localhost:8000`），
> 那在 shinyapps.io 上是跑不起來的——那邊只跑 Shiny 這一個 process。
> 現在 API 呼叫直接寫在 Shiny server 裡。

第一次要先跑一次 `rsconnect::setAccountInfo(...)`（`deploy.R` 裡有註解說明）。

---

## 檔案

```
app.R                    進入點：狀態機 + 各階段版面
R/01_hexagrams.R         八卦、六十四卦（卦名／卦辭／大意）、查表、爻題
R/02_casting.R           擲錢、動爻、之卦、互卦、朱熹變占法、時辰、卜不過三
R/03_interpreter.R       解籤師人格、卦單、Claude Messages API、離線籤解
R/04_ui.R                主題、爻與卦牌的 HTML、籤解排版
www/styles.css           全部視覺
deploy.R                 打包上 shinyapps.io
tests/                   卦學邏輯與 API payload 的驗證腳本
_archive/                改版前的舊檔
```

`R/` 目錄由 Shiny 自動載入（Shiny >= 1.5），不需要手動 `source()`。

「沉吟中」那頁的旁白從 `app.R` 的 `PONDERING_LINES`（18 句）隨機抽 5 句、
隨機排序。寫死幾句的話，多求幾次就會發現籤師每次都在講一樣的話。

### 測試

```bash
Rscript tests/test-divination.R
Rscript tests/test-claude-payload.R
```

第一支跑六十四卦查表、8×8 上下卦反查、已知卦象、動爻與之卦、
朱熹變占法 0–6 動爻、爻題、互卦、擲錢機率分布、時辰、卜不過三、
以及每個階段的 UI 渲染。第二支只檢查送給 Claude 的請求結構，
**不會真的發出請求，不花錢**。

---

## 設計筆記

視覺定調「夜廟燭火」：暗、暖、安靜。金是香火，硃砂只給動爻和印，
宣紙全場只出現一次——就是籤解那張。功能性的東西盡量退到後面，
讓節奏、留白和等待本身變成內容。

字體 Noto Serif TC（Google Fonts CDN）。動畫全部尊重
`prefers-reduced-motion`；而且入場動畫一律是「裝飾」而非「必要」——
元素的預設樣式就是可見的，動畫時間軸沒在跑（分頁在背景被節流）
也不會讓卦象消失。

---

## 免責

解籤師是 Claude 扮演的，聊備一格，不是專業建議。
卦以決疑，不以代決。
