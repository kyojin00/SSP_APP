importScripts('https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyAX8LhejArzq_XRMs4g8Hv8yc_9PuhTyvA", // 본인의 API Key
  authDomain: "sspapp-71608.firebaseapp.com",
  projectId: "sspapp-71608",
  storageBucket: "sspapp-71608.appspot.com",
  messagingSenderId: "135546039401",
  appId: "1:135546039401:web:cd9e453d12df60a6c746f8"
});

const messaging = firebase.messaging();

// ✅ 백그라운드 메시지 핸들러 수정
messaging.onBackgroundMessage((payload) => {
  console.log('[sw.js] 백그라운드 메시지 수신:', payload);

  // 👈 핵심: payload에 'notification' 객체가 이미 있다면 
  // 브라우저가 자동으로 알림을 띄우므로 여기서 showNotification을 호출하지 않습니다.
  if (payload.notification) {
    return; 
  }

  // 만약 notification 없이 data만 온 경우에만 수동으로 띄웁니다.
  const notificationTitle = payload.data?.title || "새 공지사항";
  const notificationOptions = {
    body: payload.data?.body || "",
    icon: '/icons/Icon-192.png'
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});