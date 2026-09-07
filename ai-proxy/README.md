# WSDeckBuilder AI 代理伺服器

給 iOS／Android App 的「問 AI」功能用的輕量代理，跑在 Cloudflare Workers。

用的是 **Cloudflare Workers AI**（`@cf/qwen/qwen3.8-27b`，Qwen 系列，中文能力
不錯）內建模型，不用另外辦 OpenAI／Gemini 的外部 API Key，額度也內建在
Cloudflare 帳號裡，設定最簡單、最不容易壞。

（原本試過 OpenAI 跟 Gemini：OpenAI API 要先加值才能用；Gemini 目前新帳號
發的 `AQ.` 開頭金鑰在 Google 那邊有已知未修復的 bug，打 API 一律回
`ACCESS_TOKEN_TYPE_UNSUPPORTED`，改用內建的 Workers AI 才穩定跑起來。）

## 部署步驟

1. 安裝 wrangler（如果還沒裝過）：
   ```bash
   npm install -g wrangler
   ```

2. 登入 Cloudflare（沒有帳號的話先到 https://dash.cloudflare.com 免費註冊一個）：
   ```bash
   cd ai-proxy
   wrangler login
   ```

3. 部署：
   ```bash
   wrangler deploy
   ```
   第一次部署如果提示要註冊 `workers.dev` 子網域，照畫面指示選一個名稱即可。
   部署完會印出一個網址，長得像
   `https://wsdeck-ai-proxy.<你的帳號>.workers.dev`，這個就是要填進
   App 設定的「AI 服務網址」。

4. 設定共用密鑰（用指令設定，不會進 git、不會出現在程式碼裡）：
   ```bash
   wrangler secret put APP_SHARED_SECRET
   # 自己取一組夠長、隨機的字串，例如用 `openssl rand -hex 32` 產生
   ```

5. 打開 App → 設定 →「AI 服務設定」，把第 3 步的網址填進「服務網址」、
   第 4 步的 `APP_SHARED_SECRET` 填進「服務密鑰」。兩個平台（iOS／Android）
   要各填一次。

## 之後要改設定

- 換模型：改 `src/index.ts` 裡的 `MODEL` 常數（可選模型列在
  https://developers.cloudflare.com/workers-ai/models/ ），改完 `wrangler deploy`。
- 改 prompt／邏輯：改完 `src/index.ts` 後 `wrangler deploy` 就會更新。
- 監控用量：Cloudflare Dashboard → Workers & Pages → wsdeck-ai-proxy 可以看
  請求次數；AI 用量在 Dashboard → AI → Workers AI 那頁看（有每日免費額度，
  超過才會依用量計費，價格很低）。

## 注意事項

- `APP_SHARED_SECRET` 只能擋住「隨便亂打這個網址」的人，App 本身是公開原始碼
  （public repo），有心人还是能反組譯 App 拿到這組共用密碼去打你的 Worker、
  消耗你的 Workers AI 額度。如果之後用量異常，可以到 Cloudflare Dashboard 隨時
  換一組新的 `APP_SHARED_SECRET`（App 那邊也要跟著改設定）。
- 目前每次問答都會把整份 `WSRules.md`（規則文件）當背景資料一起送出，單次
  請求的 token 數會偏高；如果之後這是問題，可以考慮只挑跟問題相關的規則
  段落再送（RAG），這個之後有需要再做。
