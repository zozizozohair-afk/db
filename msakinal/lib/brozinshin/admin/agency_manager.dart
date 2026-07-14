import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AgencyManager {
  // Singleton pattern
  static final AgencyManager instance = AgencyManager._internal();
  factory AgencyManager() => instance;
  AgencyManager._internal();

  // دالة البحث عن الوكيل
  Future<Map<String, dynamic>?> searchAgent(String agentId) async {
    if (agentId.isEmpty) return null;

    try {
      final QuerySnapshot result =
          await FirebaseFirestore.instance
              .collection('agencies')
              .where('agentId', isEqualTo: agentId)
              .limit(1)
              .get();

      if (result.docs.isNotEmpty) {
        return result.docs.first.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      throw Exception('خطأ في البحث عن الوكيل: $e');
    }
  }

  // دالة حفظ الوكالة
  Future<void> saveAgency({
    required String agentName,
    required String agentId,
    required String agencyNumber,
    required String agencyDate,
    required String principalId,
    required String principalName,
    required String? principalPhone,
    required String contractId,
    required String agencyType,
  }) async {
    if (agentName.isEmpty ||
        agentId.isEmpty ||
        agencyNumber.isEmpty ||
        agencyDate.isEmpty ||
        principalId.isEmpty) {
      throw Exception('جميع الحقول مطلوبة');
    }

    try {
      await FirebaseFirestore.instance.collection('agencies').add({
        'agentName': agentName,
        'agentId': agentId,
        'agencyNumber': agencyNumber,
        'agencyDate': agencyDate,
        'principalId': principalId,
        'principalName': principalName,
        'principalPhone': principalPhone,
        'contractId': contractId,
        'agencyType': agencyType,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('خطأ في حفظ الوكالة: $e');
    }
  }

  // دالة جلب الوكالة الحالية للعقد
  Future<Map<String, dynamic>?> getCurrentAgency(String contractId) async {
    try {
      final QuerySnapshot result =
          await FirebaseFirestore.instance
              .collection('agencies')
              .where('contractId', isEqualTo: contractId)
              .orderBy('createdAt', descending: true)
              .limit(1)
              .get();

      if (result.docs.isNotEmpty) {
        return result.docs.first.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      throw Exception('خطأ في جلب الوكالة: $e');
    }
  }

  // دالة حفظ وكالة إعادة البيع
  Future<void> saveResaleAgency({
    required String agentName,
    required String agentId,
    required String agencyNumber,
    required String agencyDate,
    required String principalId,
    required String principalName,
    required String? principalPhone,
    required String contractId,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('agencies').add({
        'agentName': agentName,
        'agentId': agentId,
        'agencyNumber': agencyNumber,
        'agencyDate': agencyDate,
        'principalId': principalId,
        'principalName': principalName,
        'principalPhone': principalPhone,
        'contractId': contractId,
        'agencyType': 'توكيل عقد إعادة بيع',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('خطأ في حفظ وكالة إعادة البيع: $e');
    }
  }
}

// مكون واجهة المستخدم للوكالة
class AgencyForm extends StatefulWidget {
  final String contractId;
  final String principalId;
  final String principalName;
  final String? principalPhone;
  final Function(Map<String, dynamic>) onAgencySaved;

  const AgencyForm({
    super.key,
    required this.contractId,
    required this.principalId,
    required this.principalName,
    this.principalPhone,
    required this.onAgencySaved,
  });

  @override
  State<AgencyForm> createState() => _AgencyFormState();
}

class _AgencyFormState extends State<AgencyForm> {
  final _formKey = GlobalKey<FormState>();
  final _agentNameController = TextEditingController();
  final _agentIdController = TextEditingController();
  final _agencyNumberController = TextEditingController();
  final _agencyDateController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _agentNameController.dispose();
    _agentIdController.dispose();
    _agencyNumberController.dispose();
    _agencyDateController.dispose();
    super.dispose();
  }

  Future<void> _searchAgent(String agentId) async {
    try {
      setState(() => _isLoading = true);
      final agentData = await AgencyManager.instance.searchAgent(agentId);
      if (agentData != null) {
        _agentNameController.text = agentData['agentName'] ?? '';
        _agentIdController.text = agentData['agentId'] ?? '';
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAgency() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isLoading = true);

      await AgencyManager.instance.saveAgency(
        agentName: _agentNameController.text,
        agentId: _agentIdController.text,
        agencyNumber: _agencyNumberController.text,
        agencyDate: _agencyDateController.text,
        principalId: widget.principalId,
        principalName: widget.principalName,
        principalPhone: widget.principalPhone,
        contractId: widget.contractId,
        agencyType: 'توكيل عقد',
      );

      final agencyData = {
        'agentName': _agentNameController.text,
        'agentId': _agentIdController.text,
        'agencyNumber': _agencyNumberController.text,
        'agencyDate': _agencyDateController.text,
      };

      widget.onAgencySaved(agencyData);

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // ... Form fields UI
        ],
      ),
    );
  }
}
