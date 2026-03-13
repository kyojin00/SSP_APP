import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-webhook-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const APP_LINK = "https://sspapp-71608.web.app"; // ✅ 너 도메인

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
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp,
    iat,
  };
  const unsigned =
    `${base64UrlEncodeStr(JSON.stringify(header))}.${base64UrlEncodeStr(JSON.stringify(payload))}`;

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
  if (!res.ok) {
    throw new Error(
      `OAuth token error: ${res.status} ${JSON.stringify(data)}`,
    );
  }
  return data.access_token;
}

function isBadTokenError(json: any) {
  const status = json?.error?.status;
  const details = json?.error?.details ?? [];

  // FCM v1에서 토큰이 죽었을 때 흔한 패턴들
  const hasUnregistered = details.some((d: any) =>
    d?.errorCode === "UNREGISTERED"
  );
  const hasInvalidArg = details.some((d: any) =>
    d?.errorCode === "INVALID_ARGUMENT"
  );

  // INVALID_ARGUMENT인데 fieldViolations에 message.token Invalid registration token이 찍히는 케이스
  const fieldViolations = details
    .filter((d: any) => d?.fieldViolations?.length)
    .flatMap((d: any) => d.fieldViolations);

  const tokenInvalidByField = fieldViolations.some((v: any) =>
    v?.field === "message.token" &&
    typeof v?.description === "string" &&
    v.description.toLowerCase().includes("invalid registration token")
  );

  return (
    status === "NOT_FOUND" ||
    status === "INVALID_ARGUMENT" ||
    hasUnregistered ||
    hasInvalidArg ||
    tokenInvalidByField
  );
}

async function fcmSend(
  accessToken: string,
  projectId: string,
  target: { token?: string; topic?: string },
  title: string,
  body: string,
  extraData: Record<string, string>,
) {
  const safeTitle = title ?? "알림";
  const safeBody = body ?? "";

  // ✅ 핵심: PWA(특히 모바일 홈추가)에서 안정적으로 뜨게 webpush.notification 포함
  // - data도 같이 넣어서 SW에서 data-only 처리도 가능하게 유지
  // - android/apns 블록은 네이티브 앱 대비로 유지
  const message: any = {
    data: {
      title: safeTitle,
      body: safeBody,
      ...extraData,
    },

    webpush: {
      headers: {
        Urgency: "high",
      },
      notification: {
        title: safeTitle,
        body: safeBody,
        icon: "/icons/Icon-192.png",
        badge: "/icons/Icon-192.png",
      },
      fcm_options: {
        // 알림 클릭 시 열 링크
        link: APP_LINK,
      },
    },

    android: {
      priority: "high",
      data: {
        title: safeTitle,
        body: safeBody,
        ...extraData,
      },
    },

    apns: {
      payload: {
        aps: {
          alert: { title: safeTitle, body: safeBody },
          sound: "default",
          "content-available": 1,
        },
      },
      headers: {
        "apns-priority": "10",
      },
    },
  };

  if (target.token) message.token = String(target.token).trim();
  else if (target.topic) message.topic = target.topic;

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${accessToken}`,
      },
      body: JSON.stringify({ message }),
    },
  );

  const json = await res.json().catch(() => ({}));

  if (res.ok) {
    console.log(
      `[FCM] ✅ 발송 성공 | token/topic: ${
        target.token ? `...${String(target.token).slice(-10)}` : target.topic
      }`,
    );
  } else {
    console.error(
      `[FCM] ❌ 발송 실패 | token/topic: ${
        target.token ? `...${String(target.token).slice(-10)}` : target.topic
      } | status: ${res.status} | error: ${JSON.stringify(json?.error)}`,
    );
  }

  return { status: res.status, json };
}

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
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    const saJson = JSON.parse(SA_JSON_STR);
    const accessToken = await getGoogleAccessToken(saJson);
    const projectId = saJson.project_id;

    const targetCategory =
      body.target_category ?? body.record?.target_category ?? "ALL";
    const title = body.title ?? body.record?.title ?? "새 공지사항";
    const content = body.content ?? body.record?.content ?? "";
    const noticeId = body.notice_id ?? body.record?.id ?? null;
    const msgBody = content.length > 100 ? `${content.slice(0, 100)}...` : content;

    const mode = body.mode ?? "tokens";

    // 공통 데이터(앱에서 눌렀을 때 처리용)
    const extraData: Record<string, string> = {
      type: "NOTICE",
      notice_id: String(noticeId ?? ""),
      url: APP_LINK,
    };

    // ✅ topic 모드
    if (mode === "topic") {
      const topic =
        body.topic ?? `notice_${String(targetCategory).toLowerCase()}`;
      const { status, json } = await fcmSend(
        accessToken,
        projectId,
        { topic },
        `[공지] ${title}`,
        msgBody,
        extraData,
      );
      const ok = status >= 200 && status < 300;
      return new Response(
        JSON.stringify({ success: ok, mode: "topic", topic, response: json }),
        {
          status: ok ? 200 : 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // ✅ tokens 모드
    let tokenRows: { token: string; platform: string | null; user_id?: string }[] = [];

    if (targetCategory === "ALL") {
      const { data, error } = await sb
        .from("user_device_tokens")
        .select("token, platform");
      if (error) throw error;
      tokenRows = data ?? [];
    } else {
      const { data: profileData, error: profileError } = await sb
        .from("profiles")
        .select("id")
        .eq("dept_category", targetCategory);
      if (profileError) throw profileError;

      const userIds = (profileData ?? []).map((p: any) => p.id);
      if (userIds.length > 0) {
        const { data: tokenData, error: tokenError } = await sb
          .from("user_device_tokens")
          .select("token, platform")
          .in("user_id", userIds);
        if (tokenError) throw tokenError;
        tokenRows = tokenData ?? [];
      }
    }

    console.log(
      `[FCM] 토큰 현황 | 전체: ${tokenRows.length} | web: ${
        tokenRows.filter((r) => r.platform === "web").length
      } | android: ${
        tokenRows.filter((r) => r.platform === "android").length
      } | ios: ${
        tokenRows.filter((r) => r.platform === "ios").length
      }`,
    );

    // ✅ 중복 제거 + 공백 제거
    const tokens = Array.from(
      new Set(
        tokenRows
          .map((r) => (r.token ? String(r.token).trim() : ""))
          .filter(Boolean),
      ),
    );

    const results: { ok: boolean; status: number }[] = [];
    const CONCURRENCY = 10;

    for (let i = 0; i < tokens.length; i += CONCURRENCY) {
      const chunk = tokens.slice(i, i + CONCURRENCY);

      const settled = await Promise.all(
        chunk.map(async (t) => {
          const { status, json } = await fcmSend(
            accessToken,
            projectId,
            { token: t },
            `[공지] ${title}`,
            msgBody,
            extraData,
          );

          const ok = status >= 200 && status < 300;

          // ✅ 만료/잘못된 토큰이면 DB에서 삭제
          if (!ok && isBadTokenError(json)) {
            console.log(`[FCM] 잘못된 토큰 삭제: ...${t.slice(-10)}`);
            await sb.from("user_device_tokens").delete().eq("token", t);
          }

          return { ok, status };
        }),
      );

      results.push(...settled);
    }

    const sentCount = results.filter((r) => r.ok).length;
    console.log(
      `[FCM] 최종 결과 | sent: ${sentCount} | failed: ${tokens.length - sentCount}`,
    );

    return new Response(
      JSON.stringify({
        success: true,
        total: tokens.length,
        sent: sentCount,
        failed: tokens.length - sentCount,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (e: any) {
    console.error("Critical Error:", e);
    return new Response(JSON.stringify({ error: e.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});