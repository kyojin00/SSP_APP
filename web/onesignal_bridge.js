window.onesignalSubscribe = async function () {
  if (!window.OneSignalDeferred) return { ok:false, error:"OneSignal not loaded" };

  return await new Promise((resolve) => {
    OneSignalDeferred.push(async function(OneSignal) {
      try {
        await OneSignal.Notifications.requestPermission();
        const perm = await OneSignal.Notifications.permission;
        const subscribed = await OneSignal.User.PushSubscription.optedIn;
        const onesignalId = await OneSignal.User?.onesignalId;
        resolve({ ok:true, permission: perm, subscribed, onesignalId });
      } catch (e) {
        resolve({ ok:false, error: String(e) });
      }
    });
  });
};

window.onesignalSetExternalId = async function(externalId) {
  return await new Promise((resolve) => {
    OneSignalDeferred.push(async function(OneSignal) {
      try {
        await OneSignal.login(String(externalId));
        resolve({ ok:true });
      } catch (e) {
        resolve({ ok:false, error: String(e) });
      }
    });
  });
};

window.onesignalLinkAndGetId = async function(externalId) {
  return await new Promise((resolve) => {
    OneSignalDeferred.push(async function(OneSignal) {
      try {
        await OneSignal.login(String(externalId));
        await OneSignal.Notifications.requestPermission();
        const permission = OneSignal.Notifications.permission;
        const optedIn = OneSignal.User.PushSubscription.optedIn;
        const onesignalId = OneSignal.User.onesignalId;
        resolve({ ok: true, permission, optedIn, onesignalId });
      } catch (e) {
        resolve({ ok: false, error: String(e) });
      }
    });
  });
};

// ✅ 알림 클릭 핸들러 - notice_id를 Flutter로 전달
window._pendingNoticeId = null;

OneSignalDeferred.push(async function(OneSignal) {
  OneSignal.Notifications.addEventListener("click", function(event) {
    try {
      const data = event?.notification?.additionalData ?? event?.result?.notification?.additionalData ?? {};
      const noticeId = data?.notice_id ?? data?.notice_id ?? null;
      console.log("[OneSignal] notification clicked | noticeId:", noticeId, "| data:", JSON.stringify(data));

      if (noticeId) {
        // Flutter가 아직 준비 안 됐을 수 있으니 pending에 저장
        window._pendingNoticeId = String(noticeId);
        // Flutter dart callback 호출 시도
        if (typeof window._onNoticeClick === "function") {
          window._onNoticeClick(String(noticeId));
        }
      }
    } catch(e) {
      console.error("[OneSignal] click handler error:", e);
    }
  });
  console.log("[OneSignal] click listener registered");
});

// Flutter에서 등록할 콜백
window.onesignalSetClickHandler = function(callback) {
  window._onNoticeClick = callback;
  // 이미 클릭 pending된 게 있으면 즉시 전달
  if (window._pendingNoticeId) {
    callback(window._pendingNoticeId);
    window._pendingNoticeId = null;
  }
};

// Flutter에서 pending notice_id 가져가기
window.onesignalGetPendingNoticeId = function() {
  const id = window._pendingNoticeId;
  window._pendingNoticeId = null;
  return id;
};