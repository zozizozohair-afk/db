import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// مساعد لإدارة عمليات تحديث حالة العقود وتحديث البيانات المرتبطة
class ContractDeleteHelper {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // التحقق مما إذا كان المستخدم الحالي هو المستخدم المحدد
  bool _isSpecialUser() {
    final User? currentUser = _auth.currentUser;
    return currentUser != null &&
        currentUser.email == 'zizoalzohairy@gmail.com';
  }

  Future<bool> deleteContract(String contractId, BuildContext? context) async {
    try {
      // جلب وثيقة العقد
      final contractDoc =
          await FirebaseFirestore.instance
              .collection('contracts')
              .doc(contractId)
              .get();

      if (!contractDoc.exists) {
        print('❌ العقد غير موجود');
        return false;
      }

      final contractData = contractDoc.data();
      final pn = contractData?['pn'];

      if (pn == null || pn.toString().isEmpty) {
        print('❌ رقم العقد غير موجود في بيانات الوثيقة');
        return false;
      }

      // تنظيف البيانات المرتبطة باستخدام pn
      final success = await cleanContractDataByPn(pn, context);

      if (!success) return false;

      // حذف وثيقة العقد نفسها
      await FirebaseFirestore.instance
          .collection('contracts')
          .doc(contractId)
          .delete();
      print('✅ تم حذف العقد بنجاح');
      return true;
    } catch (e) {
      print('❌ خطأ أثناء حذف العقد: $e');
      return false;
    }
  }

  Future<bool> cleanContractDataByPn(
    String pnValue,
    BuildContext? context,
  ) async {
    try {
      print('🚀 بدء عملية تنظيف البيانات المرتبطة برقم العقد: $pnValue');

      // 🏢 1. تحديث الوحدة المرتبطة
      final apartmentQuery =
          await _firestore
              .collection('apartments')
              .where('pn', isEqualTo: pnValue)
              .get();

      for (final doc in apartmentQuery.docs) {
        print('🏠 تحديث الوحدة ${doc.id}');
        await doc.reference.update({
          'status': 'متاح',
          'totalAmount': FieldValue.delete(),
          'tot': FieldValue.delete(),
          'clientName': FieldValue.delete(),
          'clientIdentity': FieldValue.delete(),
          'clientPhone': FieldValue.delete(),
          'تاريخ العقد تحت الانشاء': FieldValue.delete(),
        });
      }

      // 💸 2. حذف العمليات المالية المرتبطة
      final financialQuery =
          await _firestore
              .collection('financialTransactions')
              .where('pn', isEqualTo: pnValue)
              .get();

      for (final doc in financialQuery.docs) {
        print('💸 حذف العملية المالية ${doc.id}');
        await doc.reference.delete();
      }

      // 👤 3. تحديث بيانات العميل: إزالة رقم العقد من قائمة العقود
      final customerQuery =
          await _firestore
              .collection('customers')
              .where('contractNumbers', arrayContains: pnValue)
              .get();

      for (final doc in customerQuery.docs) {
        print('👤 إزالة رقم العقد من العميل ${doc.id}');
        await doc.reference.update({
          'contractNumbers': FieldValue.arrayRemove([pnValue]),
        });
      }

      _showSuccessMessage(
        context,
        '✅ تم تنظيف البيانات المرتبطة برقم العقد بنجاح',
      );
      return true;
    } catch (e) {
      print('❌ خطأ أثناء تنظيف البيانات: $e');
      _showErrorMessage(context, 'حدث خطأ أثناء التنظيف: $e');
      return false;
    }
  }

  /// حذف عقد إعادة البيع وإعادة حالة العقد الأصلي والوحدة
  Future<bool> deleteResaleContractByPn(
    String resalePn,
    BuildContext? context,
  ) async {
    try {
      print('🚀 بدء حذف عقد إعادة البيع بناءً على pn: $resalePn');

      // 1. جلب وثيقة عقد إعادة البيع عبر pn
      final resaleQuery =
          await _firestore
              .collection('resale_contracts')
              .where('pn', isEqualTo: resalePn)
              .limit(1)
              .get();

      if (resaleQuery.docs.isEmpty) {
        throw Exception('عقد إعادة البيع برقم $resalePn غير موجود');
      }

      final resaleDoc = resaleQuery.docs.first;
      final resaleData = resaleDoc.data();
      final resaleContractRef = resaleDoc.reference;

      final String? projectNumber = resaleData['projectNumber'];
      final String? unitNumber =
          resaleData['unitNumber'] ?? resaleData['number'];

      if (projectNumber == null || unitNumber == null) {
        throw Exception('بيانات عقد إعادة البيع غير مكتملة');
      }

      print(
        '📦 البيانات: pn=$resalePn | المشروع=$projectNumber | الوحدة=$unitNumber',
      );

      // 2. تحديث حالة العقد الأصلي إلى "تحت الإنشاء"
      final originalContractQuery =
          await _firestore
              .collection('contracts')
              .where('pn', isEqualTo: resalePn)
              .limit(1)
              .get();

      if (originalContractQuery.docs.isNotEmpty) {
        final originalContractRef = originalContractQuery.docs.first.reference;
        await originalContractRef.update({'status': 'تحت الإنشاء'});
        print('✅ تم تعديل حالة العقد الأصلي إلى "تحت الإنشاء"');
      }

      // 3. تحديث بيانات الوحدة المرتبطة بالعقد الأصلي
      final apartmentQuery =
          await _firestore
              .collection('apartments')
              .where('pn', isEqualTo: resalePn)
              .limit(1)
              .get();

      if (apartmentQuery.docs.isNotEmpty) {
        final apartmentRef = apartmentQuery.docs.first.reference;
        await apartmentRef.update({'status': 'مباع', 'pn': resalePn});
        print('🏠 تم تحديث بيانات الوحدة المرتبطة');
      }

      // 4. حذف العمليات المالية المرتبطة بـ pn
      final financialQuery =
          await _firestore
              .collection('financialTransactions')
              .where('pn', isEqualTo: resalePn)
              .get();

      for (final doc in financialQuery.docs) {
        await doc.reference.delete();
        print('🗑️ تم حذف العملية المالية ${doc.id}');
      }

      // 5. حذف وثيقة إعادة البيع
      await resaleContractRef.delete();
      print('✅ تم حذف وثيقة عقد إعادة البيع المرتبطة بالـ pn');

      _showSuccessMessage(
        context,
        'تم حذف عقد إعادة البيع بنجاح باستخدام رقم العقد',
      );
      return true;
    } catch (e) {
      print('❌ خطأ أثناء حذف عقد إعادة البيع: $e');
      _showErrorMessage(context, 'حدث خطأ أثناء حذف عقد إعادة البيع: $e');
      return false;
    }
  }

  /// حذف التسوية المالية وإعادة حالة العقد الأصلي
  Future<bool> deleteFinancialSettlement(
    String settlementId,
    BuildContext? context,
  ) async {
    final firestore = _firestore;

    // 1. جلب بيانات التسوية المالية
    final settlementDoc =
        await firestore
            .collection('financial_settlements')
            .doc(settlementId)
            .get();
    final settlementData = settlementDoc.data() as Map<String, dynamic>;

    // 2. جلب رقم الوحدة مع t من التسوية المالية (newContractNumber)
    final String? pnWithT = settlementData['newContractNumber'];
    if (pnWithT == null || pnWithT.isEmpty) {
      _showErrorMessage(
        context,
        'رقم العقد الجديد (newContractNumber) غير موجود في بيانات التسوية',
      );
      return false;
    }
    // إزالة t للحصول على رقم الوحدة الأصلي
    final String unitPn = '${pnWithT}t';

    // 3. جلب الوحدة
    final unitSnapshot =
        await firestore
            .collection('apartments')
            .where('pn', isEqualTo: pnWithT)
            .limit(1)
            .get();
    if (unitSnapshot.docs.isEmpty) {
      _showErrorMessage(context, 'لم يتم العثور على الوحدة');
      return false;
    }
    final unitDoc = unitSnapshot.docs.first;
    final unitData = unitDoc.data();
    final unitDocId = unitDoc.id;

    // 4. جلب العقد الأصلي المرتبط بالوحدة
    final contractSnapshot =
        await firestore
            .collection('contracts')
            .where('pn', isEqualTo: pnWithT)
            .limit(1)
            .get();
    if (contractSnapshot.docs.isEmpty) {
      _showErrorMessage(context, 'لم يتم العثور على العقد الأصلي');
      return false;
    }
    final contractDoc = contractSnapshot.docs.first;
    final contractData = contractDoc.data();
    final contractDocId = contractDoc.id;

    // 5. جلب بيانات العميل القديم من العقد الأصلي
    final oldClientData = contractData['clientData'] as Map<String, dynamic>?;
    final oldClientName = contractData['clientName'];
    final oldClientIdentity = oldClientData?['identityNumber'];
    final oldClientPhone = oldClientData?['phoneNumber'];
    if (oldClientName == null || oldClientIdentity == null) {
      _showErrorMessage(context, 'بيانات العميل الأصلي غير مكتملة في العقد');
      return false;
    }

    // 6. جلب بيانات العميل الجديد من التسوية المالية (newCustomerId)
    String? newClientIdentity = settlementData['newCustomerId'];

    // 7. جلب العميل الجديد من جدول العملاء
    DocumentSnapshot<Map<String, dynamic>>? newClientDoc;
    if (newClientIdentity != null) {
      final newClientSnapshot =
          await firestore
              .collection('customers')
              .where('identityNumber', isEqualTo: newClientIdentity)
              .limit(1)
              .get();
      if (newClientSnapshot.docs.isNotEmpty) {
        newClientDoc = newClientSnapshot.docs.first;
      }
    }

    // 8. جلب العميل القديم من جدول العملاء
    DocumentSnapshot<Map<String, dynamic>>? oldClientDoc;
    final oldClientSnapshot =
        await firestore
            .collection('customers')
            .where('identityNumber', isEqualTo: oldClientIdentity)
            .limit(1)
            .get();
    if (oldClientSnapshot.docs.isNotEmpty) {
      oldClientDoc = oldClientSnapshot.docs.first;
    }

    // 9. حذف رقم العقد مع t من العميل الجديد (إن وجد)
    if (newClientDoc != null) {
      final newClientContracts =
          (newClientDoc.data()?['contractNumbers'] as List?)?.cast<String>() ??
          [];
      if (newClientContracts.contains(unitPn)) {
        newClientContracts.remove(unitPn);
        await firestore.collection('customers').doc(newClientDoc.id).update({
          'contractNumbers': newClientContracts,
        });
      }
    }

    // 10. حذف رقم العقد مع t من العميل القديم (إن وجد)
    if (oldClientDoc != null) {
      final oldClientContracts =
          (oldClientDoc.data()?['contractNumbers'] as List?)?.cast<String>() ??
          [];
      if (oldClientContracts.contains(unitPn)) {
        oldClientContracts.remove(unitPn);
        await firestore.collection('customers').doc(oldClientDoc.id).update({
          'contractNumbers': oldClientContracts,
        });
      }
    }

    // 11. إعادة بيانات الوحدة إلى العميل القديم
    await firestore.collection('apartments').doc(unitDocId).update({
      'clientName': oldClientName,
      'clientIdentity': oldClientIdentity,
      'status': 'معروضة للبيع',
      'clientPhone': oldClientPhone,
    });

    // 12. إعادة العقد إلى حالته الأصلية وتحديث العميل
    await firestore.collection('contracts').doc(contractDocId).update({
      'clientName': oldClientName,
      'clientData': oldClientData,
      'status': 'إعادة بيع',
      'settlementContractNumber': FieldValue.delete(),
    });
    print('oldClientName: $oldClientName');
    print('oldClientIdentity: $oldClientIdentity');
    print('oldClientPhone: $oldClientPhone');
    print('oldClientData: $oldClientData');
    // 13. حذف التسوية المالية نفسها
    await firestore
        .collection('financial_settlements')
        .doc(settlementId)
        .delete();

    // 14. حذف العمليات المالية المرتبطة بالتسوية (اختياري: يمكن ربطها بـ pnWithT أو التسوية)
    await _deleteFinancialTransactions(pnWithT, context);

    _showSuccessMessage(
      context,
      'تم حذف التسوية المالية واسترجاع العميل السابق بنجاح',
    );
    return true;
  }

  /// حذف عقد الإفراغ وإعادة حالة العقد الأصلي
  Future<bool> deleteEmptyingContract(
    String emptyingId,
    BuildContext? context,
  ) async {
    try {
      // 1. جلب بيانات عقد الإفراغ وحفظها قبل الحذف
      final emptyingDoc =
          await _firestore
              .collection('emptying_contracts')
              .doc(emptyingId)
              .get();
      if (!emptyingDoc.exists) {
        _showErrorMessage(context, 'عقد الإفراغ غير موجود');
        return false;
      }

      // 2. حفظ جميع البيانات المطلوبة قبل حذف العقد
      final emptyingData = emptyingDoc.data() as Map<String, dynamic>;
      final originalContractNumber = emptyingData['originalContractNumber'];
      final pn = emptyingData['pn'];
      final projectNumber = emptyingData['projectNumber'];
      // استخدام unitNumber إذا كان موجودًا، وإلا استخدام number
      final unitNumber =
          emptyingData['unitNumber'] ?? emptyingData['number'] ?? '';

      // حفظ الحالات السابقة
      String previousStatus = 'تحت الإنشاء';
      if (emptyingData['previousStatus'] != null) {
        previousStatus = emptyingData['previousStatus'];
      }

      String previousApartmentStatus = 'مباع';
      if (emptyingData['previousApartmentStatus'] != null) {
        previousApartmentStatus = emptyingData['previousApartmentStatus'];
      }

      // 3. حذف عقد الإفراغ نفسه أولاً
      await _firestore
          .collection('emptying_contracts')
          .doc(emptyingId)
          .delete();

      // 4. تحديث حالة العقد الأصلي إلى الحالة السابقة
      await _updateOriginalContractStatus(
        originalContractNumber,
        previousStatus,
        context,
      );

      // 5. تحديث حالة الوحدة إلى الحالة السابقة
      await _updateApartmentStatusCustom(
        projectNumber,
        unitNumber,
        pn,
        previousApartmentStatus,
        context,
      );

      // 6. حذف العمليات المالية المرتبطة بعقد الإفراغ
      await _deleteFinancialTransactions(pn, context);

      _showSuccessMessage(context, 'تم حذف عقد الإفراغ بنجاح');
      return true;
    } catch (e) {
      _showErrorMessage(context, 'حدث خطأ أثناء حذف عقد الإفراغ: $e');
      return false;
    }
  }

  // دوال مساعدة

  /// تحديث حالة الوحدة إلى "متاح" وحذف بيانات العميل
  Future<void> _updateApartmentStatus(
    String projectNumber,
    String unitNumber,
    String pn,
    BuildContext? context,
  ) async {
    try {
      // التحقق مما إذا كان المستخدم هو المستخدم المحدد
      final bool isSpecialUser = _isSpecialUser();
      print(
        'بدء تحديث حالة الوحدة: المشروع=$projectNumber، الوحدة=$unitNumber، رقم العقد=$pn',
      );

      if (projectNumber.isEmpty || unitNumber.isEmpty) {
        print('تحذير: رقم المشروع أو رقم الوحدة فارغ، لا يمكن تحديث الوحدة');
        return;
      }

      // محاولات متعددة للبحث عن الوحدة باستخدام معايير مختلفة
      QuerySnapshot? apartmentQuery;

      // المحاولة الأولى: البحث باستخدام projectNumber و unitNumber
      print('محاولة البحث باستخدام projectNumber و unitNumber');
      apartmentQuery =
          await _firestore
              .collection('apartments')
              .where('projectNumber', isEqualTo: projectNumber)
              .where('unitNumber', isEqualTo: unitNumber)
              .limit(1)
              .get();

      // المحاولة الثانية: البحث باستخدام projectNumber و number
      if (apartmentQuery.docs.isEmpty) {
        print(
          'لم يتم العثور على الوحدة باستخدام unitNumber، محاولة البحث باستخدام number',
        );
        apartmentQuery =
            await _firestore
                .collection('apartments')
                .where('projectNumber', isEqualTo: projectNumber)
                .where('number', isEqualTo: unitNumber)
                .limit(1)
                .get();
      }

      // المحاولة الثالثة: البحث باستخدام pn
      if (apartmentQuery.docs.isEmpty && pn.isNotEmpty) {
        print(
          'لم يتم العثور على الوحدة باستخدام number، محاولة البحث باستخدام pn',
        );
        apartmentQuery =
            await _firestore
                .collection('apartments')
                .where('pn', isEqualTo: pn)
                .limit(1)
                .get();
      }

      // المحاولة الرابعة: البحث باستخدام contractNumber
      if (apartmentQuery.docs.isEmpty && pn.isNotEmpty) {
        print(
          'لم يتم العثور على الوحدة باستخدام pn، محاولة البحث باستخدام contractNumber',
        );
        apartmentQuery =
            await _firestore
                .collection('apartments')
                .where('contractNumber', isEqualTo: pn)
                .limit(1)
                .get();
      }

      // إذا تم العثور على الوحدة، قم بتحديثها
      if (apartmentQuery.docs.isNotEmpty) {
        final apartmentDoc = apartmentQuery.docs.first;
        final apartmentId = apartmentDoc.id;
        final currentData = apartmentDoc.data();
        print('تم العثور على الوحدة، معرف الوحدة: $apartmentId');

        // تحديث الحقول بشكل صحيح وضمان مسح جميع البيانات المرتبطة بالعقد
        final Map<String, dynamic> updateData = {
          'status': 'متاح',
          'pn': '', // مسح رقم العقد
          'totalAmount': 0,
          'paidAmount': 0,
          'tot': 0,
          'contractNumber': '', // مسح رقم العقد الإضافي
          'clientName': FieldValue.delete(),
          'clientIdentity': FieldValue.delete(),
        };

        // حذف الحقول المرتبطة بالعميل
        final List<String> fieldsToDelete = [
          'clientName',
          'clientIdentity',
          'clientPhone',
          'تاريخ العقد تحت الانشاء',
          'تاريخ الافراغ',
          'تاريخ اعادة البيع',
        ];

        // إذا كان المستخدم هو المستخدم المحدد، قم بحذف جميع بيانات العميل
        if (isSpecialUser) {
          // إضافة حقول إضافية للحذف للمستخدم المحدد
          fieldsToDelete.addAll([
            'clientData',
            'clientEmail',
            'clientMobile',
            'clientAddress',
            'clientNationality',
          ]);
        }

        // إضافة عمليات حذف الحقول إلى كائن التحديث
        if (currentData is Map<String, dynamic>) {
          for (final field in fieldsToDelete) {
            if (currentData.containsKey(field)) {
              updateData[field] = FieldValue.delete();
            }
          }
        }

        // تنفيذ التحديث
        await _firestore
            .collection('apartments')
            .doc(apartmentId)
            .update(updateData);
        print('تم تحديث حالة الوحدة بنجاح، الحالة الجديدة: متاح');

        // تحقق من نجاح التحديث
        final verifyDoc =
            await _firestore.collection('apartments').doc(apartmentId).get();
        final verifyData = verifyDoc.data();
        print(
          'التحقق من التحديث: الحالة=${verifyData?['status']}, pn=${verifyData?['pn']}',
        );
      } else {
        print('تحذير: لم يتم العثور على الوحدة باستخدام أي من معايير البحث');
        print(
          'معايير البحث: المشروع=$projectNumber، الوحدة=$unitNumber، رقم العقد=$pn',
        );

        // محاولة أخيرة: عرض جميع الوحدات في المشروع للتشخيص
        if (projectNumber.isNotEmpty) {
          final allUnits =
              await _firestore
                  .collection('apartments')
                  .where('projectNumber', isEqualTo: projectNumber)
                  .get();

          if (allUnits.docs.isNotEmpty) {
            print('وحدات المشروع $projectNumber:');
            for (final doc in allUnits.docs) {
              final data = doc.data();
              print(
                '- وحدة رقم: ${data['number'] ?? data['unitNumber']}, الحالة: ${data['status']}, pn: ${data['pn']}',
              );
            }
          } else {
            print('لا توجد وحدات في المشروع $projectNumber');
          }
        }
      }
    } catch (e) {
      print('خطأ في تحديث حالة الوحدة: $e');
    }
  }

  /// تحديث حالة الوحدة إلى "مباع"
  Future<void> _updateApartmentStatusToSold(
    String projectNumber,
    String unitNumber,
    String pn,
    BuildContext? context,
  ) async {
    try {
      // تصحيح الاستعلام للبحث عن الوحدة باستخدام رقم المشروع ورقم الوحدة
      final apartmentQuery =
          await _firestore
              .collection('apartments')
              .where('projectNumber', isEqualTo: projectNumber)
              .where('unitNumber', isEqualTo: unitNumber)
              .limit(1)
              .get();

      if (apartmentQuery.docs.isEmpty) {
        // محاولة ثانية باستخدام حقل 'number' في حالة استخدامه بدلاً من 'unitNumber'
        final secondQuery =
            await _firestore
                .collection('apartments')
                .where('projectNumber', isEqualTo: projectNumber)
                .where('number', isEqualTo: unitNumber)
                .limit(1)
                .get();

        if (secondQuery.docs.isNotEmpty) {
          final apartmentDoc = secondQuery.docs.first;
          // تحديث الحقول بشكل صحيح وضمان تحديث حقل pn وإضافة حقل contractNumber
          await _firestore.collection('apartments').doc(apartmentDoc.id).update(
            {
              'status': 'مباع',
              'pn': pn, // إضافة حقل pn
              'contractNumber': pn, // إضافة حقل إضافي قد يكون مستخدمًا
            },
          );
          print('تم تحديث حالة الوحدة إلى مباع باستخدام حقل number');
        } else {
          print(
            'لم يتم العثور على الوحدة باستخدام رقم المشروع $projectNumber ورقم الوحدة $unitNumber',
          );
        }
      } else {
        final apartmentDoc = apartmentQuery.docs.first;
        // تحديث الحقول بشكل صحيح وضمان تحديث حقل pn وإضافة حقل contractNumber
        await _firestore.collection('apartments').doc(apartmentDoc.id).update({
          'status': 'مباع',
          'pn': pn, // إضافة حقل pn
          'contractNumber': pn, // إضافة حقل إضافي قد يكون مستخدمًا
        });
        print('تم تحديث حالة الوحدة إلى مباع باستخدام حقل unitNumber');
      }
    } catch (e) {
      print('خطأ في تحديث حالة الوحدة: $e');
    }
  }

  /// تحديث حالة الوحدة إلى "معروضة للبيع"
  Future<void> _updateApartmentStatusToResale(
    String projectNumber,
    String unitNumber,
    String pn,
    BuildContext? context,
  ) async {
    try {
      print(
        'بدء تحديث حالة الوحدة إلى معروضة للبيع: المشروع=$projectNumber، الوحدة=$unitNumber، رقم العقد=$pn',
      );

      // تصحيح الاستعلام للبحث عن الوحدة باستخدام رقم المشروع ورقم الوحدة
      final apartmentQuery =
          await _firestore
              .collection('apartments')
              .where('projectNumber', isEqualTo: projectNumber)
              .where('unitNumber', isEqualTo: unitNumber)
              .limit(1)
              .get();

      if (apartmentQuery.docs.isEmpty) {
        print(
          'لم يتم العثور على الوحدة باستخدام unitNumber، محاولة البحث باستخدام number',
        );
        // محاولة ثانية باستخدام حقل 'number' في حالة استخدامه بدلاً من 'unitNumber'
        final secondQuery =
            await _firestore
                .collection('apartments')
                .where('projectNumber', isEqualTo: projectNumber)
                .where('number', isEqualTo: unitNumber)
                .limit(1)
                .get();

        if (secondQuery.docs.isNotEmpty) {
          final apartmentDoc = secondQuery.docs.first;
          final apartmentId = apartmentDoc.id;
          print(
            'تم العثور على الوحدة باستخدام number، معرف الوحدة: $apartmentId',
          );

          // تحديث الحقول بشكل صحيح وضمان تحديث حقل pn وإضافة حقل contractNumber
          final updateData = {
            'status': 'معروضة للبيع',
            'pn': pn,
            'contractNumber': pn, // إضافة حقل إضافي قد يكون مستخدمًا
          };

          await _firestore
              .collection('apartments')
              .doc(apartmentId)
              .update(updateData);
          print('تم تحديث حالة الوحدة إلى معروضة للبيع باستخدام حقل number');

          // تحقق من نجاح التحديث
          final verifyDoc =
              await _firestore.collection('apartments').doc(apartmentId).get();
          final verifyData = verifyDoc.data();
          print(
            'التحقق من التحديث: الحالة=${verifyData?['status']}, pn=${verifyData?['pn']}',
          );
        } else {
          print(
            'تحذير: لم يتم العثور على الوحدة باستخدام رقم المشروع $projectNumber ورقم الوحدة $unitNumber',
          );

          // محاولة ثالثة: البحث عن الوحدة باستخدام رقم المشروع فقط
          print('محاولة البحث عن الوحدة باستخدام رقم المشروع فقط');
          final thirdQuery =
              await _firestore
                  .collection('apartments')
                  .where('projectNumber', isEqualTo: projectNumber)
                  .get();

          if (thirdQuery.docs.isNotEmpty) {
            print(
              'تم العثور على ${thirdQuery.docs.length} وحدة في المشروع $projectNumber',
            );
            print(
              'الوحدات المتاحة: ${thirdQuery.docs.map((doc) => '${doc.data()['unitNumber'] ?? doc.data()['number']}').join(', ')}',
            );
          } else {
            print('لم يتم العثور على أي وحدات في المشروع $projectNumber');
          }
        }
      } else {
        final apartmentDoc = apartmentQuery.docs.first;
        final apartmentId = apartmentDoc.id;
        print(
          'تم العثور على الوحدة باستخدام unitNumber، معرف الوحدة: $apartmentId',
        );

        // تحديث الحقول بشكل صحيح وضمان تحديث حقل pn وإضافة حقل contractNumber
        final updateData = {
          'status': 'معروضة للبيع',
          'pn': pn,
          'contractNumber': pn, // إضافة حقل إضافي قد يكون مستخدمًا
        };

        await _firestore
            .collection('apartments')
            .doc(apartmentId)
            .update(updateData);
        print('تم تحديث حالة الوحدة إلى معروضة للبيع باستخدام حقل unitNumber');

        // تحقق من نجاح التحديث
        final verifyDoc =
            await _firestore.collection('apartments').doc(apartmentId).get();
        final verifyData = verifyDoc.data();
        print(
          'التحقق من التحديث: الحالة=${verifyData?['status']}, pn=${verifyData?['pn']}',
        );
      }
    } catch (e) {
      print('خطأ في تحديث حالة الوحدة إلى معروضة للبيع: $e');
    }
  }

  /// تحديث حالة الوحدة إلى حالة مخصصة
  Future<void> _updateApartmentStatusCustom(
    String projectNumber,
    String unitNumber,
    String pn,
    String status,
    BuildContext? context,
  ) async {
    try {
      // تصحيح الاستعلام للبحث عن الوحدة باستخدام رقم المشروع ورقم الوحدة
      final apartmentQuery =
          await _firestore
              .collection('apartments')
              .where('projectNumber', isEqualTo: projectNumber)
              .where('unitNumber', isEqualTo: unitNumber)
              .limit(1)
              .get();

      if (apartmentQuery.docs.isEmpty) {
        // محاولة ثانية باستخدام حقل 'number' في حالة استخدامه بدلاً من 'unitNumber'
        final secondQuery =
            await _firestore
                .collection('apartments')
                .where('projectNumber', isEqualTo: projectNumber)
                .where('number', isEqualTo: unitNumber)
                .limit(1)
                .get();

        if (secondQuery.docs.isNotEmpty) {
          final apartmentDoc = secondQuery.docs.first;
          // تحديث الحقول بشكل صحيح وضمان تحديث حقل pn وإضافة حقل contractNumber
          await _firestore.collection('apartments').doc(apartmentDoc.id).update(
            {
              'status': status,
              'pn': pn,
              'contractNumber': pn, // إضافة حقل إضافي قد يكون مستخدمًا
            },
          );
          print('تم تحديث حالة الوحدة إلى $status باستخدام حقل number');
        } else {
          print(
            'لم يتم العثور على الوحدة باستخدام رقم المشروع $projectNumber ورقم الوحدة $unitNumber',
          );
        }
      } else {
        final apartmentDoc = apartmentQuery.docs.first;
        // تحديث الحقول بشكل صحيح وضمان تحديث حقل pn وإضافة حقل contractNumber
        await _firestore.collection('apartments').doc(apartmentDoc.id).update({
          'status': status,
          'pn': pn,
          'contractNumber': pn, // إضافة حقل إضافي قد يكون مستخدمًا
        });
        print('تم تحديث حالة الوحدة إلى $status باستخدام حقل unitNumber');
      }
    } catch (e) {
      print('خطأ في تحديث حالة الوحدة: $e');
    }
  }

  /// حذف العمليات المالية المرتبطة بالعقد
  Future<void> _deleteFinancialTransactions(
    String pn,
    BuildContext? context,
  ) async {
    try {
      // التحقق مما إذا كان المستخدم هو المستخدم المحدد
      final bool isSpecialUser = _isSpecialUser();
      if (pn.isEmpty) {
        print('تحذير: رقم العقد فارغ، لا يمكن حذف العمليات المالية');
        return;
      }

      // تأكد من أن رقم العقد صالح وتخزينه في متغير ثابت
      final String contractNumber = pn.trim();
      pn = contractNumber;

      print('بدء حذف العمليات المالية للعقد رقم: $pn');

      // قائمة بجميع الحقول المحتملة التي قد تحتوي على رقم العقد
      final List<String> possibleFields = [
        'pn',
        'contractNumber',
        'contractId',
        'cod',
      ];

      // جمع جميع المستندات من جميع الاستعلامات
      final Set<String> processedDocIds = {};
      final List<DocumentSnapshot> docsToDelete = [];

      // تنفيذ استعلام لكل حقل محتمل
      for (final field in possibleFields) {
        print('البحث عن العمليات المالية باستخدام حقل $field');
        final query =
            await _firestore
                .collection('financialTransactions')
                .where(field, isEqualTo: pn)
                .get();

        print(
          'تم العثور على ${query.docs.length} عملية مالية باستخدام حقل $field',
        );

        // إضافة المستندات الجديدة فقط إلى القائمة
        for (final doc in query.docs) {
          if (!processedDocIds.contains(doc.id)) {
            processedDocIds.add(doc.id);
            docsToDelete.add(doc);

            // طباعة تفاصيل العملية المالية للتشخيص
            final data = doc.data();
            print(
              '- معرف العملية: ${doc.id}, النوع: ${data['transactionType'] ?? 'غير محدد'}, المبلغ: ${data['amount'] ?? 0}',
            );
          }
        }
      }

      // البحث عن العمليات المالية التي تحتوي على رقم العقد في وصف العملية
      print('البحث عن العمليات المالية التي تحتوي على رقم العقد في الوصف');
      final descriptionQuery =
          await _firestore.collection('financialTransactions').get();

      for (final doc in descriptionQuery.docs) {
        if (!processedDocIds.contains(doc.id)) {
          final data = doc.data();
          final description = data['description'] as String? ?? '';

          // التحقق مما إذا كان الوصف يحتوي على رقم العقد
          if (description.contains(pn)) {
            processedDocIds.add(doc.id);
            docsToDelete.add(doc);
            print(
              '- تم العثور على عملية مالية في الوصف: ${doc.id}, الوصف: $description',
            );
          }
        }
      }

      // حذف جميع العمليات المالية المرتبطة بالعقد
      if (docsToDelete.isNotEmpty) {
        // استخدام مجموعات من 500 عملية كحد أقصى لكل دفعة (حد Firestore)
        final int batchSize = 500;
        int totalDeleted = 0;

        // للمستخدم المحدد، قم بحذف العمليات المالية مباشرة دون تأكيد إضافي
        if (isSpecialUser) {
          for (int i = 0; i < docsToDelete.length; i += batchSize) {
            final int end =
                (i + batchSize < docsToDelete.length)
                    ? i + batchSize
                    : docsToDelete.length;
            final batch = _firestore.batch();

            for (int j = i; j < end; j++) {
              batch.delete(docsToDelete[j].reference);
              totalDeleted++;
            }

            await batch.commit();
            print('تم تنفيذ دفعة حذف تحتوي على ${end - i} عملية مالية');
          }

          print(
            'تم حذف $totalDeleted عملية مالية مرتبطة بالعقد رقم $pn بنجاح (حذف مباشر)',
          );
        } else {
          // للمستخدمين الآخرين، استخدم الطريقة العادية
          for (int i = 0; i < docsToDelete.length; i += batchSize) {
            final int end =
                (i + batchSize < docsToDelete.length)
                    ? i + batchSize
                    : docsToDelete.length;
            final batch = _firestore.batch();

            for (int j = i; j < end; j++) {
              batch.delete(docsToDelete[j].reference);
              totalDeleted++;
            }

            await batch.commit();
            print('تم تنفيذ دفعة حذف تحتوي على ${end - i} عملية مالية');
          }

          print('تم حذف $totalDeleted عملية مالية مرتبطة بالعقد رقم $pn بنجاح');
        }
      } else {
        print('لم يتم العثور على أي عمليات مالية لحذفها للعقد رقم $pn');
      }

      // التحقق من نجاح الحذف
      for (final field in possibleFields) {
        final verifyQuery =
            await _firestore
                .collection('financialTransactions')
                .where(field, isEqualTo: pn)
                .limit(5)
                .get();

        if (verifyQuery.docs.isNotEmpty) {
          print(
            'تحذير: لا تزال هناك ${verifyQuery.docs.length} عملية مالية متبقية باستخدام حقل $field',
          );
          for (final doc in verifyQuery.docs) {
            final data = doc.data();
            print(
              '- معرف العملية المتبقية: ${doc.id}, النوع: ${data['transactionType'] ?? 'غير محدد'}, المبلغ: ${data['amount'] ?? 0}',
            );
          }
        }
      }
    } catch (e) {
      print('خطأ في حذف العمليات المالية: $e');
    }
  }

  /// تحديث حالة العقد الأصلي
  Future<void> _updateOriginalContractStatus(
    String contractNumber,
    String newStatus,
    BuildContext? context,
  ) async {
    try {
      final contractQuery =
          await _firestore
              .collection('contracts')
              .where('pn', isEqualTo: contractNumber)
              .limit(1)
              .get();

      if (contractQuery.docs.isNotEmpty) {
        final contractDoc = contractQuery.docs.first;
        await _firestore.collection('contracts').doc(contractDoc.id).update({
          'status': newStatus,
        });
      }
    } catch (e) {
      print('خطأ في تحديث حالة العقد الأصلي: $e');
    }
  }

  // عرض رسائل للمستخدم
  void _showSuccessMessage(BuildContext? context, String message) {
    // التحقق مما إذا كان المستخدم هو المستخدم المحدد
    final bool isSpecialUser = _isSpecialUser();

    if (context != null) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null && context.mounted) {
        // إذا كان المستخدم هو المستخدم المحدد، قم بعرض رسالة نجاح مباشرة
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              isSpecialUser ? "$message (تم التنفيذ مباشرة)" : message,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: EdgeInsets.all(10),
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        print('✅ $message');
      }
    } else {
      print('✅ $message');
    }
  }

  void _showErrorMessage(BuildContext? context, String message) {
    if (context != null) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null && context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: EdgeInsets.all(10),
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        print('❌ $message');
      }
    } else {
      print('❌ $message');
    }
  }
}
