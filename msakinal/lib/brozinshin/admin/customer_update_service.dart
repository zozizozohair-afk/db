import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// خدمة تحديث بيانات العملاء في جميع الجداول المرتبطة
class CustomerUpdateService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// فحص توزيع بيانات العميل عبر الجداول المختلفة
  static Future<Map<String, int>> checkCustomerDataDistribution(
    String identityNumber,
  ) async {
    final distribution = <String, int>{
      'العملاء': 0,
      'العقود': 0,
      'الوحدات': 0,
      'المعاملات المالية': 0,
      'التكليفات': 0,
      'عقود إعادة البيع': 0,
    };

    try {
      // فحص جدول العملاء
      final customersQuery =
          await _firestore
              .collection('customers')
              .where('identityNumber', isEqualTo: identityNumber)
              .get();
      distribution['العملاء'] = customersQuery.docs.length;

      // فحص جدول العقود
      final contractsQueries = [
        _firestore
            .collection('contracts')
            .where('identityNumber', isEqualTo: identityNumber),
        _firestore
            .collection('contracts')
            .where('clientIdentity', isEqualTo: identityNumber),
        _firestore
            .collection('contracts')
            .where('clientData.identityNumber', isEqualTo: identityNumber),
      ];

      int contractsCount = 0;
      for (final query in contractsQueries) {
        final snapshot = await query.get();
        contractsCount += snapshot.docs.length;
      }
      distribution['العقود'] = contractsCount;

      // فحص جدول الوحدات
      final unitsQueries = [
        _firestore
            .collection('apartments')
            .where('customerId', isEqualTo: identityNumber),
        _firestore
            .collection('apartments')
            .where('clientIdentity', isEqualTo: identityNumber),
      ];

      int unitsCount = 0;
      for (final query in unitsQueries) {
        final snapshot = await query.get();
        unitsCount += snapshot.docs.length;
      }
      distribution['الوحدات'] = unitsCount;

      // فحص جدول المعاملات المالية
      // البحث برقم الهوية أولاً، ثم البحث باسم العميل إذا وجد
      final transactionsQueries = [
        _firestore
            .collection('financial_transactions')
            .where('idNumber', isEqualTo: identityNumber),
        _firestore
            .collection('financial_transactions')
            .where('identityNumber', isEqualTo: identityNumber),
        _firestore
            .collection('financial_transactions')
            .where('customerId', isEqualTo: identityNumber),
        // البحث في المجموعة الفرعية financialTransactions أيضاً
        _firestore
            .collection('financialTransactions')
            .where('idNumber', isEqualTo: identityNumber),
        _firestore
            .collection('financialTransactions')
            .where('identityNumber', isEqualTo: identityNumber),
        _firestore
            .collection('financialTransactions')
            .where('customerId', isEqualTo: identityNumber),
      ];
      
      // البحث باسم العميل أيضاً إذا كان متوفراً
      String? customerName;
      try {
        final customerDoc = await _firestore
            .collection('customers')
            .where('identityNumber', isEqualTo: identityNumber)
            .limit(1)
            .get();
        if (customerDoc.docs.isNotEmpty) {
          customerName = customerDoc.docs.first.data()['name'];
        }
      } catch (e) {
        // تجاهل الخطأ والمتابعة
      }
      
      if (customerName != null) {
        transactionsQueries.addAll([
          _firestore
              .collection('financial_transactions')
              .where('customerName', isEqualTo: customerName),
          _firestore
              .collection('financial_transactions')
              .where('clientName', isEqualTo: customerName),
          _firestore
              .collection('financialTransactions')
              .where('customerName', isEqualTo: customerName),
          _firestore
              .collection('financialTransactions')
              .where('clientName', isEqualTo: customerName),
        ]);
      }
      
      int transactionsCount = 0;
      final processedTransactionIds = <String>{};
      for (final query in transactionsQueries) {
        final snapshot = await query.get();
        for (final doc in snapshot.docs) {
          if (!processedTransactionIds.contains(doc.id)) {
            processedTransactionIds.add(doc.id);
            transactionsCount++;
          }
        }
      }
      distribution['المعاملات المالية'] = transactionsCount;

      // فحص جدول التكليفات
      final assignmentsQuery =
          await _firestore
              .collection('assignments')
              .where('identityNumber', isEqualTo: identityNumber)
              .get();
      distribution['التكليفات'] = assignmentsQuery.docs.length;

      // فحص جدول عقود إعادة البيع
      final resaleQuery =
          await _firestore
              .collection('resaleContracts')
              .where('identityNumber', isEqualTo: identityNumber)
              .get();
      distribution['عقود إعادة البيع'] = resaleQuery.docs.length;
    } catch (e) {
      print('خطأ في فحص توزيع البيانات: $e');
    }

    return distribution;
  }

  /// تحديث بيانات العميل في جميع الجداول المرتبطة
  /// [oldIdentityNumber] رقم الهوية القديم
  /// [newCustomerData] البيانات الجديدة للعميل
  static Future<Map<String, dynamic>> updateCustomerDataEverywhere({
    required String oldIdentityNumber,
    required Map<String, dynamic> newCustomerData,
    required BuildContext context,
  }) async {
    final results = {
      'success': false,
      'updatedTables': <String>[],
      'errors': <String>[],
      'totalUpdated': 0,
    };

    try {
      // 1. تحديث جدول العملاء
      await _updateCustomersTable(
        oldIdentityNumber: oldIdentityNumber,
        newCustomerData: newCustomerData,
        results: results,
      );

      // 2. تحديث جدول العقود
      await _updateContractsTable(
        oldIdentityNumber: oldIdentityNumber,
        newCustomerData: newCustomerData,
        results: results,
      );

      // 3. تحديث جدول المعاملات المالية
      await _updateFinancialTransactions(
        oldIdentityNumber: oldIdentityNumber,
        newCustomerData: newCustomerData,
        results: results,
      );

      // 4. تحديث جدول الوحدات
      await _updateUnitsTable(
        oldIdentityNumber: oldIdentityNumber,
        newCustomerData: newCustomerData,
        results: results,
      );

      // 5. تحديث جدول التنازلات
      await _updateAssignmentsTable(
        oldIdentityNumber: oldIdentityNumber,
        newCustomerData: newCustomerData,
        results: results,
      );

      // 6. تحديث جدول عقود إعادة البيع
      await _updateResaleContractsTable(
        oldIdentityNumber: oldIdentityNumber,
        newCustomerData: newCustomerData,
        results: results,
      );

      results['success'] = true;

      // عرض رسالة نجاح
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تحديث بيانات العميل بنجاح في ${results['totalUpdated']} سجل عبر ${(results['updatedTables'] as List).length} جدول',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      (results['errors'] as List<String>).add('خطأ عام: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تحديث بيانات العميل: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }

    return results;
  }

  /// تحديث جدول العملاء
  static Future<void> _updateCustomersTable({
    required String oldIdentityNumber,
    required Map<String, dynamic> newCustomerData,
    required Map<String, dynamic> results,
  }) async {
    try {
      final customersQuery =
          await _firestore
              .collection('customers')
              .where('identityNumber', isEqualTo: oldIdentityNumber)
              .get();

      if (customersQuery.docs.isNotEmpty) {
        final batch = _firestore.batch();

        for (final doc in customersQuery.docs) {
          batch.update(doc.reference, {
            'name': newCustomerData['name'],
            'identityNumber': newCustomerData['identityNumber'],
            'phoneNumber': newCustomerData['phoneNumber'],
            'lastModified': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
        results['updatedTables'].add('العملاء');
        results['totalUpdated'] += customersQuery.docs.length;
      }
    } catch (e) {
      results['errors'].add('خطأ في تحديث جدول العملاء: $e');
    }
  }

  /// تحديث جدول العقود
  static Future<void> _updateContractsTable({
    required String oldIdentityNumber,
    required Map<String, dynamic> newCustomerData,
    required Map<String, dynamic> results,
  }) async {
    try {
      // البحث بالطرق المختلفة المستخدمة في العقود
      final contractsQueries = [
        _firestore
            .collection('contracts')
            .where('identityNumber', isEqualTo: oldIdentityNumber),
        _firestore
            .collection('contracts')
            .where('clientIdentity', isEqualTo: oldIdentityNumber),
        _firestore
            .collection('contracts')
            .where('clientData.identityNumber', isEqualTo: oldIdentityNumber),
      ];

      final batch = _firestore.batch();
      int updatedCount = 0;

      for (final query in contractsQueries) {
        final querySnapshot = await query.get();

        for (final doc in querySnapshot.docs) {
          final data = doc.data();
          final updateData = <String, dynamic>{};

          // تحديث الحقول المختلفة حسب بنية البيانات
          if (data.containsKey('clientName')) {
            updateData['clientName'] = newCustomerData['name'];
          }
          if (data.containsKey('identityNumber')) {
            updateData['identityNumber'] = newCustomerData['identityNumber'];
          }
          if (data.containsKey('clientIdentity')) {
            updateData['clientIdentity'] = newCustomerData['identityNumber'];
          }
          if (data.containsKey('clientData')) {
            updateData['clientData.identityNumber'] =
                newCustomerData['identityNumber'];
            updateData['clientData.name'] = newCustomerData['name'];
            updateData['clientData.phoneNumber'] =
                newCustomerData['phoneNumber'];
          }
          if (data.containsKey('idNumber')) {
            updateData['idNumber'] = newCustomerData['identityNumber'];
          }

          if (updateData.isNotEmpty) {
            updateData['lastModified'] = FieldValue.serverTimestamp();
            batch.update(doc.reference, updateData);
            updatedCount++;
          }
        }
      }

      if (updatedCount > 0) {
        await batch.commit();
        results['updatedTables'].add('العقود');
        results['totalUpdated'] += updatedCount;
      }
    } catch (e) {
      results['errors'].add('خطأ في تحديث جدول العقود: $e');
    }
  }

  /// تحديث جدول المعاملات المالية
  static Future<void> _updateFinancialTransactions({
    required String oldIdentityNumber,
    required Map<String, dynamic> newCustomerData,
    required Map<String, dynamic> results,
  }) async {
    try {
      // البحث في المعاملات المالية باسم العميل بدلاً من رقم الهوية
      // هذا يسمح بتحديث رقم الهوية حتى لو تغير
      final customerName = newCustomerData['name'];
      final transactionsQueries = [
        _firestore
            .collection('financial_transactions')
            .where('customerName', isEqualTo: customerName),
        _firestore
            .collection('financial_transactions')
            .where('clientName', isEqualTo: customerName),
        // إضافة البحث في المجموعة الفرعية financialTransactions أيضاً
        _firestore
            .collection('financialTransactions')
            .where('customerName', isEqualTo: customerName),
        _firestore
            .collection('financialTransactions')
            .where('clientName', isEqualTo: customerName),
        // البحث برقم الهوية القديم كخيار احتياطي
        _firestore
            .collection('financial_transactions')
            .where('idNumber', isEqualTo: oldIdentityNumber),
        _firestore
            .collection('financial_transactions')
            .where('identityNumber', isEqualTo: oldIdentityNumber),
        _firestore
            .collection('financial_transactions')
            .where('customerId', isEqualTo: oldIdentityNumber),
        _firestore
            .collection('financialTransactions')
            .where('idNumber', isEqualTo: oldIdentityNumber),
        _firestore
            .collection('financialTransactions')
            .where('identityNumber', isEqualTo: oldIdentityNumber),
        _firestore
            .collection('financialTransactions')
            .where('customerId', isEqualTo: oldIdentityNumber),
      ];

      final batch = _firestore.batch();
      int updatedCount = 0;
      final processedDocs = <String>{}; // لتجنب التحديث المكرر

      for (final query in transactionsQueries) {
        final querySnapshot = await query.get();

        for (final doc in querySnapshot.docs) {
          // تجنب تحديث نفس المستند أكثر من مرة
          if (processedDocs.contains(doc.id)) continue;
          processedDocs.add(doc.id);
          
          final data = doc.data();
          final updateData = <String, dynamic>{};

          // تحديث جميع الحقول المحتملة
          if (data.containsKey('customerName')) {
            updateData['customerName'] = newCustomerData['name'];
          }
          if (data.containsKey('clientName')) {
            updateData['clientName'] = newCustomerData['name'];
          }
          if (data.containsKey('idNumber')) {
            updateData['idNumber'] = newCustomerData['identityNumber'];
          }
          if (data.containsKey('identityNumber')) {
            updateData['identityNumber'] = newCustomerData['identityNumber'];
          }
          if (data.containsKey('customerId')) {
            updateData['customerId'] = newCustomerData['identityNumber'];
          }
          // إضافة تحديث رقم الجوال إذا كان موجوداً
          if (data.containsKey('customerPhone')) {
            updateData['customerPhone'] = newCustomerData['phoneNumber'];
          }
          if (data.containsKey('clientPhone')) {
            updateData['clientPhone'] = newCustomerData['phoneNumber'];
          }

          if (updateData.isNotEmpty) {
            updateData['lastModified'] = FieldValue.serverTimestamp();
            batch.update(doc.reference, updateData);
            updatedCount++;
          }
        }
      }

      if (updatedCount > 0) {
        await batch.commit();
        results['updatedTables'].add('المعاملات المالية');
        results['totalUpdated'] += updatedCount;
      }
    } catch (e) {
      results['errors'].add('خطأ في تحديث جدول المعاملات المالية: $e');
    }
  }

  /// تحديث جدول الوحدات
  static Future<void> _updateUnitsTable({
    required String oldIdentityNumber,
    required Map<String, dynamic> newCustomerData,
    required Map<String, dynamic> results,
  }) async {
    try {
      // البحث بالطرق المختلفة المستخدمة في الوحدات
      final unitsQueries = [
        _firestore
            .collection('apartments')
            .where('customerId', isEqualTo: oldIdentityNumber),
        _firestore
            .collection('apartments')
            .where('clientIdentity', isEqualTo: oldIdentityNumber),
        _firestore
            .collection('apartments')
            .where('clientRef', isEqualTo: oldIdentityNumber),
      ];

      final batch = _firestore.batch();
      int updatedCount = 0;

      for (final query in unitsQueries) {
        final querySnapshot = await query.get();

        for (final doc in querySnapshot.docs) {
          final data = doc.data();
          final updateData = <String, dynamic>{};

          // تحديث الحقول المختلفة حسب بنية البيانات
          if (data.containsKey('customerName')) {
            updateData['customerName'] = newCustomerData['name'];
          }
          if (data.containsKey('customerId')) {
            updateData['customerId'] = newCustomerData['identityNumber'];
          }
          if (data.containsKey('clientName')) {
            updateData['clientName'] = newCustomerData['name'];
          }
          if (data.containsKey('clientIdentity')) {
            updateData['clientIdentity'] = newCustomerData['identityNumber'];
          }
          if (data.containsKey('clientPhone')) {
            updateData['clientPhone'] = newCustomerData['phoneNumber'];
          }
          if (data.containsKey('clientRef')) {
            updateData['clientRef'] = newCustomerData['identityNumber'];
          }

          if (updateData.isNotEmpty) {
            updateData['lastModified'] = FieldValue.serverTimestamp();
            batch.update(doc.reference, updateData);
            updatedCount++;
          }
        }
      }

      if (updatedCount > 0) {
        await batch.commit();
        results['updatedTables'].add('الوحدات');
        results['totalUpdated'] += updatedCount;
      }
    } catch (e) {
      results['errors'].add('خطأ في تحديث جدول الوحدات: $e');
    }
  }

  /// تحديث جدول التنازلات
  static Future<void> _updateAssignmentsTable({
    required String oldIdentityNumber,
    required Map<String, dynamic> newCustomerData,
    required Map<String, dynamic> results,
  }) async {
    try {
      // البحث في التنازلات كمالك أصلي أو مالك جديد
      final assignmentsQueries = [
        _firestore
            .collection('contract_assignments')
            .where('originalOwnerID', isEqualTo: oldIdentityNumber),
        _firestore
            .collection('contract_assignments')
            .where('newOwnerID', isEqualTo: oldIdentityNumber),
      ];

      final batch = _firestore.batch();
      int updatedCount = 0;

      for (final query in assignmentsQueries) {
        final querySnapshot = await query.get();

        for (final doc in querySnapshot.docs) {
          final data = doc.data();
          final updateData = <String, dynamic>{};

          // تحديث بيانات المالك الأصلي
          if (data['originalOwnerID'] == oldIdentityNumber) {
            updateData['originalOwnerName'] = newCustomerData['name'];
            updateData['originalOwnerID'] = newCustomerData['identityNumber'];
          }

          // تحديث بيانات المالك الجديد
          if (data['newOwnerID'] == oldIdentityNumber) {
            updateData['newOwnerName'] = newCustomerData['name'];
            updateData['newOwnerID'] = newCustomerData['identityNumber'];
          }

          if (updateData.isNotEmpty) {
            updateData['lastModified'] = FieldValue.serverTimestamp();
            batch.update(doc.reference, updateData);
            updatedCount++;
          }
        }
      }

      if (updatedCount > 0) {
        await batch.commit();
        results['updatedTables'].add('التنازلات');
        results['totalUpdated'] += updatedCount;
      }
    } catch (e) {
      results['errors'].add('خطأ في تحديث جدول التنازلات: $e');
    }
  }

  /// تحديث جدول عقود إعادة البيع
  static Future<void> _updateResaleContractsTable({
    required String oldIdentityNumber,
    required Map<String, dynamic> newCustomerData,
    required Map<String, dynamic> results,
  }) async {
    try {
      final resaleQuery =
          await _firestore
              .collection('resale_contracts')
              .where('identityNumber', isEqualTo: oldIdentityNumber)
              .get();

      if (resaleQuery.docs.isNotEmpty) {
        final batch = _firestore.batch();

        for (final doc in resaleQuery.docs) {
          batch.update(doc.reference, {
            'clientName': newCustomerData['name'],
            'identityNumber': newCustomerData['identityNumber'],
            'lastModified': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
        results['updatedTables'].add('عقود إعادة البيع');
        results['totalUpdated'] += resaleQuery.docs.length;
      }
    } catch (e) {
      results['errors'].add('خطأ في تحديث جدول عقود إعادة البيع: $e');
    }
  }

  /// التحقق من وجود بيانات العميل في الجداول المختلفة
  static Future<Map<String, int>> checkCustomerDistribution(
    String identityNumber,
  ) async {
    final distribution = <String, int>{};

    try {
      // فحص جدول العملاء
      final customersQuery =
          await _firestore
              .collection('customers')
              .where('identityNumber', isEqualTo: identityNumber)
              .get();
      distribution['العملاء'] = customersQuery.docs.length;

      // فحص جدول العقود
      final contractsQuery =
          await _firestore
              .collection('contracts')
              .where('identityNumber', isEqualTo: identityNumber)
              .get();
      distribution['العقود'] = contractsQuery.docs.length;

      // فحص جدول المعاملات المالية
      final transactionsQuery =
          await _firestore
              .collection('financial_transactions')
              .where('idNumber', isEqualTo: identityNumber)
              .get();
      distribution['المعاملات المالية'] = transactionsQuery.docs.length;

      // فحص جدول الوحدات
      final unitsQuery =
          await _firestore
              .collection('apartments')
              .where('customerId', isEqualTo: identityNumber)
              .get();
      distribution['الوحدات'] = unitsQuery.docs.length;
    } catch (e) {
      print('خطأ في فحص توزيع بيانات العميل: $e');
    }

    return distribution;
  }
}
