import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DatabaseManagementPage extends StatefulWidget {
  const DatabaseManagementPage({super.key});

  @override
  _DatabaseManagementPageState createState() => _DatabaseManagementPageState();
}

class _DatabaseManagementPageState extends State<DatabaseManagementPage> {
  bool _isExporting = false;
  bool _isImporting = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // تعريف الجداول وأعمدتها
  final Map<String, List<String>> _collections = {
    'apartments': [
      'pn', // رقم الوحدة الكامل (المشروع-رقم الشقة)
      'number', // رقم الشقة
      'projectNumber', // رقم المشروع
      'status', // حالة الشقة (متاح، محجوز، تم البيع...)
      'direction', // اتجاه الشقة
      'description', // وصف الشقة
      'area', // مساحة الشقة
      'deedNumber', // رقم الصك
      'deedDate', // تاريخ الصك
      'city', // اللهة
      'district', // الحي
      'planNumber', // رقم المخطط
      'regionNumber', // رقم القطعة
      'floor', // رقم الطابق
      'clientName', // اسم العميل (إذا تم البيع)
      'clientIdentity', // رقم هوية العميل
      'totalAmount', // المبلغ الإجمالي
      'paidAmount', // المبلغ المدفوع
      'dateStringafragh', // تاريخ الإفراغ
      'contractNumbers1', // أرقام العقود المرتبطة
    ],
    'contracts': [
      'pn', // رقم العقد
      'contractNumber', // رقم العقد
      'projectNumber', // رقم المشروع
      'unitNumber', // رقم الوحدة
      'clientName', // اسم العميل
      'status', // حالة العقد
      'direction', // اتجاه الوحدة
      'totalAmount', // المبلغ الكلي
      'paidAmount', // المبلغ المدفوع
      'remainingAmount', // المبلغ المتبقي
      'deliveryMonths', // مدة التسليم بالأشهر
      'deliveryDays', // مدة استيفاء المبلغ بالأيام
      'dateGregorian', // التاريخ الميلادي
      'dateHijri', // التاريخ الهجري
      'clientData', // بيانات العميل
      'unitData', // بيانات الوحدة
      'settlementContractNumber', // رقم عقد التسوية
      'identityNumber', // رقم الهوية
    ],
    'customers': ['name', 'identityNumber', 'phoneNumber'],
    'financialTransactions': [
      'transactionId', // معرف العملية
      'date', // تاريخ العملية
      'customerName', // اسم العميل
      'amount', // المبلغ
      'cod', // رقم المرجع
      'debitCredit', // له/عليه
      'idNumber', // رقم الهوية
      'description', // الوصف
      'transactionType', // نوع العملية (نقدي/شيك/حوالة)
      'operationType', // نوع العملية (وحدة/مستقلة)
      'independentOperationType', // نوع العملية المستقلة (دفعة عادية/عربون)
      'isIndependent', // هل العملية مستقلة
      'isDeposit', // هل العملية عربون
      'pn', // رقم الوحدة
      'projectNumber', // رقم المشروع
      'unitNumber', // رقم الشقة
      'customerId', // رقم هوية العميل للربط
      'createdAt', // تاريخ الإنشاء
      'createdBy', // منشئ العملية
      'lastModified', // آخر تعديل
      'transactionHash', // قيمة التشفير للعملية
    ],
    'agencies': [
      'agentName',
      'agentId',
      'agencyNumber',
      'agencyDate',
      'principalName',
    ],
    'astlam': [
      'newContractNumber', // رقم العقد الجديد
      'originalContractNumber', // رقم العقد الأصلي
      'projectNumber', // رقم المشروع
      'apartmentNumber', // رقم الشقة
      'adad', // رقم عداد الكهرباء
      'maoakif', // رقم الموقف
      'date', // تاريخ المحضر
      'customerName', // اسم العميل
      'clientIdentityNumber', // رقم هوية العميل
      'clientPhoneNumber', // رقم جوال العميل
      'deedNumber', // رقم الصك
      'regionNumber', // رقم القطعة
      'numberf', // رقم الطابق
      'numbermo', // رقم المخطط
      'hy', // الحي
      'unitDirection', // اتجاه الوحدة
      'dateString', // تاريخ المحضر (نص)
    ],
    'financialSettlements': [
      'newContractNumber', // رقم العقد الجديد
      'originalContractNumber', // رقم العقد الأصلي
      'projectNumber', // رقم المشروع
      'apartmentNumber', // رقم الشقة
      'nameNow', // اسم العميل الجديد
      'newCustomerId', // هوية العميل الجديد
      'newPrice', // السعر الجديد
      'settlementDate', // تاريخ التسوية
      'createdAt', // تاريخ إنشاء التسوية
      'customerName', // اسم العميل السابق
      'clientIdentityNumber', // هوية العميل السابق
      'clientPhoneNumber', // رقم جوال العميل السابق
      'deedNumber', // رقم الصك
      'regionNumber', // رقم القطعة
      'unitDirection', // اتجاه الوحدة
      'contractDateHijri', // تاريخ العقد الهجري
    ],
    'resale_contracts': [
      'pn', // رقم العقد
      'contractNumber', // رقم العقد الأصلي
      'resaleContractNumber', // رقم عقد إعادة البيع
      'projectNumber', // رقم المشروع
      'unitNumber', // رقم الوحدة
      'clientName', // اسم العميل
      'status', // حالة العقد (معروض للبيع/تم البيع)
      'secondPartyAmount', // مبلغ الطرف الثاني
      'resaleFee', // رسوم إعادة البيع
      'marketingFee', // أتعاب التسويق
      'companyFee', // أتعاب الشركة
      'lawyerFee', // أتعاب المحامي
      'createdAt', // تاريخ الإنشاء
      'isResale', // هل هو عقد إعادة بيع
      'originalContractId', // معرف العقد الأصلي
      'identityNumber', // رقم هوية العميل
      'settlementContractNumber', // رقم عقد التسوية
      'clientData', // بيانات العميل
      'unitData', // بيانات الوحدة
      'resaleDate', // تاريخ إعادة البيع
      'updatedAt', // تاريخ آخر تحديث
    ],
  };

  Future<void> _exportDatabase() async {
    try {
      setState(() => _isExporting = true);

      // إنشاء ملف Excel جديد
      var excel = Excel.createExcel();
      excel.delete('Sheet1'); // حذف الورقة الافتراضية

      // تصدير كل جدول
      for (var collectionName in _collections.keys) {
        print('جاري تصدير جدول: $collectionName'); // للتشخيص

        var sheet = excel[collectionName];
        var snapshot = await _firestore.collection(collectionName).get();
        print('تم جلب ${snapshot.docs.length} سجل'); // للتشخيص

        int rowIndex = 0;

        // إضافة أسماء الأعمدة
        _collections[collectionName]?.asMap().forEach((colIndex, header) {
          sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: colIndex,
                  rowIndex: rowIndex,
                ),
              )
              .value = header;
        });
        rowIndex++;

        // إضافة البيانات
        for (var doc in snapshot.docs) {
          var data = doc.data();
          _collections[collectionName]?.asMap().forEach((colIndex, field) {
            dynamic value = data[field];
            String cellValue = '';

            try {
              if (value == null) {
                cellValue = '';
              } else if (value is Timestamp) {
                try {
                  // التحقق من صحة التاريخ قبل التحويل
                  DateTime dateTime = value.toDate();
                  if (dateTime.year >= 1900 && dateTime.year <= 2100) {
                    cellValue = DateFormat(
                      'yyyy-MM-dd HH:mm',
                    ).format(dateTime);
                  } else {
                    cellValue = 'تاريخ غير صحيح';
                  }
                } catch (e) {
                  cellValue = 'خطأ في التاريخ';
                }
              } else if (value is List) {
                cellValue = value.join(', ');
              } else if (value is Map) {
                cellValue = value.toString();
              } else if (value is num) {
                cellValue = value.toString();
              } else {
                cellValue = value.toString();
              }

              sheet
                  .cell(
                    CellIndex.indexByColumnRow(
                      columnIndex: colIndex,
                      rowIndex: rowIndex,
                    ),
                  )
                  .value = cellValue;
            } catch (e) {
              print('خطأ في معالجة القيمة $value: $e'); // للتشخيص
              sheet
                  .cell(
                    CellIndex.indexByColumnRow(
                      columnIndex: colIndex,
                      rowIndex: rowIndex,
                    ),
                  )
                  .value = 'ERROR: $e';
            }
          });
          rowIndex++;
        }
      }

      final now = DateTime.now();
      final fileName =
          'database_export_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.xlsx';

      final fileBytes = excel.save();
      if (fileBytes != null) {
        if (kIsWeb) {
          // حفظ الملف في المتصفح
          final blob = html.Blob([fileBytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor =
              html.document.createElement('a') as html.AnchorElement
                ..href = url
                ..style.display = 'none'
                ..download = fileName;
          html.document.body?.children.add(anchor);
          anchor.click();
          html.document.body?.children.remove(anchor);
          html.Url.revokeObjectUrl(url);
        } else {
          // حفظ الملف في الموبايل
          final dir = Directory('/storage/emulated/0/Download');
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          final filePath = '${dir.path}/$fileName';
          File(filePath)
            ..createSync(recursive: true)
            ..writeAsBytesSync(fileBytes);
        }

        // التحقق من أن الـ widget ما زال نشطاً قبل إظهار SnackBar
        if (mounted && context.mounted) {
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('تم تصدير قاعدة البيانات بنجاح: $fileName'),
                duration: Duration(seconds: 5),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            print('تم تصدير قاعدة البيانات بنجاح: $fileName');
          }
        }
      }
    } catch (e, stackTrace) {
      print('خطأ: $e\n$stackTrace');
      
      // التحقق من أن الـ widget ما زال نشطاً قبل إظهار SnackBar
      if (mounted && context.mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('حدث خطأ أثناء التصدير: $e'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        } catch (scaffoldError) {
          print('خطأ في إظهار رسالة الخطأ: $scaffoldError');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _importDatabase() async {
    try {
      setState(() => _isImporting = true);

      if (kIsWeb) {
        final input = html.FileUploadInputElement()..accept = '.xlsx';
        input.click();

        await input.onChange.first;
        if (input.files == null || input.files!.isEmpty) {
          setState(() => _isImporting = false);
          return; // إلغاء العملية إذا لم يتم اختيار ملف
        }

        final file = input.files!.first;
        // التحقق من امتداد الملف
        if (!file.name.toLowerCase().endsWith('.xlsx')) {
          throw 'يجب اختيار ملف Excel بامتداد .xlsx';
        }

        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);

        await reader.onLoad.first;
        final bytes = reader.result as List<int>;
        await _processExcelFile(bytes);
      }
    } catch (e, stackTrace) {
      print('خطأ في الاستيراد: $e\n$stackTrace');
      
      // التحقق من أن الـ widget ما زال نشطاً قبل إظهار SnackBar
      if (mounted && context.mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('حدث خطأ أثناء الاستيراد: $e'),
              backgroundColor: Colors.red,
            ),
          );
        } catch (scaffoldError) {
          // في حالة فشل إظهار SnackBar، اطبع الخطأ فقط
          print('خطأ في إظهار رسالة الخطأ: $scaffoldError');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _processExcelFile(List<int> bytes) async {
    Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      // إذا فشل تحليل Excel بسبب قيم التاريخ غير الصحيحة
      if (e.toString().contains('RangeError') && e.toString().contains('millisecondsSinceEpoch')) {
        // استخراج القيمة المشكلة من رسالة الخطأ
        String errorValue = '';
        final match = RegExp(r'(\d{13,})').firstMatch(e.toString());
        if (match != null) {
          errorValue = match.group(1) ?? '';
        }
        
        throw 'خطأ في ملف Excel: يحتوي الملف على أرقام كبيرة (مثل أرقام الهوية أو الجوال) تم تفسيرها كتواريخ غير صالحة.\n\nالقيمة المشكلة: $errorValue\n\nسبب المشكلة:\n• مكتبة قراءة Excel تحاول تلقائيًا تحويل الأرقام الكبيرة إلى تواريخ\n• أرقام الهوية والجوال الطويلة تسبب هذا الخطأ\n• حتى لو كانت البيانات تبدو صحيحة في Excel\n\nالحلول المجربة:\n\n1. **تنسيق الخلايا كنص:**\n   • حدد جميع خلايا أرقام الهوية والجوال\n   • انقر بزر الماوس الأيمن → Format Cells\n   • اختر "Text" من قائمة Category\n   • اضغط OK واحفظ الملف\n\n2. **إعادة إنشاء الملف:**\n   • احفظ الملف كـ CSV (Comma delimited)\n   • أغلق Excel وأعد فتح ملف CSV\n   • احفظه مرة أخرى كملف Excel (.xlsx)\n\n3. **للعملاء خاصة:**\n   • تأكد أن أرقام الهوية والجوال مكتوبة كنص فقط\n   • تجنب استخدام أي تنسيق رقمي أو تاريخي\n   • استخدم علامة اقتباس (\') قبل الرقم إذا لزم الأمر\n\nملاحظة: هذا الخطأ شائع مع ملفات Excel التي تحتوي على 100+ صف من البيانات.';
      }
      throw 'خطأ في قراءة ملف Excel: $e';
    }

    // التحقق من وجود الجداول المطلوبة
    for (var sheet in excel.tables.keys) {
      if (!_collections.containsKey(sheet)) {
        throw 'الجدول $sheet غير موجود في قاعدة البيانات';
      }
    }

    for (var sheet in excel.tables.keys) {
      final table = excel.tables[sheet]!;
      final batch = _firestore.batch();
      int successCount = 0;

      // التحقق من تطابق الأعمدة
      final headerRow = table.row(0);
      if (headerRow.length != _collections[sheet]!.length) {
        throw 'عدد الأعمدة في جدول $sheet غير متطابق';
      }

      // تحويل البيانات من Excel إلى Map
      for (var row = 1; row < table.maxRows; row++) {
        try {
          Map<String, dynamic> data = {};
          bool isValidRow = false;

          for (var col = 0; col < table.maxCols; col++) {
            final cellValue =
                table
                    .cell(
                      CellIndex.indexByColumnRow(
                        columnIndex: col,
                        rowIndex: row,
                      ),
                    )
                    .value;
            if (cellValue != null) {
              isValidRow = true;
              final fieldName = _collections[sheet]![col];

              // معالجة خاصة حسب نوع الجدول والحقل
              switch (sheet) {
                case 'apartments':
                case 'contracts':
                  // الحفاظ على المعالجة الحالية للوحدات والعقود
                  if (fieldName == 'number' || fieldName == 'projectNumber') {
                    data[fieldName] = cellValue.toString().replaceAll(
                      RegExp(r'\s+'),
                      '',
                    );
                  } else {
                    data[fieldName] = _processFieldValue(fieldName, cellValue);
                  }
                  break;

                case 'customers':
                  if (fieldName == 'identityNumber' ||
                      fieldName == 'name' ||
                      fieldName == 'phoneNumber') {
                    // تحويل إلى نص مع إزالة المسافات الزائدة
                    String stringValue = '';
                    
                    if (cellValue != null) {
                      // معالجة خاصة للأرقام الكبيرة
                      if (cellValue is num) {
                        // تحويل الرقم إلى نص بدون تنسيق علمي
                        stringValue = cellValue.toStringAsFixed(0);
                      } else {
                        stringValue = cellValue.toString();
                      }
                      
                      stringValue = stringValue.trim();
                      
                      // للأرقام الطويلة، تأكد من عدم وجود تنسيق علمي أو فواصل
                      if (fieldName == 'identityNumber' || fieldName == 'phoneNumber') {
                        // إزالة أي تنسيق علمي أو فواصل أو نقاط
                        stringValue = stringValue.replaceAll(RegExp(r'[^0-9]'), '');
                        
                        // التحقق من طول رقم الهوية (يجب أن يكون 10 أرقام للسعودية)
                        if (fieldName == 'identityNumber' && stringValue.length != 10 && stringValue.isNotEmpty) {
                          print('تحذير: رقم هوية غير صحيح في الصف $row: $stringValue (الطول: ${stringValue.length})');
                        }
                        
                        // التحقق من طول رقم الجوال
                        if (fieldName == 'phoneNumber' && stringValue.length < 9 && stringValue.isNotEmpty) {
                          print('تحذير: رقم جوال قصير في الصف $row: $stringValue');
                        }
                      }
                    }
                    
                    data[fieldName] = stringValue;
                  } else {
                    // أي حقل آخر يتم تحويله إلى نص
                    data[fieldName] = cellValue?.toString() ?? '';
                  }
                  break;

                case 'financialTransactions':
                  if (fieldName == 'amount') {
                    data[fieldName] =
                        double.tryParse(cellValue.toString()) ?? 0.0;
                  } else if (fieldName == 'date' || fieldName == 'createdAt') {
                    // استخدام نفس منطق معالجة التاريخ المحسن
                    data[fieldName] = _processFieldValue(fieldName, cellValue);
                  } else {
                    data[fieldName] = _processFieldValue(fieldName, cellValue);
                  }
                  break;

                default:
                  data[fieldName] = _processFieldValue(fieldName, cellValue);
              }
            }
          }

          // معالجة خاصة للإضافة حسب نوع الجدول
          if (isValidRow && data.isNotEmpty) {
            bool shouldAdd = true;
            String? uniqueField = _getUniqueFieldForCollection(sheet);

            if (uniqueField != null && data.containsKey(uniqueField)) {
              try {
                final existingDoc =
                    await _firestore
                        .collection(sheet)
                        .where(uniqueField, isEqualTo: data[uniqueField])
                        .limit(1)
                        .get();

                if (existingDoc.docs.isNotEmpty) {
                  shouldAdd = false;
                  print('تم تخطي السجل المكرر في $sheet: ${data[uniqueField]}');
                }
              } catch (e) {
                print('خطأ في التحقق من التكرار للسجل ${data[uniqueField]}: $e');
                // في حالة الخطأ، نضيف السجل لتجنب فقدان البيانات
                shouldAdd = true;
              }
            }

            if (shouldAdd) {
              final docRef = _firestore.collection(sheet).doc();
              batch.set(docRef, {
                ...data,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
              successCount++;
            }
          }
        } catch (e) {
          print('خطأ في معالجة الصف $row في جدول $sheet: $e');
        }
      }

      // تنفيذ العملية
      if (successCount > 0) {
        await batch.commit();
        
        // التحقق من أن الـ widget ما زال نشطاً قبل إظهار SnackBar
        if (mounted && context.mounted) {
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('تم إضافة $successCount سجل في جدول $sheet'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (scaffoldError) {
            print('تم إضافة $successCount سجل في جدول $sheet بنجاح');
          }
        } else {
          print('تم إضافة $successCount سجل في جدول $sheet بنجاح');
        }
      }
    }
  }

  // دالة مساعدة لمعالجة قيم الحقول
  dynamic _processFieldValue(String fieldName, dynamic value) {
    if (value == null) return null;

    if (fieldName.contains('Date') ||
        fieldName == 'createdAt' ||
        fieldName == 'updatedAt') {
      try {
        // التحقق من أن القيمة ليست رقماً كبيراً جداً
        String dateString = value.toString().trim();
        
        // إذا كانت القيمة رقماً كبيراً (أكبر من timestamp صحيح)
        if (RegExp(r'^\d+$').hasMatch(dateString)) {
          int? timestamp = int.tryParse(dateString);
          if (timestamp != null) {
            // التحقق من أن timestamp في نطاق صحيح
            if (timestamp > 253402300799000 || timestamp < -62135596800000) {
              print('تاريخ غير صحيح: $timestamp، سيتم استخدام التاريخ الحالي');
              return Timestamp.now();
            }
            // تحويل من milliseconds إلى DateTime
            return Timestamp.fromMillisecondsSinceEpoch(timestamp);
          }
        }
        
        // محاولة تحليل التاريخ كنص
        DateTime parsedDate = DateTime.parse(dateString);
        
        // التحقق من أن التاريخ في نطاق معقول
        if (parsedDate.year < 1900 || parsedDate.year > 2100) {
          print('تاريخ خارج النطاق المعقول: ${parsedDate.year}، سيتم استخدام التاريخ الحالي');
          return Timestamp.now();
        }
        
        return Timestamp.fromDate(parsedDate);
      } catch (e) {
        print('خطأ في تحليل التاريخ: $value، الخطأ: $e');
        return Timestamp.now();
      }
    }

    if (value is num) return value.toDouble();
    if (fieldName.contains('Amount') || fieldName.contains('Fee')) {
      return double.tryParse(value.toString()) ?? 0.0;
    }

    return value.toString();
  }

  // دالة مساعدة لتحديد الحقل الفريد لكل جدول
  String? _getUniqueFieldForCollection(String collection) {
    switch (collection) {
      case 'apartments':
      case 'contracts':
        return 'pn';
      case 'customers':
        return 'identityNumber';
      case 'financialTransactions':
        return 'transactionHash';
      case 'agencies':
        return 'agencyNumber';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'إدارة قاعدة البيانات',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // قسم الإجراءات
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      title: 'تصدير البيانات',
                      subtitle: 'تصدير إلى Excel',
                      icon: Icons.upload_rounded,
                      color: Color(0xFF2e7d32),
                      onPressed: _isExporting ? null : _exportDatabase,
                      isLoading: _isExporting,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildActionCard(
                      title: 'استيراد البيانات',
                      subtitle: 'استيراد من Excel',
                      icon: Icons.download_rounded,
                      color: Color(0xFF1565c0),
                      onPressed: _isImporting ? null : _importDatabase,
                      isLoading: _isImporting,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 32),

              // قسم الجداول المتاحة
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.table_chart, color: Color(0xFF1565c0)),
                          SizedBox(width: 12),
                          Text(
                            'الجداول المتاحة',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1565c0),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1),
                    ...(_collections.keys.map(
                      (name) => _buildTableItem(name),
                    )).toList(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    required bool isLoading,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    isLoading
                        ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        )
                        : Icon(icon, color: color, size: 24),
              ),
              SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableItem(String name) {
    return Container(
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFF1565c0).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.grid_on, color: Color(0xFF1565c0), size: 20),
        ),
        title: Text(
          name,
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
        ),
        subtitle: Text(
          '${_collections[name]?.length ?? 0} عمود',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      ),
    );
  }
}
