import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UnitFinancialSettlementDialog extends StatefulWidget {
  final String unitPn; // رقم الشقة (pn) من صفحة الوحدة
  const UnitFinancialSettlementDialog({super.key, required this.unitPn});

  @override
  State<UnitFinancialSettlementDialog> createState() =>
      _UnitFinancialSettlementDialogState();
}

class _UnitFinancialSettlementDialogState
    extends State<UnitFinancialSettlementDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _contractData;
  Map<String, dynamic>? _selectedCustomer;
  List<Map<String, dynamic>> _customerList = [];
  final TextEditingController _customerSearchController =
      TextEditingController();
  final TextEditingController _newPriceController = TextEditingController();
  bool _isLoading = false;
  bool _contractLoaded = false;
  bool _showCustomerList = false;
  Map<String, dynamic>? _untedata;

  @override
  void initState() {
    super.initState();
    _fetchContractByUnitPn();
  }

  Future<void> _fetchContractByUnitPn() async {
    setState(() {
      _isLoading = true;
      _contractData = null;
      _contractLoaded = false;
    });

    try {
      final query =
          await _firestore
              .collection('contracts')
              .where('pn', isEqualTo: widget.unitPn)
              .limit(1)
              .get();

      if (query.docs.isNotEmpty) {
        setState(() {
          _contractData = {
            ...query.docs.first.data(),
            'docId': query.docs.first.id,
          };
          _contractLoaded = true;
        });
        // بعد جلب العقد، اجلب بيانات الوحدة
        await fetchUnitData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('لم يتم العثور على عقد برقم الشقة هذا')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء جلب بيانات العقد: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchCustomersByIdentity(String identity) async {
    if (identity.isEmpty) {
      setState(() {
        _customerList = [];
        _showCustomerList = false;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _showCustomerList = false;
    });

    try {
      final query =
          await _firestore
              .collection('customers')
              .where('identityNumber', isGreaterThanOrEqualTo: identity)
              .where('identityNumber', isLessThanOrEqualTo: '$identity\uf8ff')
              .limit(5)
              .get();

      final results =
          query.docs.map((doc) => {...doc.data(), 'docId': doc.id}).toList();
      setState(() {
        _customerList = results;
        _showCustomerList = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء البحث عن العملاء: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _selectCustomer(Map<String, dynamic> customer) {
    setState(() {
      _selectedCustomer = customer;
      _customerSearchController.text = customer['identityNumber'] ?? '';
      _showCustomerList = false;
    });
  }

  Future<void> fetchUnitData() async {
    if (_contractData == null) return;
    final querySnapshot =
        await _firestore
            .collection('apartments')
            .where('projectNumber', isEqualTo: _contractData?['projectNumber'])
            .where('number', isEqualTo: _contractData?['unitNumber'])
            .limit(1)
            .get();

    if (querySnapshot.docs.isNotEmpty) {
      setState(() {
        _untedata = querySnapshot.docs.first.data();
        _untedata!['docId'] = querySnapshot.docs.first.id;
      });
    } else {
      _untedata = null;
    }
  }

  Future<void> _submitSettlement() async {
    if (_newPriceController.text.isEmpty ||
        _selectedCustomer == null ||
        _contractData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يرجى إكمال جميع الحقول المطلوبة')),
      );
      return;
    }

    // تأكد من وجود بيانات الوحدة
    if (_untedata == null) {
      try {
        await fetchUnitData();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر جلب بيانات الوحدة: $e')));
        return;
      }
    }

    if (_untedata == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('بيانات الوحدة غير متوفرة')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // تحقق من وجود جميع المفاتيح المطلوبة في الخرائط
      final docId = _contractData?['docId'];
      final docId1 = _selectedCustomer?['docId'];
      final docId2 = _untedata?['docId'];

      if (docId == null || docId1 == null || docId2 == null) {
        throw Exception('بعض المعرفات (docId) ناقصة');
      }

      // تحقق من وجود الحقول الداخلية
      final clientData = _contractData?['clientData'] as Map<String, dynamic>?;
      final unitData = _contractData?['unitData'] as Map<String, dynamic>?;

      if (clientData == null || unitData == null) {
        throw Exception('بيانات العميل أو بيانات الوحدة مفقودة داخل العقد');
      }

      final oldClientIdentity = clientData['identityNumber'];
      final pnWithT =
          '${_contractData?['pn']?.toString() ?? ''}t'; // الرقم مع t

      // إضافة رقم العقد مع t للعميل القديم
      if (oldClientIdentity != null) {
        final oldClientSnapshot =
            await _firestore
                .collection('customers')
                .where('identityNumber', isEqualTo: oldClientIdentity)
                .limit(1)
                .get();
        if (oldClientSnapshot.docs.isNotEmpty) {
          final oldClientDoc = oldClientSnapshot.docs.first;
          final oldClientDocId = oldClientDoc.id;
          final oldContracts =
              (oldClientDoc.data()['contractNumbers'] as List?)
                  ?.cast<String>() ??
              [];
          if (!oldContracts.contains(pnWithT)) {
            oldContracts.add(pnWithT);
            await _firestore.collection('customers').doc(oldClientDocId).update(
              {'contractNumbers': oldContracts},
            );
          }
        }
      }

      // إضافة رقم العقد مع t للعميل الجديد أيضًا
      final newContracts =
          (_selectedCustomer?['contractNumbers'] as List?)?.cast<String>() ??
          [];
      if (!newContracts.contains(pnWithT)) {
        newContracts.add(pnWithT);
        await _firestore.collection('customers').doc(docId1).update({
          'contractNumbers': newContracts,
        });
      }

      final now = DateTime.now();
      final formattedDate =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      await _firestore.collection('financialSettlements').add({
        'newContractNumber': _contractData?['pn'],
        'originalContractNumber': _contractData?['contractNumber'],
        'projectNumber': _contractData?['projectNumber'],
        'apartmentNumber': _contractData?['unitNumber'],
        'nameNow': _selectedCustomer?['name'],
        'newCustomerId': _selectedCustomer?['identityNumber'],
        'newPrice': double.parse(_newPriceController.text),
        'settlementDate': formattedDate,
        'createdAt': FieldValue.serverTimestamp(),
        'customerName': _contractData?['clientName'],
        'clientIdentityNumber': clientData['identityNumber'],
        'clientPhoneNumber': clientData['phoneNumber'],
        'deedNumber': unitData['deedNumber'],
        'regionNumber': unitData['regionNumber'],
        'unitDirection': _contractData?['direction'],
        'contractDateHijri': _contractData?['dateHijri'],
      });

      await _firestore.collection('contracts').doc(docId).update({
        'status': 'تمت إعادة البيع',
        'settlementContractNumber': _contractData?['pn'],
      });

      await _firestore.collection('customers').doc(docId1).update({
        'contractNumber': _contractData?['pn'],
        'contractNumbers': FieldValue.arrayUnion([_contractData?['pn']]),
      });

      await _firestore.collection('apartments').doc(docId2).update({
        'clientName': _selectedCustomer?['name'],
        'status': 'تحت الاجراء',
        'totalAmount': double.parse(_newPriceController.text),
        'clientIdentity': _selectedCustomer?['identityNumber'],
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تم حفظ التسوية المالية بنجاح')));
      Navigator.of(context).pop(); // إغلاق الدايالوج
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء الحفظ: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildContractInfo() {
    if (!_contractLoaded || _contractData == null) return Container();
    final clientData = _contractData?['clientData'] as Map<String, dynamic>?;
    final unitData = _contractData?['unitData'] as Map<String, dynamic>?;
    return Card(
      margin: EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'بيانات العقد الأصلي',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            Divider(),
            _infoRow(
              'رقم المشروع',
              _contractData?['projectNumber']?.toString(),
            ),
            _infoRow('تاريخ العقد', _contractData?['dateHijri']?.toString()),
            _infoRow('رقم الشقة', _contractData?['unitNumber']?.toString()),
            _infoRow('اتجاه الشقة', _contractData?['direction']?.toString()),
            _infoRow('رقم القطعة', unitData?['regionNumber']?.toString()),
            _infoRow('اسم العميل', _contractData?['clientName']?.toString()),
            _infoRow('هوية العميل', clientData?['identityNumber']?.toString()),
            _infoRow('رقم جوال العميل', clientData?['phoneNumber']?.toString()),
            _infoRow('رقم الصك', unitData?['deedNumber']?.toString()),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value ?? 'غير متوفر')),
        ],
      ),
    );
  }

  Widget _buildCustomerSearchField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'بحث عن العميل الجديد',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        TextField(
          controller: _customerSearchController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'رقم هوية العميل',
            border: OutlineInputBorder(),
          ),
          onChanged: (val) {
            _searchCustomersByIdentity(val);
          },
        ),
        if (_showCustomerList && _customerList.isNotEmpty)
          Container(
            constraints: BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _customerList.length,
              itemBuilder: (context, idx) {
                final customer = _customerList[idx];
                return ListTile(
                  title: Text('${customer['name'] ?? ''}'),
                  subtitle: Text('هوية: ${customer['identityNumber'] ?? ''}'),
                  onTap: () => _selectCustomer(customer),
                );
              },
            ),
          ),
        if (_selectedCustomer != null)
          Card(
            margin: EdgeInsets.only(top: 8),
            color: Colors.green[50],
            child: ListTile(
              title: Text('${_selectedCustomer?['name']}'),
              subtitle: Text('هوية: ${_selectedCustomer?['identityNumber']}'),
              trailing: Icon(Icons.check_circle, color: Colors.green),
              onTap: () {
                setState(() {
                  _selectedCustomer = null;
                  _customerSearchController.clear();
                });
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.all(16),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: SizedBox(
          width: 380,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'تسوية مالية للوحدة',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'رقم الشقة (PN): ${widget.unitPn}',
                style: TextStyle(color: Colors.blue),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _buildContractInfo(),
              SizedBox(height: 12),
              _buildCustomerSearchField(),
              SizedBox(height: 12),
              TextField(
                controller: _newPriceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'السعر الجديد',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitSettlement,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('حفظ التسوية المالية'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
