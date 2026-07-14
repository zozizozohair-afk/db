# دليل إعداد الإشعارات المجانية 100% 🆓

## نظرة عامة

هذا النظام مجاني بالكامل ولا يتطلب Firebase Functions المدفوعة. يعتمد على:
- **Firebase Cloud Messaging (FCM)** - مجاني تماماً
- **Topic-based messaging** - مجاني تماماً
- **Client-side notification sending** - مجاني تماماً
- **Firestore** - مجاني ضمن الحدود السخية

## المتطلبات الأساسية

### 1. إعداد Firebase Cloud Messaging (FCM)

#### في وحدة تحكم Firebase:
1. انتقل إلى مشروعك في [Firebase Console](https://console.firebase.google.com/)
2. اذهب إلى **Project Settings** > **Cloud Messaging**
3. في قسم **Web configuration**:
   - انقر على **Generate key pair** لإنشاء VAPID key
   - انسخ الـ VAPID key (موجود بالفعل في الكود)
4. في قسم **Server key**:
   - انسخ **Server key** (مطلوب للإرسال)

#### تحديث Server Key في الكود:
```dart
// في ملف lib/services/free_notification_service.dart
// استبدل 'YOUR_SERVER_KEY_HERE' بالـ Server key الخاص بك
static const String _serverKey = 'YOUR_SERVER_KEY_HERE';
```

### 2. إعداد قواعد Firestore (مجانية)

أضف هذه القواعد في Firestore Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // قواعد مجموعة user_tokens
    match /user_tokens/{tokenId} {
      allow read, write: if request.auth != null;
    }
    
    // قواعد مجموعة notification_history
    match /notification_history/{notificationId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

### 3. إعداد الفهارس في Firestore (مجانية)

أنشئ الفهارس التالية في Firestore:

#### فهرس user_tokens:
- Collection: `user_tokens`
- Fields: `active` (Ascending), `timestamp` (Descending)

#### فهرس notification_history:
- Collection: `notification_history`
- Fields: `timestamp` (Descending)

## كيفية الاستخدام

### 1. إرسال إشعار لجميع المستخدمين:

```dart
import '../services/free_notification_service.dart';

// إرسال لجميع المستخدمين
await FreeNotificationService.sendNotificationToAll(
  title: 'عنوان الإشعار',
  body: 'محتوى الإشعار',
  data: {'page': 'home'}, // اختياري
);
```

### 2. إرسال إشعار لمستخدم محدد:

```dart
// الحصول على رمز المستخدم المميز
String? userToken = await FreeNotificationService.getCurrentToken();

// إرسال للمستخدم
await FreeNotificationService.sendNotificationToUser(
  userToken: userToken!,
  title: 'عنوان الإشعار',
  body: 'محتوى الإشعار',
);
```

### 3. استخدام المواضيع (Topics):

```dart
// الاشتراك في موضوع
await FreeNotificationService.subscribeToTopic('vip_users');

// إلغاء الاشتراك
await FreeNotificationService.unsubscribeFromTopic('vip_users');
```

### 4. استخدام صفحة إدارة الإشعارات:

```dart
import '../pages/free_notifications_admin.dart';

// إضافة إلى التنقل
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const FreeNotificationsAdminPage(),
  ),
);
```

## الملفات المُنشأة والمُحدثة

### ملفات جديدة:
- `lib/services/free_notification_service.dart` - خدمة الإشعارات المجانية
- `lib/pages/free_notifications_admin.dart` - صفحة إدارة الإشعارات المجانية
- `FREE_NOTIFICATION_SETUP.md` - هذا الدليل

### ملفات محدثة:
- `lib/main.dart` - تحديث لاستخدام النظام المجاني
- `pubspec.yaml` - إضافة مكتبة http
- `web/firebase-messaging-sw.js` - Service Worker (موجود مسبقاً)
- `web/manifest.json` - إعدادات الويب (موجود مسبقاً)
- `web/index.html` - Firebase SDK (موجود مسبقاً)

## خطوات التشغيل

### 1. تحديث Server Key:
```dart
// في lib/services/free_notification_service.dart
static const String _serverKey = 'AAAAxxxxxxx:APA91bH...'; // ضع مفتاحك هنا
```

### 2. تثبيت التبعيات:
```bash
flutter pub get
```

### 3. تشغيل التطبيق:
```bash
flutter run
```

## المميزات

✅ **مجاني 100%** - لا توجد تكاليف إضافية
✅ **بدون Firebase Functions** - لا حاجة لنشر Functions
✅ **إرسال فوري** - إرسال مباشر من التطبيق
✅ **دعم المواضيع** - تجميع المستخدمين حسب الاهتمامات
✅ **تاريخ الإشعارات** - حفظ جميع الإشعارات المرسلة
✅ **واجهة إدارية** - صفحة سهلة لإدارة الإشعارات
✅ **دعم الويب والموبايل** - يعمل على جميع المنصات

## الحدود المجانية

### Firebase Cloud Messaging:
- **غير محدود** - إرسال إشعارات مجاني تماماً
- **جميع المنصات** - Android, iOS, Web
- **جميع الميزات** - Topics, Direct messaging, Data messages

### Firestore:
- **50,000 قراءة/يوم** - كافية لآلاف المستخدمين
- **20,000 كتابة/يوم** - كافية لآلاف الإشعارات
- **1 جيجابايت تخزين** - كافي لملايين الإشعارات
- **10 جيجابايت نقل/شهر** - كافي للاستخدام العادي

## اختبار النظام

### 1. اختبار الإرسال لجميع المستخدمين:
1. افتح صفحة إدارة الإشعارات
2. اختر "جميع المستخدمين"
3. أدخل العنوان والمحتوى
4. اضغط "إرسال الإشعار"

### 2. اختبار الإرسال لمستخدم محدد:
1. انسخ رمز مميز من قائمة "الرموز المميزة النشطة"
2. اختر "مستخدم محدد"
3. الصق الرمز المميز
4. أدخل العنوان والمحتوى
5. اضغط "إرسال الإشعار"

### 3. اختبار المواضيع:
1. اشترك في موضوع: `await FreeNotificationService.subscribeToTopic('test');`
2. اختر "موضوع محدد" في صفحة الإدارة
3. أدخل "test" كاسم الموضوع
4. أرسل الإشعار

## استكشاف الأخطاء

### مشاكل شائعة:

1. **Server Key غير صحيح:**
   - تأكد من نسخ Server Key من Firebase Console
   - تحقق من عدم وجود مسافات إضافية

2. **الإشعارات لا تصل:**
   - تأكد من منح الإذن للإشعارات
   - تحقق من أن الرمز المميز صحيح
   - راجع Console للأخطاء

3. **خطأ في الإرسال:**
   - تحقق من اتصال الإنترنت
   - تأكد من صحة Server Key
   - راجع استجابة FCM في Console

4. **قواعد Firestore:**
   - تأكد من إعداد القواعد بشكل صحيح
   - تحقق من مصادقة المستخدم

## الأمان

- احتفظ بـ Server Key آمناً
- لا تشارك مفاتيح Firebase
- استخدم قواعد Firestore المناسبة
- راجع أذونات المستخدمين بانتظام

## مقارنة مع النظام المدفوع

| الميزة | النظام المجاني | النظام مع Functions |
|--------|----------------|--------------------|
| التكلفة | مجاني 100% | مجاني ضمن حدود |
| سهولة الإعداد | سهل جداً | متوسط |
| الأداء | ممتاز | ممتاز |
| المرونة | عالية | عالية جداً |
| الصيانة | قليلة | متوسطة |
| الميزات المتقدمة | أساسية | متقدمة |

## الدعم

للمساعدة الإضافية:
- [Firebase Documentation](https://firebase.google.com/docs/cloud-messaging)
- [Flutter Firebase Messaging](https://firebase.flutter.dev/docs/messaging/overview/)
- [FCM HTTP API](https://firebase.google.com/docs/cloud-messaging/http-server-ref)

---

**ملاحظة:** هذا النظام مجاني بالكامل ومناسب لمعظم التطبيقات. إذا كنت تحتاج ميزات متقدمة أكثر، يمكنك الترقية للنظام مع Firebase Functions لاحقاً.