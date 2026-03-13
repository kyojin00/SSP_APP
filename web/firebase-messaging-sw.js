importScripts('https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyAX8LhejArzq_XRMs4g8Hv8yc_9PuhTyvA",
  authDomain: "sspapp-71608.firebaseapp.com",
  projectId: "sspapp-71608",
  storageBucket: "sspapp-71608.firebasestorage.app",
  messagingSenderId: "135546039401",
  appId: "1:135546039401:web:cd9e453d12df60a6c746f8",
});

const messaging = firebase.messaging();

/** ✅ 1) “진짜 push가 도착했는지” 확인용 (가장 중요) */
self.addEventListener('push', (event) => {
  console.log('[SW] push event arrived ✅', event);

  // event.data가 없을 수도 있음(암호화 payload)
  // 그래도 도착만 확인하면 됨
});

/** ✅ 2) FCM 백그라운드 메시지 → 항상 알림 표시 */
messaging.onBackgroundMessage((payload) => {
  console.log('[SW] onBackgroundMessage payload ✅', payload);

  const title =
    payload?.notification?.title ||
    payload?.data?.title ||
    "알림";

  const body =
    payload?.notification?.body ||
    payload?.data?.body ||
    "";

  const url =
    payload?.fcmOptions?.link ||
    payload?.data?.url ||
    "https://sspapp-71608.web.app";

  return self.registration.showNotification(title, {
    body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: { url },
  });
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = event.notification?.data?.url || "https://sspapp-71608.web.app";
  event.waitUntil(clients.openWindow(url));
});