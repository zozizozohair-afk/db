# نظام تحديث بيانات العملاء المحسن

## نظرة عامة
تم تحسين نظام تحديث بيانات العملاء ليشمل جميع الجداول والمجموعات في قاعدة البيانات، مع التأكد من تحديث جميع الحقول المرتبطة بالعميل.

## التحديثات الجديدة

### 1. تحسين تحديث المعاملات المالية
- **البحث باسم العميل**: البحث الأساسي يتم باسم العميل بدلاً من رقم الهوية
- **إضافة البحث في مجموعة `financialTransactions`** بالإضافة إلى `financial_transactions`
- **البحث الاحتياطي**: البحث برقم الهوية القديم كخيار احتياطي
- **تحديث حقول إضافية**: `customerPhone`, `clientPhone`
- **منع التحديث المكرر** للمستندات نفسها
- **تحديث شامل لجميع الحقول**: `customerId`, `customerName`, `idNumber`, `identityNumber`

### 2. تحسين فحص التوزيع
- **البحث في كلا المجموعتين**: `financial_transactions` و `financialTransactions`
- **تجنب العد المكرر** للمستندات نفسها
- **إحصائيات دقيقة** لتوزيع بيانات العميل

## الجداول المدعومة

| الجدول | الحقول المحدثة | طريقة البحث |
|--------|----------------|-------------|
| **العملاء** | `name`, `identityNumber`, `phoneNumber` | `identityNumber` |
| **العقود** | `clientData.*`, `clientName`, `identityNumber`, `clientIdentity` | `identityNumber`, `clientIdentity`, `clientData.identityNumber` |
| **الوحدات** | `clientName`, `clientIdentity`, `clientPhone`, `customerName`, `customerId` | `customerId`, `clientIdentity` |
| **المعاملات المالية** | `customerName`, `customerId`, `customerPhone`, `clientName`, `clientPhone`, `idNumber`, `identityNumber` | `customerId`, `idNumber`, `identityNumber` |
| **التكليفات** | `identityNumber` | `identityNumber` |
| **عقود إعادة البيع** | `identityNumber` | `identityNumber` |

## كيفية الاستخدام

### 1. تحديث بيانات العميل
```dart
await CustomerUpdateService.updateCustomerDataEverywhere(
  oldIdentityNumber: '1005799141',
  newCustomerData: {
    'name': 'فاطمة بنت مصطفى بن حسين مصطفى',
    'identityNumber': '1005799141',
    'phoneNumber': '0501234567',
  },
  context: context,
);
```

### 2. فحص توزيع البيانات
```dart
final distribution = await CustomerUpdateService.checkCustomerDataDistribution(
  '1005799141'
);

// النتيجة:
// {
//   'العملاء': 1,
//   'العقود': 2,
//   'الوحدات': 1,
//   'المعاملات المالية': 5,
//   'التكليفات': 0,
//   'عقود إعادة البيع': 0
// }
```

### 3. استخدام صفحة الاختبار
```dart
// الانتقال إلى صفحة الاختبار
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const TestCustomerDataSyncPage(),
  ),
);
```

## المشاكل المحلولة

### ✅ مشكلة عدم تحديث `customerId` في المعاملات المالية
- **السبب**: عدم البحث في مجموعة `financialTransactions`
- **الحل**: إضافة البحث في كلا المجموعتين مع تجنب التحديث المكرر

### ✅ مشكلة صعوبة تحديث رقم الهوية
- **السبب**: الاعتماد على رقم الهوية فقط في البحث
- **الحل**: تغيير آلية البحث في المعاملات المالية للبحث باسم العميل أولاً، مما يسمح بتحديث رقم الهوية حتى لو تغير

### ✅ مشكلة عدم تحديث أرقام الجوال
- **السبب**: عدم تحديث حقول `customerPhone` و `clientPhone`
- **الحل**: إضافة تحديث هذه الحقول في جميع الجداول

### ✅ مشكلة التحديث المكرر
- **السبب**: البحث بطرق متعددة قد يجد نفس المستند
- **الحل**: استخدام مجموعة `processedDocs` لتجنب التحديث المكرر

## ملاحظات مهمة

1. **الأمان**: يتم استخدام Batch Operations لضمان التحديث الآمن
2. **الأداء**: تجنب التحديث المكرر يحسن الأداء
3. **الشمولية**: النظام يغطي جميع الجداول والحقول المحتملة
4. **المرونة**: يمكن إضافة جداول جديدة بسهولة

## اختبار النظام

1. **افتح صفحة الاختبار**: `TestCustomerDataSyncPage`
2. **أدخل رقم الهوية**: مثل `1005799141`
3. **اضغط "فحص التوزيع"**: لرؤية توزيع البيانات الحالي
4. **أدخل البيانات الجديدة**: الاسم ورقم الجوال
5. **اضغط "تحديث البيانات"**: لتطبيق التحديثات
6. **تحقق من النتائج**: سيتم عرض عدد السجلات المحدثة

## الملفات المعدلة

- `customer_update_service.dart`: الخدمة الرئيسية للتحديث
- `test_customer_data_sync.dart`: صفحة الاختبار
- `README_customer_update_enhanced.md`: هذا الملف

---

**تاريخ التحديث**: $(date)
**الإصدار**: 2.0
**المطور**: نظام إدارة المساكن