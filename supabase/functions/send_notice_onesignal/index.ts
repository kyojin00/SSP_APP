import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-webhook-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const APP_URL = "https://sspapp-71608.web.app";

function chunk<T>(arr: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < arr.length; i += size) {
    out.push(arr.slice(i, i + size));
  }
  return out;
}

async function oneSignalSend(
  restApiKey: string,
  appId: string,
  payload: Record<string, unknown>,
) {
  const res = await fetch("https://onesignal.com/api/v1/notifications", {
    method: "POST",
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Authorization": `Basic ${restApiKey.trim()}`,
    },
    body: JSON.stringify({
      app_id: appId,
      ...payload,
    }),
  });

  const json = await res.json().catch(() => ({}));

  if (!res.ok) {
    console.error("[OneSignal] ❌ send failed | status:", res.status, "| body:", JSON.stringify(json));
  } else {
    console.log("[OneSignal] ✅ send ok | status:", res.status, "| body:", JSON.stringify(json));
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
    const ONESIGNAL_APP_ID = Deno.env.get("ONESIGNAL_APP_ID")!;
    const ONESIGNAL_REST_API_KEY = Deno.env.get("ONESIGNAL_REST_API_KEY")!;

    if (!ONESIGNAL_APP_ID || !ONESIGNAL_REST_API_KEY) {
      throw new Error("Missing OneSignal environment variables");
    }

    const incomingSecret = req.headers.get("x-webhook-secret");
    let body: any = {};
    try { body = await req.json(); } catch {}

    const finalSecret = incomingSecret || body.secret;
    if (finalSecret !== NOTICE_WEBHOOK_SECRET) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    const targetCategory = body.target_category ?? body.record?.target_category ?? "ALL";
    const title   = body.title   ?? body.record?.title   ?? "새 공지사항";
    const content = body.content ?? body.record?.content ?? "";
    const noticeId = body.notice_id ?? body.record?.id ?? null;
    const msgBody = content.length > 160 ? `${content.slice(0, 160)}...` : content;
    const mode = body.mode ?? (targetCategory === "ALL" ? "all" : "dept");

    const commonPayload = {
      target_channel: "push",
      headings: { en: `[공지] ${title}` },
      contents: { en: msgBody },
      url: APP_URL,
      data: { type: "NOTICE", notice_id: String(noticeId ?? "") },
    };

    // ── single
    if (mode === "single") {
      const userId = String(body.user_id ?? "").trim();
      if (!userId) {
        return new Response(JSON.stringify({ error: "user_id required" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      const { status, json } = await oneSignalSend(ONESIGNAL_REST_API_KEY, ONESIGNAL_APP_ID, {
        ...commonPayload,
        include_external_user_ids: [userId],
        channel_for_external_user_ids: "push",
      });
      return new Response(JSON.stringify({ success: status < 300, status, json }), {
        status: status < 300 ? 200 : 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    console.log(`[OneSignal] mode=${mode} | targetCategory=${targetCategory}`);

    // ── all: include_external_user_ids로 중복 방지
    // included_segments: ["All"] 은 구독 단위로 전송되어 기기당 중복 발생 가능
    // include_external_user_ids 는 user 단위로 묶어서 1번만 전송
    if (mode === "all") {
      const { data: allProfiles, error: profilesError } = await sb
        .from("profiles")
        .select("id");

      if (profilesError) throw profilesError;

      const allUserIds = (allProfiles ?? []).map((p: any) => String(p.id));
      console.log(`[OneSignal] all mode | userIds=${allUserIds.length}`);

      if (allUserIds.length === 0) {
        return new Response(JSON.stringify({ success: true, total: 0 }), {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const batches = chunk(allUserIds, 1000);
      let anyFail = false;

      for (const b of batches) {
        const { status, json } = await oneSignalSend(ONESIGNAL_REST_API_KEY, ONESIGNAL_APP_ID, {
          ...commonPayload,
          include_external_user_ids: b,
          channel_for_external_user_ids: "push",
        });
        console.log(`[OneSignal] all batch | status=${status} | body=${JSON.stringify(json)}`);
        if (!(status >= 200 && status < 300)) anyFail = true;
      }

      return new Response(JSON.stringify({ success: !anyFail }), {
        status: anyFail ? 500 : 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ── dept: onesignal_subscriptions 테이블에서 player_id 직접 조회
    const { data: profileData, error: profileError } = await sb
      .from("profiles")
      .select("id")
      .eq("dept_category", targetCategory);

    if (profileError) throw profileError;

    const userIds = (profileData ?? []).map((p: any) => String(p.id));
    console.log(`[OneSignal] dept=${targetCategory} | userIds=${userIds.length}`);

    if (userIds.length === 0) {
      return new Response(JSON.stringify({ success: true, total: 0 }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // dept 모드도 include_external_user_ids 로 통일 (중복 방지)
    const batches = chunk(userIds, 1000);
    let anyFail = false;

    for (const b of batches) {
      const { status, json } = await oneSignalSend(ONESIGNAL_REST_API_KEY, ONESIGNAL_APP_ID, {
        ...commonPayload,
        include_external_user_ids: b,
        channel_for_external_user_ids: "push",
      });
      console.log(`[OneSignal] dept batch | status=${status} | body=${JSON.stringify(json)}`);
      if (!(status >= 200 && status < 300)) anyFail = true;
    }

    return new Response(JSON.stringify({ success: !anyFail }), {
      status: anyFail ? 500 : 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (e: any) {
    console.error("Critical Error:", e);
    return new Response(JSON.stringify({ error: e.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});