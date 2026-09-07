# WSDeckBuilder AI 代理伺服器

給 iOS／Android App 的「問 AI」功能用的輕量代理，跑在 Cloudflare Workers。
作用：把 OpenAI 的 API Key 藏在這一層，App 本身不帶 Key，只帶一組共用密碼
（`X-App-Secret`），減少 Key 被反組譯 App 拿走的風險。

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

3. 到 https://platform.openai.com/api-keys 辦一組 API Key。

4. 部署：
   ```bash
   wrangler deploy
   ```
   部署完會印出一個網址，長得像
   `https://wsdeck-ai-proxy.<你的帳號>.workers.dev`，這個就是等一下要填進
   App 設定的「AI 服務網址」。

5. 設定兩組密鑰（用指令設定，不會進 git、不會出現在程式碼裡）：
   ```bash
   wrangler secret put OPENAI_API_KEY
   # 貼上剛剛辦的 OpenAI API Key，按 Enter

   wrangler secret put APP_SHARED_SECRET
   # 自己取一組夠長、隨機的字串，例如用 `openssl rand -hex 32` 產生
   ```

6. 打開 App → 設定 →「AI 服務設定」，把第 4 步的網址填進「服務網址」、
   第 5 步的 `APP_SHARED_SECRET` 填進「服務密鑰」。兩個平台（iOS／Android）
   要各填一次。

## 之後要改設定

- 換 Key：重新 `wrangler secret put OPENAI_API_KEY`，不用重新 deploy。
- 改程式邏輯（例如換模型、改 prompt）：改完 `src/index.ts` 後 `wrangler deploy` 就會更新。
- 監控用量：Cloudflare Dashboard → Workers → wsdeck-ai-proxy 可以看請求次數；
  OpenAI 那邊的費用要到 https://platform.openai.com/usage 看。

## 注意事項

- `APP_SHARED_SECRET` 只能擋住「隨便亂打這個網址」的人，App 本身是公開原始碼
  （public repo），有心人还是能反組譯 App 拿到這組共用密碼去打你的 Worker、
  消耗你的 OpenAI 額度。如果之後用量異常，可以到 Cloudflare Dashboard 隨時
  換一組新的 `APP_SHARED_SECRET`（App 那邊也要跟著改設定）。
- 目前每次問答都會把整份 `WSRules.md`（規則文件）當背景資料一起送給 OpenAI，
  單次請求的 token 數會偏高、費用也會偏高；如果之後費用是問題，可以考慮
  只挑跟問題相關的規則段落再送（RAG），這個之後有需要再做。
