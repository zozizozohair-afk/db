import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'agency_manager.dart';

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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('إضافة وكيل'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // عرض بيانات الموكل
              ListTile(
                title: Text('الموكل: ${widget.principalName}'),
                subtitle: Text('الهوية: ${widget.principalId}'),
              ),
              Divider(),
              // حقول بيانات الوكيل
              TextFormField(
                controller: _agentIdController,
                decoration: InputDecoration(
                  labelText: 'رقم هوية الوكيل',
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search),
                    onPressed: () async {
                      final result = await AgencyManager.instance.searchAgent(
                        _agentIdController.text,
                      );
                      if (result != null) {
                        setState(() {
                          _agentNameController.text = result['agentName'] ?? '';
                        });
                      }
                    },
                  ),
                ),
                validator: (value) => value?.isEmpty == true ? 'مطلوب' : null,
              ),
              TextFormField(
                controller: _agentNameController,
                decoration: InputDecoration(labelText: 'اسم الوكيل'),
                validator: (value) => value?.isEmpty == true ? 'مطلوب' : null,
              ),
              TextFormField(
                controller: _agencyNumberController,
                decoration: InputDecoration(labelText: 'رقم الوكالة'),
                validator: (value) => value?.isEmpty == true ? 'مطلوب' : null,
              ),
              TextFormField(
                controller: _agencyDateController,
                decoration: InputDecoration(labelText: 'تاريخ الوكالة'),
                readOnly: true,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) {
                    _agencyDateController.text = DateFormat(
                      'yyyy-MM-dd',
                    ).format(date);
                  }
                },
                validator: (value) => value?.isEmpty == true ? 'مطلوب' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final docRef =
                  FirebaseFirestore.instance.collection('agencies').doc();
              final agencyData = {
                'id': docRef.id, // إضافة معرف الوكالة
                'agentName': _agentNameController.text,
                'agencyNumber': _agencyNumberController.text,
                'agencyDate': _agencyDateController.text,
                'agentId': _agentIdController.text,
                'principalId': widget.principalId,
                'principalName': widget.principalName,
                'contractId': widget.contractId,
                'createdAt': FieldValue.serverTimestamp(),
                'usedIn': [], // قائمة العقود التي استخدمت فيها الوكالة
                'lastUsed': null,
              };

              try {
                await docRef.set(agencyData);
                widget.onAgencySaved(agencyData);

                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            }
          },
          child: Text('حفظ'),
        ),
      ],
    );
  }
}
