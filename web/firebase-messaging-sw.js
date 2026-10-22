/* eslint-disable no-undef */
// Service worker for Firebase Cloud Messaging in Kortexify

// Import Firebase scripts for Service Worker (compat version for web workers)
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

// Default Firebase configuration for Kortexify Web
const firebaseConfig = {
  apiKey: "AIzaSyBy0raUCON8Q64uS_ybbnjZAR47Ieb14es",
  authDomain: "kortex-study-app-2026.firebaseapp.com",
  projectId: "kortex-study-app-2026",
  storageBucket: "kortex-study-app-2026.firebasestorage.app",
  messagingSenderId: "1073532728398",
  appId: "1:1073532728398:web:8362216c490832a0897f1f"
};

// Check if query parameters were passed to the service worker to override/extend configuration
try {
  const urlParams = new URLSearchParams(location.search);
  const paramConfig = Object.fromEntries(urlParams.entries());
  if (paramConfig.apiKey && paramConfig.projectId) {
    Object.assign(firebaseConfig, paramConfig);
  }
} catch (e) {
  // Ignore query param parsing errors
}

// Initialize Firebase App
if (!firebase.apps.length) {
  firebase.initializeApp(firebaseConfig);
}

// Initialize Firebase Messaging
let messaging = null;
try {
  if (firebase.messaging.isSupported()) {
    messaging = firebase.messaging();
  }
} catch (err) {
  console.error('[firebase-messaging-sw.js] Firebase Messaging not supported or failed to initialize:', err);
}

// Background push notification handler
if (messaging) {
  messaging.onBackgroundMessage((payload) => {
    console.log('[firebase-messaging-sw.js] Received background message:', payload);

    const title = payload.notification?.title || payload.data?.title || 'Kortexify';
    const body = payload.notification?.body || payload.data?.body || 'You have a new update in Kortexify.';
    const icon = payload.notification?.icon || payload.data?.icon || '/icons/Icon-192.png';
    const clickAction = payload.fcmOptions?.link || payload.data?.click_action || payload.data?.url || '/workspace';

    const notificationOptions = {
      body: body,
      icon: icon,
      badge: '/icons/Icon-192.png',
      tag: payload.data?.tag || payload.data?.channel_id || 'kortex_notification',
      renotify: true,
      data: {
        click_action: clickAction,
        ...(payload.data || {})
      }
    };

    return self.registration.showNotification(title, notificationOptions);
  });
}

// Notification click event handler
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const targetUrl = event.notification.data?.click_action || '/workspace';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      // Focus existing open window/tab if found
      for (const client of windowClients) {
        if (client.url && 'focus' in client) {
          return client.focus();
        }
      }
      // Open new window if none open
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
    })
  );
});

// Lifecycle events
self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(clients.claim());
});
