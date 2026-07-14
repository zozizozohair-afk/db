# كيفية الحصول على Server Key من Firebase 🔑

## خطوات الحصول على Server Key:

### 1. افتح Firebase Console
- اذهب إلى [Firebase Console](https://console.firebase.google.com/)
- اختر مشروعك

### 2. انتقل إلى إعدادات المشروع
- انقر على أيقونة الترس ⚙️ في الشريط الجانبي
- اختر **Project Settings**

### 3. اذهب إلى Cloud Messaging
- انقر على تبويب **Cloud Messaging**
- ستجد قسم **Project credentials**

### 4. انسخ Server Key
- ابحث عن **Server key**
- انقر على أيقونة النسخ 📋 بجانب المفتاح
- المفتاح يبدأ عادة بـ: `AAAAxxxxxxx:APA91bH...`

### 5. حدث الكود
افتح ملف `lib/services/free_notification_service.dart` وابحث عن السطر:

```dart
static const String _serverKey = 'YOUR_SERVER_KEY_HERE';
```

استبدل `YOUR_SERVER_KEY_HERE` بالمفتاح الذي نسخته:

```dart
static const String _serverKey = 'AAAAxxxxxxx:APA91bH...';
```

## مثال كامل:

```dart
// قبل التحديث
static const String _serverKey = 'YOUR_SERVER_KEY_HERE';

// بعد التحديث
static const String _serverKey = 'AAAABcDeFgHi:APA91bHxYzAbCdEfGhIjKlMnOpQrStUvWxYz1234567890';
```

## ملاحظات مهمة:

⚠️ **احتفظ بالمفتاح آمناً** - لا تشاركه مع أحد
⚠️ **لا تنشره على GitHub** - أضفه إلى `.gitignore` إذا لزم الأمر
⚠️ **تأكد من النسخ الكامل** - المفتاح طويل جداً
⚠️ **لا تضع مسافات إضافية** - انسخ المفتاح كما هو

## التحقق من صحة المفتاح:

بعد تحديث المفتاح، شغل التطبيق وجرب إرسال إشعار تجريبي. إذا نجح الإرسال، فالمفتاح صحيح.

## إذا لم تجد Server Key:

1. تأكد من تفعيل **Cloud Messaging API**:
   - اذهب إلى [Google Cloud Console](https://console.cloud.google.com/)
   - اختر مشروعك
   - ابحث عن "Firebase Cloud Messaging API"
   - فعّل الـ API

2. أو استخدم **Service Account Key** (طريقة أحدث):
   - في Firebase Console > Project Settings > Service accounts
   - انقر على "Generate new private key"
   - حمل ملف JSON
   - استخدم هذا الملف مع Firebase Admin SDK

---

**بعد تحديث Server Key، ستكون جاهزاً لإرسال الإشعارات مجاناً! 🎉**