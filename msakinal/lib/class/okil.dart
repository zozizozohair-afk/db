import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AgencyDialog extends StatefulWidget {
  final String unitPn;
  final String usageLocation; // نص يحدد موقع الاستخدام (مثلاً: "عقد بيع")
  final String? principalId; // هوية الموكل (من العميل)
  final String? principalName;
  final String? principalPhone;

  const AgencyDialog({
    super.key,
    required this.unitPn,
    required this.usageLocation,
    this.principalId,
    this.principalName,
    this.principalPhone,
  });

  @override
  State<AgencyDialog> createState() => _AgencyDialogState();
}

class _AgencyDialogState extends State<AgencyDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _agentIdController = TextEditingController();
  final TextEditingController _agentNameController = TextEditingController();
  final TextEditingController _agentPhoneController = TextEditingController();
  final TextEditingController _agencyNumberController = TextEditingController();
  final TextEditingController _agencyDateController = TextEditingController();

  bool _isLoading = false;

  Future<void> _searchAgent() async {
    setState(() => _isLoading = true);
    final agentId = _agentIdController.text.trim();
    final snapshot =
        await FirebaseFirestore.instance
            .collection('agencies')
            .where('agentId', isEqualTo: agentId)
            .limit(1)
            .get();
    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      _agentNameController.text = data['agentName'] ?? '';
      _agentPhoneController.text = data['agentPhone'] ?? '';
      _agencyNumberController.text = data['agencyNumber'] ?? '';
      _agencyDateController.text = data['agencyDate'] ?? '';
      // يمكن جلب بيانات الموكل أيضاً إذا أردت
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('لم يتم العثور على وكيل بهذه الهوية')),
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveAgency() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final agencyData = {
      'agencyNumber': _agencyNumberController.text.trim(),
      'agencyDate': _agencyDateController.text.trim(),
      'agentId': _agentIdController.text.trim(),
      'agentName': _agentNameController.text.trim(),
      'agentPhone': _agentPhoneController.text.trim(),
      'principalId': widget.principalId ?? '',
      'principalName': widget.principalName ?? '',
      'principalPhone': widget.principalPhone ?? '',
      'unitPn': widget.unitPn,
      'usageLocation': widget.usageLocation,
      'createdAt': FieldValue.serverTimestamp(),
    };

    // حفظ في جدول الوكالات
    await FirebaseFirestore.instance.collection('agencies').add(agencyData);

    Navigator.of(context).pop({
      'agentName': _agentNameController.text.trim(),
      'agentId': _agentIdController.text.trim(),
      'agencyNumber': _agencyNumberController.text.trim(),
    });

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('إدارة الوكالة'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // بحث عن الوكيل
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _agentIdController,
                      decoration: InputDecoration(
                        labelText: 'رقم هوية الوكيل',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.search),
                    onPressed: _isLoading ? null : _searchAgent,
                  ),
                ],
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _agentNameController,
                decoration: InputDecoration(
                  labelText: 'اسم الوكيل',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _agentPhoneController,
                decoration: InputDecoration(
                  labelText: 'رقم جوال الوكيل',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _agencyNumberController,
                decoration: InputDecoration(
                  labelText: 'رقم الوكالة',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _agencyDateController,
                decoration: InputDecoration(
                  labelText: 'تاريخ الوكالة',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.datetime,
                validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
              ),
              SizedBox(height: 10),
              // بيانات الموكل (تظهر فقط للعرض)
              if (widget.principalName != null)
                Text('اسم الموكل: ${widget.principalName}'),
              if (widget.principalId != null)
                Text('هوية الموكل: ${widget.principalId}'),
              if (widget.principalPhone != null)
                Text('جوال الموكل: ${widget.principalPhone}'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveAgency,
          child:
              _isLoading
                  ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : Text('حفظ'),
        ),
      ],
    );
  }
}
