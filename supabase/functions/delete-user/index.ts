// supabase/functions/delete-user/index.ts
// 배포: npx supabase functions deploy delete-user

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { userId } = await req.json();
    if (!userId) {
      return new Response(JSON.stringify({ error: "userId가 필요합니다." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Service Role 클라이언트 (모든 권한)
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    // 요청자 JWT로 일반 클라이언트 생성 → 호출자 확인
    const authHeader = req.headers.get("Authorization") ?? "";
    const supabaseUser = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user: caller }, error: userError } = await supabaseUser.auth.getUser();
    if (userError || !caller) {
      return new Response(JSON.stringify({ error: "인증 실패: " + (userError?.message ?? "") }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 호출자 ADMIN 권한 확인
    const { data: profile } = await supabaseAdmin
      .from("profiles")
      .select("role")
      .eq("id", caller.id)
      .single();

    if (profile?.role !== "ADMIN") {
      return new Response(JSON.stringify({ error: "관리자 권한이 없습니다." }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 본인 삭제 방지
    if (caller.id === userId) {
      return new Response(JSON.stringify({ error: "본인 계정은 삭제할 수 없습니다." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // profiles 삭제 → Auth 삭제
    await supabaseAdmin.from("profiles").delete().eq("id", userId);
    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(userId);
    if (deleteError) throw deleteError;

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (e) {
    return new Response(JSON.stringify({ error: e.message ?? "알 수 없는 오류" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});