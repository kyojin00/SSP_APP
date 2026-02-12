import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ---------------------------------------------------------
// 1. CORS 설정 (Web 브라우저 호출 및 외부 연동 필수)
// ---------------------------------------------------------
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-webhook-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// ---------------------------------------------------------
// 2. JWT 유틸리티 (Google OAuth2 인증용 - FCM v1 API 전용)
// ---------------------------------------------------------
function base64UrlEncodeBytes(bytes: Uint8Array) {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function base64UrlEncodeStr(str: string) {
  return base64UrlEncodeBytes(new TextEncoder().encode(str));
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const cleaned = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");

  const der = Uint8Array.from(atob(cleaned), (c) => c.charCodeAt(0));

  return await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

async function getGoogleAccessToken(sa: any): Promise<string> {
  const iat = Math.floor(Date.now() / 1000);
  const exp = iat + 3600;
  const scope = "https://www.googleapis.com/auth/firebase.messaging";

  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: sa.client_email,
    scope,
    aud: "https://oauth2.googleapis.com/token",
    exp,
    iat,
  };

  const unsigned = `${base64UrlEncodeStr(JSON.stringify(header))}.${base64UrlEncodeStr(JSON.stringify(payload))}`;
  const key = await importPrivateKey(sa.private_key);
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );

  const jwt = `${unsigned}.${base64UrlEncodeBytes(new Uint8Array(sig))}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const data = await res.json();
  if (!res.ok) throw new Error(`OAuth token error: ${res.status} ${JSON.stringify(data)}`);
  return data.access_token;
}

// ---------------------------------------------------------
// 3. FCM 발송 함수 (v1 API 전용)
// ---------------------------------------------------------
async function fcmSend(
  accessToken: string, 
  projectId: string, 
  target: { token?: string; topic?: string }, 
  title: string, 
  body: string, 
  data: Record<string, string>
) {
  const message: any = {
    notification: { title, body },
    data,
    android: { priority: "high" },
    apns: { payload: { aps: { sound: "default" } } },
  };

  if (target.token) message.token = target.token;
  else if (target.topic) message.topic = target.topic;

  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${accessToken}`,
    },
    body: JSON.stringify({ message }),
  });

  const json = await res.json().catch(() => ({}));
  return { status: res.status, json };
}

// ---------------------------------------------------------
// 4. 메인 핸들러
// ---------------------------------------------------------
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const NOTICE_WEBHOOK_SECRET = Deno.env.get("NOTICE_WEBHOOK_SECRET")!;
    const SA_JSON_STR = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON")!;

    const incomingSecret = req.headers.get("x-webhook-secret");
    let body: any;
    try {
      body = await req.json();
    } catch {
      body = {};
    }

    const finalSecret = incomingSecret || body.secret;
    if (finalSecret !== NOTICE_WEBHOOK_SECRET) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), { 
        status: 401, 
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
      });
    }

    const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const saJson = JSON.parse(SA_JSON_STR);
    const accessToken = await getGoogleAccessToken(saJson);
    const projectId = saJson.project_id;

    const targetCategory = body.target_category ?? body.record?.target_category ?? "ALL";
    const title = body.title ?? body.record?.title ?? "새 공지사항";
    const content = body.content ?? body.record?.content ?? "";
    const noticeId = body.notice_id ?? body.record?.id ?? null;
    const msgBody = content.length > 100 ? `${content.slice(0, 100)}...` : content;
    const mode = body.mode ?? "tokens";

    // ✅ 1. 토픽 모드
    if (mode === "topic") {
      const topic = body.topic ?? `notice_${String(targetCategory).toLowerCase()}`;
      const { status, json } = await fcmSend(accessToken, projectId, { topic }, `[공지] ${title}`, msgBody, { type: "NOTICE", notice_id: String(noticeId ?? "") });
      const ok = status >= 200 && status < 300;
      return new Response(JSON.stringify({ success: ok, mode: "topic", topic, response: json }), { 
        status: ok ? 200 : 500, 
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
      });
    }

    // ✅ 2. 토큰 모드 (관계를 타지 않는 2단계 조회)
    let tokens: string[] = [];
    if (targetCategory === "ALL") {
      const { data, error } = await sb.from("user_device_tokens").select("token");
      if (error) throw error;
      tokens = (data ?? []).map((x) => x.token);
    } else {
      // 1단계: profiles 테이블에서 해당 부서(dept_category)의 유저 ID 목록을 먼저 가져옴
      const { data: profileData, error: profileError } = await sb
        .from("profiles")
        .select("id")
        .eq("dept_category", targetCategory);
      
      if (profileError) throw profileError;

      const userIds = (profileData ?? []).map(p => p.id);

      // 2단계: 유저 ID 목록이 있다면 해당 유저들의 토큰을 가져옴
      if (userIds.length > 0) {
        const { data: tokenData, error: tokenError } = await sb
          .from("user_device_tokens")
          .select("token")
          .in("user_id", userIds);
        
        if (tokenError) throw tokenError;
        tokens = (tokenData ?? []).map(x => x.token);
      }
    }

    tokens = Array.from(new Set(tokens)).filter(Boolean);
    const results = [];
    const CONCURRENCY = 10;

    for (let i = 0; i < tokens.length; i += CONCURRENCY) {
      const chunk = tokens.slice(i, i + CONCURRENCY);
      const settled = await Promise.all(chunk.map(async (t) => {
        const { status, json } = await fcmSend(accessToken, projectId, { token: t }, `[공지] ${title}`, msgBody, { type: "NOTICE", notice_id: String(noticeId ?? "") });
        const ok = status >= 200 && status < 300;
        
        if (!ok && (json?.error?.status === "NOT_FOUND" || json?.error?.details?.some((d: any) => d.errorCode === "UNREGISTERED"))) {
          await sb.from("user_device_tokens").delete().eq("token", t);
        }
        return { ok, status };
      }));
      results.push(...settled);
    }

    const sentCount = results.filter(r => r.ok).length;

    return new Response(JSON.stringify({ 
      success: true, 
      total: tokens.length, 
      sent: sentCount, 
      failed: tokens.length - sentCount 
    }), { 
      status: 200, 
      headers: { ...corsHeaders, "Content-Type": "application/json" } 
    });

  } catch (e: any) {
    console.error("Critical Error:", e);
    return new Response(JSON.stringify({ error: e.message }), { 
      status: 500, 
      headers: { ...corsHeaders, "Content-Type": "application/json" } 
    });
  }
});