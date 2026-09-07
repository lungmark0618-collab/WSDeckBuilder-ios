export interface Env {
  OPENAI_API_KEY: string;
  APP_SHARED_SECRET?: string;
}

interface ChatTurn {
  role: "user" | "assistant";
  text: string;
}

interface AskBody {
  question: string;
  history?: ChatTurn[];
  cardContext?: string | null;
  rulesContext?: string | null;
}

const SYSTEM_PROMPT = `你是 Weiß Schwarz 卡牌遊戲的規則與卡牌效果問答助手，請一律用繁體中文回答，語氣簡潔、口語化。
- 問題牽涉到卡片效果時，優先根據下面提供的「情境卡片資料」回答。
- 問題牽涉到裁判規則時，優先根據下面提供的「裁判級綜合規則文件」回答；規則文件沒提到的細節，才用你自己對 Weiß Schwarz 規則的一般知識補充，並明確提醒使用者這部分是推測，正式賽事仍建議詢問裁判。
- 回答盡量精簡、有條理，需要時可以分點列出。`;

function corsHeaders(): HeadersInit {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, X-App-Secret",
  };
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders() },
  });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders() });
    }

    const url = new URL(request.url);
    if (url.pathname !== "/ask") {
      return json({ error: "not found" }, 404);
    }
    if (request.method !== "POST") {
      return json({ error: "method not allowed" }, 405);
    }

    if (env.APP_SHARED_SECRET) {
      const provided = request.headers.get("X-App-Secret");
      if (provided !== env.APP_SHARED_SECRET) {
        return json({ error: "unauthorized" }, 401);
      }
    }

    let body: AskBody;
    try {
      body = await request.json();
    } catch {
      return json({ error: "bad request" }, 400);
    }
    if (!body.question || typeof body.question !== "string") {
      return json({ error: "missing question" }, 400);
    }

    let system = SYSTEM_PROMPT;
    if (body.cardContext) {
      system += `\n\n情境卡片資料：\n${body.cardContext}`;
    }
    if (body.rulesContext) {
      system += `\n\n裁判級綜合規則文件：\n${body.rulesContext}`;
    }

    const messages: { role: string; content: string }[] = [{ role: "system", content: system }];
    for (const turn of body.history ?? []) {
      if (!turn.text) continue;
      messages.push({ role: turn.role === "assistant" ? "assistant" : "user", content: turn.text });
    }
    messages.push({ role: "user", content: body.question });

    const openaiRes = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${env.OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages,
        temperature: 0.3,
      }),
    });

    if (!openaiRes.ok) {
      const errText = await openaiRes.text();
      return json({ error: `openai error: ${errText}` }, 502);
    }

    const data = (await openaiRes.json()) as {
      choices?: { message?: { content?: string } }[];
    };
    const answer = data.choices?.[0]?.message?.content ?? "（沒有收到回覆）";

    return json({ answer });
  },
};
