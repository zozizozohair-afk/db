import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:msakinal/astlam.dart';
import 'package:msakinal/priovider/auth_provider.dart';
import 'package:provider/provider.dart';

import 'class/contract_service.dart';
import 'class/crit_tasoiah.dart';
import 'class/resale_contract_service.dart';

class ApartmentsListPage extends StatefulWidget {
  final String? projectNumber;
  @override
  const ApartmentsListPage({super.key, this.projectNumber});
  @override
  _ApartmentsListPageState createState() => _ApartmentsListPageState();
}

// دالة لعرض نموذج إنشاء عقد إعادة بيع
void showResaleContractDialog({
  required BuildContext context,
  required String projectNumber,
  required String unitNumber,
  required String direction,
}) {
  final formKey = GlobalKey<FormState>();
  final secondPartyController = TextEditingController();
  final identityNumberController = TextEditingController();
  final phoneController = TextEditingController();
  final totalAmountController = TextEditingController();
  final paidAmountController = TextEditingController();
  final resaleFeeController = TextEditingController(text: '0');
  final marketingFeeController = TextEditingController(text: '0');
  final companyFeeController = TextEditingController(text: '0');
  final lawyerFeeController = TextEditingController(text: '0');
  final notesController = TextEditingController();

  final now = DateTime.now();
  final formattedDate =
      '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

  Map<String, dynamic> originalContract = {};
  Map<String, dynamic>? unitData;
  Map<String, dynamic>? customerData;
  bool isLoading = false;
  String pnValue = '';

  Future<void> loadOriginalContractAndCustomer() async {
    try {
      final unitQuery =
          await FirebaseFirestore.instance
              .collection('apartments')
              .where('projectNumber', isEqualTo: projectNumber)
              .where('number', isEqualTo: unitNumber)
              .limit(1)
              .get();

      if (unitQuery.docs.isEmpty) return;

      final unitDoc = unitQuery.docs.first;
      unitData = {...unitDoc.data(), 'docId': unitDoc.id};

      pnValue = unitData!['pn'] ?? '$projectNumber-$unitNumber';

      final futures = [
        FirebaseFirestore.instance
            .collection('contracts')
            .where('pn', isEqualTo: pnValue)
            .limit(1)
            .get(),
        FirebaseFirestore.instance
            .collection('customers')
            .where('contractNumbers', arrayContains: pnValue)
            .limit(1)
            .get(),
      ];

      final results = await Future.wait(futures);
      final contractQuery = results[0];
      final customerQuery = results[1];

      if (contractQuery.docs.isNotEmpty) {
        final doc = contractQuery.docs.first;
        originalContract = Map<String, dynamic>.from(doc.data());
        originalContract['docId'] = doc.id;

        if (originalContract.containsKey('totalAmount')) {
          totalAmountController.text =
              originalContract['totalAmount'].toString();
        }
        if (originalContract.containsKey('paidAmount')) {
          paidAmountController.text = originalContract['paidAmount'].toString();
        }
      }

      if (customerQuery.docs.isNotEmpty) {
        final customerDoc = customerQuery.docs.first;
        customerData = {...customerDoc.data(), 'docId': customerDoc.id};

        secondPartyController.text = customerData!['name'] ?? '';
        identityNumberController.text = customerData!['identityNumber'] ?? '';
        phoneController.text = customerData!['phone'] ?? '';
      }
    } catch (e) {
      print('خطأ في جلب البيانات: $e');
      throw Exception('فشل في تحميل البيانات: $e');
    }
  }

  Future<void> updateUnitAndCustomer() async {
    try {
      if (unitData == null || !unitData!.containsKey('docId')) {
        throw Exception('لم يتم العثور على بيانات الوحدة');
      }

      double totalAmount = double.parse(totalAmountController.text);
      if (totalAmount <= 0) {
        throw Exception('المبلغ الإجمالي يجب أن يكون أكبر من صفر');
      }

      await FirebaseFirestore.instance
          .collection('apartments')
          .doc(unitData!['docId'])
          .update({
            'status': 'معروضة للبيع',
            'totalAmount': totalAmount,
            'resaleContractDate': FieldValue.serverTimestamp(),
          });

      if (customerData != null && customerData!.containsKey('docId')) {
        await FirebaseFirestore.instance
            .collection('customers')
            .doc(customerData!['docId'])
            .update({'contractNumber': '${pnValue}a'});
      }
    } catch (e) {
      print('خطأ في تحديث البيانات: $e');
      throw Exception('فشل في تحديث بيانات الوحدة أو العميل: $e');
    }
  }

  showDialog(
    context: context,
    builder:
        (context) => StatefulBuilder(
          builder: (context, setState) {
            if (!isLoading && originalContract.isEmpty) {
              isLoading = true;
              setState(() {});
              loadOriginalContractAndCustomer()
                  .then((_) {
                    if (context.mounted) {
                      setState(() {
                        isLoading = false;
                      });
                    }
                  })
                  .catchError((error) {
                    if (context.mounted) {
                      setState(() {
                        isLoading = false;
                      });
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('خطأ: $error')));
                    }
                  });
            }

            return AlertDialog(
              title: Text('إنشاء عقد إعادة بيع', textAlign: TextAlign.center),
              content:
                  isLoading
                      ? SizedBox(
                        height: 120,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              'جاري تحميل البيانات...',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'يرجى الانتظار قليلاً',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                      : SingleChildScrollView(
                        child: Form(
                          key: formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextFormField(
                                controller: secondPartyController,
                                decoration: InputDecoration(
                                  labelText: 'اسم المشتري الجديد',
                                  border: OutlineInputBorder(),
                                ),
                                validator:
                                    (value) =>
                                        value!.isEmpty
                                            ? 'يرجى إدخال الاسم'
                                            : null,
                              ),
                              SizedBox(height: 8),
                              TextFormField(
                                controller: identityNumberController,
                                decoration: InputDecoration(
                                  labelText: 'رقم الهوية',
                                  border: OutlineInputBorder(),
                                ),
                                validator:
                                    (value) =>
                                        value!.isEmpty
                                            ? 'يرجى إدخال رقم الهوية'
                                            : null,
                              ),
                              SizedBox(height: 8),
                              TextFormField(
                                controller: phoneController,
                                decoration: InputDecoration(
                                  labelText: 'رقم الهاتف',
                                  border: OutlineInputBorder(),
                                ),
                                validator:
                                    (value) =>
                                        value!.isEmpty
                                            ? 'يرجى إدخال رقم الهاتف'
                                            : null,
                              ),
                              SizedBox(height: 8),
                              TextFormField(
                                controller: totalAmountController,
                                decoration: InputDecoration(
                                  labelText: 'المبلغ المتفق عليه ',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                              SizedBox(height: 8),
                              SizedBox(height: 8),
                              TextFormField(
                                controller: resaleFeeController,
                                decoration: InputDecoration(
                                  labelText: 'رسوم إعادة البيع',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                              SizedBox(height: 8),
                              TextFormField(
                                controller: marketingFeeController,
                                decoration: InputDecoration(
                                  labelText: 'رسوم التسويق',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                              SizedBox(height: 8),
                              TextFormField(
                                controller: companyFeeController,
                                decoration: InputDecoration(
                                  labelText: 'رسوم الشركة',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                              SizedBox(height: 8),
                              TextFormField(
                                controller: lawyerFeeController,
                                decoration: InputDecoration(
                                  labelText: 'رسوم المحامي',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                              SizedBox(height: 8),
                              TextFormField(
                                controller: notesController,
                                decoration: InputDecoration(
                                  labelText: 'ملاحظات',
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 3,
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
                  onPressed:
                      isLoading
                          ? null
                          : () async {
                            if (formKey.currentState!.validate()) {
                              setState(() => isLoading = true);

                              try {
                                await updateUnitAndCustomer();

                                // أولاً: تعديل حالة الوحدة إلى "معروضة للبيع"
                                final apartmentQuery =
                                    await FirebaseFirestore.instance
                                        .collection('apartments')
                                        .where('pn', isEqualTo: pnValue)
                                        .limit(1)
                                        .get();

                                if (apartmentQuery.docs.isNotEmpty) {
                                  await apartmentQuery.docs.first.reference
                                      .update({'status': 'معروضة للبيع'});
                                }

                                // ثانياً: تعديل حالة العقد الأصلي إلى "تحت الإنشاء"
                                if (originalContract.isNotEmpty &&
                                    originalContract['pn'] != null) {
                                  final originalContractQuery =
                                      await FirebaseFirestore.instance
                                          .collection('contracts')
                                          .where(
                                            'pn',
                                            isEqualTo: originalContract['pn'],
                                          )
                                          .limit(1)
                                          .get();

                                  if (originalContractQuery.docs.isNotEmpty) {
                                    await originalContractQuery
                                        .docs
                                        .first
                                        .reference
                                        .update({'status': 'تحت الإنشاء'});
                                  }
                                }

                                // إنشاء بيانات العقد الجديد
                                final contractData = {
                                  'projectNumber': projectNumber,
                                  'unitNumber': unitNumber,
                                  'direction': direction,
                                  'secondParty': secondPartyController.text,
                                  'identityNumber':
                                      identityNumberController.text,
                                  'phone': phoneController.text,
                                  'secondPartyAmount':
                                      double.tryParse(
                                        totalAmountController.text,
                                      ) ??
                                      0,
                                  'resaleFee':
                                      double.tryParse(
                                        resaleFeeController.text,
                                      ) ??
                                      0,
                                  'marketingFee':
                                      double.tryParse(
                                        marketingFeeController.text,
                                      ) ??
                                      0,
                                  'companyFee':
                                      double.tryParse(
                                        companyFeeController.text,
                                      ) ??
                                      0,
                                  'lawyerFee':
                                      double.tryParse(
                                        lawyerFeeController.text,
                                      ) ??
                                      0,
                                  'notes': notesController.text,
                                  'contractDate': formattedDate,
                                  'createdAt': FieldValue.serverTimestamp(),
                                  'pn': pnValue,
                                };

                                if (originalContract.isNotEmpty) {
                                  contractData['originalContractId'] =
                                      originalContract['docId'];
                                  contractData['originalContractNumber'] =
                                      pnValue;
                                }

                                final Map<String, dynamic> finalContractData =
                                    Map<String, dynamic>.from(contractData);

                                final resaleService = ResaleContractService();
                                await resaleService.addResaleContract(
                                  finalContractData,
                                );

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'تم إنشاء عقد إعادة البيع بنجاح',
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  setState(() => isLoading = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('حدث خطأ: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          },
                  child: Text('إنشاء العقد'),
                ),
              ],
            );
          },
        ),
  );
}

class _ApartmentsListPageState extends State<ApartmentsListPage> {
  String _calculateRemainingDays(String contractDate) {
    if (contractDate.isEmpty) return "غير محدد";

    try {
      final dateParts = contractDate.split('/');
      if (dateParts.length != 3) return "تاريخ غير صحيح";

      final day = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final year = int.parse(dateParts[2]);

      final deliveryDateTime = DateTime(year + 1, month, day); // إضافة 12 شهر
      final today = DateTime.now();

      if (today.isAfter(deliveryDateTime)) {
        return "تم تجاوز الموعد";
      }

      final difference = deliveryDateTime.difference(today).inDays;
      return "$difference يوم متبقي";
    } catch (e) {
      return "خطأ في الحساب";
    }
  }

  final TextEditingController searchController = TextEditingController();
  String searchProjectNumber = '';
  String? initialProjectNumber;
  bool _isPressed = false;
  String selectedStatusFilter = 'الكل';
  bool showDeleteProjectButton = false;

  Color _getCardColor(String status) {
    switch (status) {
      case 'مباع':
        return Colors.red[700]!;
      case 'محجوز':
        return Colors.amber[800]!;
      case 'معروضة للبيع':
        return Colors.purple[800]!;
      case 'تم الإفراغ':
        return Colors.blue[800]!;
      case 'متاح':
        return Colors.green;
      case 'تحت الاجراء':
        return Colors.grey.shade600;
      default:
        return Colors.green[900]!;
    }
  }

  @override
  void initState() {
    super.initState();
    initialProjectNumber = widget.projectNumber; // استقبل القيمة من Widget
    searchController.text =
        initialProjectNumber ?? ''; // املأ حقل البحث إذا كان هناك قيمة
    searchProjectNumber = initialProjectNumber ?? ''; // حدد قيمة البحث الأولية
  }

  @override
  Widget build(BuildContext context) {
    final userty =
        Provider.of<AppAuthProvider>(context, listen: false).userType;
    return Scaffold(
      appBar: AppBar(
        title: Text('قائمة الشقق'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_forever),
            tooltip: 'حذف الكل',
            onPressed: () {
              if (userty == 'مستر') {
                //  _confirmDeleteAll();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم تقيد عمليه الحذف حتى اشعار اخر'),
                    backgroundColor: Colors.red,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'انت على وشك ارتكاب جريمه كبرى بس معلش زهير مايسمح لك',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: 'بحث برقم المشروع',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          searchController.clear();
                          searchProjectNumber = '';
                          showDeleteProjectButton = false;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onSubmitted: (_) {
                    setState(() {
                      searchProjectNumber = searchController.text.trim();
                      showDeleteProjectButton = searchProjectNumber.isNotEmpty;
                    });
                  },
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedStatusFilter,
                        decoration: InputDecoration(
                          labelText: 'فلترة حسب الحالة',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items:
                            [
                              'الكل',
                              'متاح',
                              'محجوز',
                              'مباع',
                              'معروضة للبيع',
                              'تم الإفراغ',
                              'تحت الاجراء',
                            ].map((status) {
                              return DropdownMenuItem(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedStatusFilter = value!;
                          });
                        },
                      ),
                    ),
                    if (showDeleteProjectButton && userty == 'مستر') ...[
                      SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _deleteProject(),
                        icon: Icon(Icons.delete_forever, color: Colors.white),
                        label: Text(
                          'حذف المشروع',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  (searchProjectNumber.isNotEmpty
                      ? FirebaseFirestore.instance
                          .collection('apartments')
                          .where(
                            'projectNumber',
                            isEqualTo: searchProjectNumber,
                          )
                          .snapshots()
                      : FirebaseFirestore.instance
                          .collection('apartments')
                          .snapshots()),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('حدث خطأ في جلب البيانات'));
                }

                if (snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('لا توجد بيانات لعرضها'));
                }

                var apartments = snapshot.data!.docs;

                // تطبيق فلترة الحالة
                if (selectedStatusFilter != 'الكل') {
                  apartments =
                      apartments.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return data['status'] == selectedStatusFilter;
                      }).toList();
                }

                apartments.sort(
                  (a, b) => _compareNumbers(
                    (a.data() as Map)['number'],
                    (b.data() as Map)['number'],
                  ),
                );

                return AnimatedSwitcher(
                  duration: Duration(milliseconds: 300),
                  child: GridView.builder(
                    key: ValueKey<String>(searchProjectNumber),
                    padding: const EdgeInsets.all(12),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _getCrossAxisCount(context),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio:
                          MediaQuery.of(context).size.width > 600 ? 0.7 : 0.9,
                    ),
                    itemCount: apartments.length,
                    itemBuilder: (context, index) {
                      final apartment = apartments[index];
                      final data = apartment.data() as Map<String, dynamic>;
                      final status = data['status'] ?? 'متاح';
                      final clientRef = data['clientName'];
                      final dateforafrak = data['dateStringafragh'];
                      final paid = data['tot']?.toDouble() ?? 0;
                      final total = data['totalAmount']?.toDouble() ?? 1;
                      final progress = paid / total;

                      return AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: Card(
                          color: Colors.white,
                          elevation: 4,
                          shadowColor: _getCardColor(status).withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: _getCardColor(status),
                              width: 2.5,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // معلومات الشقة
                                  Hero(
                                    tag: 'apartment-${data['number']}',
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'شقة رقم: ${_formatNumber(data['number'])}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20,
                                                color: _getCardColor(status),
                                                shadows: [
                                                  Shadow(
                                                    blurRadius: 2,
                                                    color: Colors.black
                                                        .withOpacity(0.2),
                                                    offset: Offset(1, 1),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              'دور: ${_formatNumber(data['floor'])}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20,
                                                color: Colors.black,
                                                shadows: [
                                                  Shadow(
                                                    blurRadius: 2,
                                                    color: Colors.black
                                                        .withOpacity(0.2),
                                                    offset: Offset(1, 1),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 8),
                                        Container(
                                          width: double.infinity,
                                          padding: EdgeInsets.symmetric(
                                            vertical: 6,
                                            horizontal: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.blue.shade200,
                                            ),
                                          ),
                                          child: Text(
                                            'مشروع رقم: ${data['projectNumber'] ?? 'غير محدد'}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                              color: Colors.blue.shade800,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  _buildInfoRow(
                                    Icons.apartment,
                                    'المشروع: ${data['projectNumber'] ?? 'غير معروف'}',
                                    18,
                                    Colors.black87,
                                  ),
                                  _buildInfoRow(
                                    Icons.explore,
                                    'الاتجاه: ${data['direction'] ?? 'غير محدد'}',
                                    16,
                                    _getCardColor(status),
                                  ),
                                  _buildInfoRow(
                                    Icons.description,
                                    'الوصف: ${data['description'] ?? 'لا يوجد'}',
                                    14,
                                    _getCardColor(status),
                                  ),
                                  _buildInfoRow(
                                    Icons.article,
                                    'رقم الصك: ${data['deedNumber'] ?? 'لا يوجد'}',
                                    16,
                                    _getCardColor(status),
                                  ),
                                  _buildInfoRow(
                                    Icons.person,
                                    'العميل: ${clientRef?.isNotEmpty == true ? clientRef : 'غير مرتبط بعميل'}',
                                    14,
                                    Colors.black87,
                                  ),
                                  _buildInfoRow(
                                    Icons.calendar_today,
                                    'تاريخ الافراغ: ${dateforafrak?.isNotEmpty == true ? dateforafrak : 'لم يتم الافراغ الى الان'}',
                                    14,
                                    Colors.black87,
                                  ),
                                  SizedBox(height: 12),
                                  // شريط الحالة
                                  SizedBox(
                                    width: double.infinity,
                                    child: AnimatedContainer(
                                      duration: Duration(milliseconds: 300),
                                      padding: EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getCardColor(
                                          status,
                                        ).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _getCardColor(
                                            status,
                                          ).withOpacity(0.5),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.circle,
                                            size: 12,
                                            color: _getCardColor(status),
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'الحالة: $status',
                                            style: TextStyle(
                                              color: Colors.black87,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  if (status == 'مباع' &&
                                      data['تاريخ العقد تحت الانشاء'] != null)
                                    Container(
                                      margin: EdgeInsets.only(top: 8),
                                      padding: EdgeInsets.symmetric(
                                        vertical: 6,
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[800]!.withOpacity(
                                          0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.orange[800]!,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.timer,
                                            size: 16,
                                            color: Colors.orange[800],
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'موعد التسليم: ${_calculateRemainingDays(data['تاريخ العقد تحت الانشاء'])}',
                                            style: TextStyle(
                                              color: Colors.orange[800],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  //dateforafrak
                                  // تصميم جديد لشريط السداد مع أيقونات
                                  SizedBox(height: 12),
                                  if (status == 'متاح')
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        AnimatedContainer(
                                          duration: Duration(milliseconds: 200),
                                          curve: Curves.easeInOut,
                                          transform:
                                              Matrix4.identity()..scale(
                                                _isPressed ? 0.95 : 1.0,
                                              ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.blueAccent,
                                                Colors.lightBlue,
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.blue.withOpacity(
                                                  0.3,
                                                ),
                                                blurRadius: 10,
                                                offset: Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              onTap: () {
                                                showSmartAddContractDialog(
                                                  context: context,
                                                  projectNumber:
                                                      '${data['projectNumber']}',
                                                  unitNumber:
                                                      '${data['number']}',
                                                  direction:
                                                      '${data['direction']}',
                                                );
                                              },
                                              onTapDown:
                                                  (_) => setState(
                                                    () => _isPressed = true,
                                                  ),
                                              onTapCancel:
                                                  () => setState(
                                                    () => _isPressed = false,
                                                  ),
                                              onTapUp:
                                                  (_) => setState(
                                                    () => _isPressed = false,
                                                  ),
                                              child: Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 12,
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.attach_money,
                                                      color: Colors.white,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      'بيع الشقة',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        AnimatedContainer(
                                          duration: Duration(milliseconds: 180),
                                          curve: Curves.easeInOut,
                                          transform:
                                              Matrix4.identity()..scale(
                                                _isPressed ? 0.95 : 1.0,
                                              ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                const Color.fromARGB(
                                                  255,
                                                  143,
                                                  68,
                                                  255,
                                                ),
                                                const Color.fromARGB(
                                                  255,
                                                  244,
                                                  3,
                                                  3,
                                                ),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color.fromARGB(
                                                  255,
                                                  79,
                                                  3,
                                                  114,
                                                ).withOpacity(0.3),
                                                blurRadius: 10,
                                                offset: Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder:
                                                        (context) => Aistlam(
                                                          unitPn:
                                                              data['pn'] ?? '',

                                                          // هنا يمكنك تمرير أي متغيرات تحتاجها
                                                        ),
                                                  ),
                                                );
                                              },
                                              onTapDown:
                                                  (_) => setState(
                                                    () => _isPressed = true,
                                                  ),
                                              onTapCancel:
                                                  () => setState(
                                                    () => _isPressed = false,
                                                  ),
                                              onTapUp:
                                                  (_) => setState(
                                                    () => _isPressed = false,
                                                  ),
                                              child: Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 12,
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.arrow_back,
                                                      color: Colors.white,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      'افراغ ',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  // أضف هذا في أي مكان في واجهتك UI
                                  SizedBox(height: 8),

                                  // عرض البيانات المالية من جدول العمليات المالية
                                  FutureBuilder<Map<String, double>>(
                                    future: _getFinancialSummary(data['pn']),
                                    builder: (context, snapshot) {
                                      final financialData =
                                          snapshot.data ??
                                          {'total': 0, 'paid': 0};
                                      final financialTotal =
                                          financialData['total']!;
                                      final financialPaid =
                                          financialData['paid']!;
                                      final financialProgress =
                                          financialTotal > 0
                                              ? financialPaid / financialTotal
                                              : 0.0;

                                      return Column(
                                        children: [
                                          // شريط التقدم المالي
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.payments,
                                                size: 18,
                                                color: Colors.green,
                                              ),
                                              SizedBox(width: 4),
                                              Expanded(
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(3),
                                                  child: Container(
                                                    height: 8,
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey[150],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                      border: Border.all(
                                                        color:
                                                            Colors.grey[350]!,
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: LinearProgressIndicator(
                                                      value: financialProgress,
                                                      minHeight: 8,
                                                      backgroundColor:
                                                          Colors.transparent,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                            Color
                                                          >(
                                                            _getCardColor(
                                                              status,
                                                            ),
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 4),
                                              Icon(
                                                Icons.attach_money,
                                                size: 18,
                                                color: Colors.greenAccent,
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 4),
                                          // عرض المبالغ المالية من جدول العمليات
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.arrow_circle_down,
                                                    size: 14,
                                                    color: Colors.green[300],
                                                  ),
                                                  SizedBox(width: 2),
                                                  Text(
                                                    'مدفوع: ${financialPaid.toStringAsFixed(2)} ر.س',
                                                    style: TextStyle(
                                                      color: Colors.black87,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.arrow_circle_up,
                                                    size: 14,
                                                    color: Colors.orange[300],
                                                  ),
                                                  SizedBox(width: 2),
                                                  Text(
                                                    'إجمالي: ${financialTotal.toStringAsFixed(2)} ر.س',
                                                    style: TextStyle(
                                                      color: Colors.black87,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting)
                                            Padding(
                                              padding: EdgeInsets.only(top: 4),
                                              child: SizedBox(
                                                height: 12,
                                                width: 12,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(_getCardColor(status)),
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),

                                  // زر الإجراءات البسيط
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      // زر حجز الشقة - يظهر فقط إذا كانت الحالة "متاح"
                                      if (status == 'متاح')
                                        GestureDetector(
                                          onTap: () {
                                            _showReservationDialog(
                                              context,
                                              apartment.id,
                                              data,
                                            );
                                          },
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.green.shade600,
                                                  Colors.green.shade800,
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.green
                                                      .withOpacity(0.3),
                                                  blurRadius: 5,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.bookmark_add,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'حجز شقة',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                      // زر بيع مشروط - يظهر فقط إذا كانت الحالة "محجوز"
                                      if (status == 'محجوز')
                                        GestureDetector(
                                          onTap: () {
                                            _showConditionalSaleDialog(
                                              context,
                                              data,
                                            );
                                          },
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.purple.shade600,
                                                  Colors.purple.shade800,
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.purple
                                                      .withOpacity(0.3),
                                                  blurRadius: 5,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.sell,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'بيع للحاجز',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                      // زر إعادة البيع - يظهر فقط إذا كانت الحالة "مباع"
                                      if (status == 'مباع')
                                        GestureDetector(
                                          onTap: () {
                                            showResaleContractDialog(
                                              context: context,
                                              projectNumber:
                                                  data['projectNumber'] ?? '',
                                              unitNumber:
                                                  data['number'].toString(),
                                              direction:
                                                  data['direction'] ?? '',
                                            );
                                          },
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.orange.shade700,
                                                  Colors.deepOrange.shade800,
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.orange
                                                      .withOpacity(0.3),
                                                  blurRadius: 5,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.autorenew,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'إعادة بيع',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                      if (status == 'معروضة للبيع')
                                        GestureDetector(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder:
                                                  (_) =>
                                                      UnitFinancialSettlementDialog(
                                                        unitPn: data['pn'],
                                                      ),
                                            );
                                          },
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.purple.shade700,
                                                  Colors.blue.shade800,
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.orange
                                                      .withOpacity(0.3),
                                                  blurRadius: 5,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.monetization_on,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'تسويه ماليه',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                      // زر إلغاء الحجز - يظهر فقط إذا كانت الحالة "محجوز"
                                      if (status == 'محجوز')
                                        GestureDetector(
                                          onTap: () {
                                            _showCancelReservationDialog(
                                              context,
                                              apartment.id,
                                              data,
                                            );
                                          },
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.red.shade600,
                                                  Colors.red.shade800,
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.red.withOpacity(
                                                    0.3,
                                                  ),
                                                  blurRadius: 5,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.cancel,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'إلغاء الحجز',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                      // زر الإجراءات
                                      GestureDetector(
                                        onTap: () {
                                          // هنا يمكنك وضع الإجراء الذي تريده عند الضغط على الأيقونة
                                          _showActionDialog(
                                            context,
                                            apartment.id,
                                            data,
                                          );
                                        },
                                        child: Container(
                                          padding: EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: _getCardColor(
                                              status,
                                            ).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.touch_app,
                                            color: _getCardColor(status),
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddApartmentDialog(context),
        child: Icon(Icons.add),
        tooltip: 'إضافة وحدة جديدة',
        backgroundColor: Colors.blue,
      ),
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 4;
    if (width > 800) return 3;
    if (width > 500) return 2;
    return 1;
  }

  // دالة إضافة وحدة جديدة
  void _showAddApartmentDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final projectNumberController = TextEditingController();
    final apartmentNumberController = TextEditingController();
    final descriptionController = TextEditingController();
    final areaController = TextEditingController();
    final floorController = TextEditingController();

    String? selectedDirection;
    String selectedStatus = 'متاح';
    List<String> availableDirections = [];
    Map<String, dynamic>? similarApartmentData;
    bool isLoadingDirections = false;
    bool isLoadingSimilarData = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.add_home, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('إضافة وحدة جديدة'),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // حقل رقم المشروع
                        TextFormField(
                          controller: projectNumberController,
                          decoration: InputDecoration(
                            labelText: 'رقم المشروع *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.business),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى إدخال رقم المشروع';
                            }
                            return null;
                          },
                          onChanged: (value) async {
                            if (value.isNotEmpty) {
                              setState(() {
                                isLoadingDirections = true;
                                availableDirections.clear();
                                selectedDirection = null;
                                similarApartmentData = null;
                              });

                              // جلب الاتجاهات المتاحة للمشروع
                              try {
                                // جلب الاتجاهات من الشقق الموجودة - البحث بكلا النوعين String و int
                                final querySnapshot1 =
                                    await FirebaseFirestore.instance
                                        .collection('apartments')
                                        .where(
                                          'projectNumber',
                                          isEqualTo: value,
                                        )
                                        .get();

                                final querySnapshot2 =
                                    await FirebaseFirestore.instance
                                        .collection('apartments')
                                        .where(
                                          'projectNumber',
                                          isEqualTo: int.tryParse(value) ?? 0,
                                        )
                                        .get();

                                // استخدام النتيجة التي تحتوي على بيانات أكثر
                                final querySnapshot =
                                    querySnapshot1.docs.length >=
                                            querySnapshot2.docs.length
                                        ? querySnapshot1
                                        : querySnapshot2;

                                Set<String> directions = {};
                                for (var doc in querySnapshot.docs) {
                                  final direction = doc.data()['direction'];
                                  if (direction != null &&
                                      direction.toString().isNotEmpty) {
                                    directions.add(direction.toString());
                                  }
                                }

                                setState(() {
                                  availableDirections =
                                      directions.toList()..sort();
                                  isLoadingDirections = false;
                                });
                              } catch (e) {
                                setState(() {
                                  isLoadingDirections = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('خطأ في جلب الاتجاهات: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        SizedBox(height: 16),

                        // قائمة الاتجاهات
                        if (isLoadingDirections)
                          Container(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircularProgressIndicator(strokeWidth: 2),
                                SizedBox(width: 12),
                                Text('جاري جلب الاتجاهات...'),
                              ],
                            ),
                          )
                        else if (availableDirections.isNotEmpty)
                          DropdownButtonFormField<String>(
                            value: selectedDirection,
                            decoration: InputDecoration(
                              labelText: 'الاتجاه *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.explore),
                            ),
                            items:
                                availableDirections.map((direction) {
                                  return DropdownMenuItem(
                                    value: direction,
                                    child: Text(direction),
                                  );
                                }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedDirection = value;
                                similarApartmentData = null;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'يرجى اختيار الاتجاه';
                              }
                              return null;
                            },
                          )
                        else if (projectNumberController.text.isNotEmpty)
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              border: Border.all(color: Colors.orange.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info, color: Colors.orange),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'لا توجد اتجاهات متاحة لهذا المشروع',
                                    style: TextStyle(
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        SizedBox(height: 16),

                        // حقل رقم الشقة
                        TextFormField(
                          controller: apartmentNumberController,
                          decoration: InputDecoration(
                            labelText: 'رقم الشقة *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.home),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى إدخال رقم الشقة';
                            }
                            return null;
                          },
                          onChanged: (value) async {
                            if (value.isNotEmpty &&
                                projectNumberController.text.isNotEmpty &&
                                selectedDirection != null) {
                              setState(() {
                                isLoadingSimilarData = true;
                                similarApartmentData = null;
                              });

                              try {
                                // التحقق من وجود شقة بنفس الرقم والمشروع
                                final existingQuery =
                                    await FirebaseFirestore.instance
                                        .collection('apartments')
                                        .where(
                                          'projectNumber',
                                          isEqualTo:
                                              projectNumberController.text,
                                        )
                                        .where('number', isEqualTo: value)
                                        .get();

                                if (existingQuery.docs.isNotEmpty) {
                                  setState(() {
                                    isLoadingSimilarData = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'يوجد شقة بنفس الرقم في هذا المشروع',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                // جلب بيانات شقة مشابهة بنفس الاتجاه والمشروع
                                final similarQuery =
                                    await FirebaseFirestore.instance
                                        .collection('apartments')
                                        .where(
                                          'projectNumber',
                                          isEqualTo:
                                              projectNumberController.text,
                                        )
                                        .where(
                                          'direction',
                                          isEqualTo: selectedDirection,
                                        )
                                        .limit(1)
                                        .get();

                                if (similarQuery.docs.isNotEmpty) {
                                  final data = similarQuery.docs.first.data();
                                  setState(() {
                                    similarApartmentData = data;
                                    // ملء الحقول بالبيانات المشابهة
                                    descriptionController.text =
                                        data['description'] ?? '';
                                    areaController.text = data['area'] ?? '';
                                    isLoadingSimilarData = false;
                                  });
                                } else {
                                  setState(() {
                                    isLoadingSimilarData = false;
                                  });
                                }
                              } catch (e) {
                                setState(() {
                                  isLoadingSimilarData = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('خطأ في جلب البيانات: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                        ),

                        SizedBox(height: 16),

                        // عرض حالة جلب البيانات المشابهة
                        if (isLoadingSimilarData)
                          Container(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircularProgressIndicator(strokeWidth: 2),
                                SizedBox(width: 12),
                                Text('جاري جلب البيانات المشابهة...'),
                              ],
                            ),
                          ),

                        // عرض البيانات المشابهة إذا وجدت
                        if (similarApartmentData != null)
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              border: Border.all(color: Colors.green.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.info, color: Colors.green),
                                    SizedBox(width: 8),
                                    Text(
                                      'تم جلب البيانات من شقة مشابهة:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'رقم الصك: ${similarApartmentData!['deedNumber'] ?? 'غير محدد'}',
                                ),
                                Text(
                                  'تاريخ الصك: ${similarApartmentData!['deedDate'] ?? 'غير محدد'}',
                                ),
                                Text(
                                  'رقم المخطط: ${similarApartmentData!['planNumber'] ?? 'غير محدد'}',
                                ),
                                Text(
                                  'رقم القطعة: ${similarApartmentData!['regionNumber'] ?? 'غير محدد'}',
                                ),
                                Text(
                                  'الصف: ${similarApartmentData!['floor'] ?? 'غير محدد'}',
                                ),
                              ],
                            ),
                          ),

                        SizedBox(height: 16),

                        // حقل الوصف (قابل للتعديل)
                        TextFormField(
                          controller: descriptionController,
                          decoration: InputDecoration(
                            labelText: 'الوصف',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.description),
                          ),
                          maxLines: 3,
                        ),

                        SizedBox(height: 16),

                        // حقل المساحة (قابل للتعديل)
                        TextFormField(
                          controller: areaController,
                          decoration: InputDecoration(
                            labelText: 'المساحة',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.square_foot),
                          ),
                          keyboardType: TextInputType.number,
                        ),

                        SizedBox(height: 16),

                        // حقل الطابق (قابل للإدخال اليدوي)
                        TextFormField(
                          controller: floorController,
                          decoration: InputDecoration(
                            labelText: 'الطابق',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.layers),
                          ),
                          keyboardType: TextInputType.number,
                        ),

                        SizedBox(height: 16),

                        // حقل الحالة (دائماً متاح للتعديل)
                        DropdownButtonFormField<String>(
                          value: selectedStatus,
                          decoration: InputDecoration(
                            labelText: 'الحالة *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.info),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'متاح',
                              child: Text('متاح'),
                            ),
                            DropdownMenuItem(
                              value: 'محجوز',
                              child: Text('محجوز'),
                            ),
                            DropdownMenuItem(
                              value: 'مباع',
                              child: Text('مباع'),
                            ),
                            DropdownMenuItem(
                              value: 'غير متاح',
                              child: Text('غير متاح'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedStatus = value!;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى اختيار الحالة';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      if (selectedDirection == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('يرجى اختيار الاتجاه'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      try {
                        // التحقق النهائي من عدم وجود شقة بنفس الرقم والمشروع
                        final existingQuery =
                            await FirebaseFirestore.instance
                                .collection('apartments')
                                .where(
                                  'projectNumber',
                                  isEqualTo: projectNumberController.text,
                                )
                                .where(
                                  'number',
                                  isEqualTo: apartmentNumberController.text,
                                )
                                .get();

                        if (existingQuery.docs.isNotEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'يوجد شقة بنفس الرقم في هذا المشروع',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        // إنشاء بيانات الشقة الجديدة
                        final apartmentData = {
                          'number': apartmentNumberController.text,
                          'projectNumber': projectNumberController.text,
                          'direction': selectedDirection,
                          'description': descriptionController.text,
                          'area': areaController.text,
                          'floor':
                              floorController
                                  .text, // استخدام القيمة المدخلة يدوياً
                          'status': selectedStatus,
                          'pn':
                              '${projectNumberController.text}-${apartmentNumberController.text}',
                          'createdAt': FieldValue.serverTimestamp(),
                        };

                        // إضافة البيانات المشابهة إذا وجدت (باستثناء الطابق)
                        if (similarApartmentData != null) {
                          apartmentData.addAll({
                            'deedNumber':
                                similarApartmentData!['deedNumber'] ?? '',
                            'deedDate': similarApartmentData!['deedDate'] ?? '',
                            'planNumber':
                                similarApartmentData!['planNumber'] ?? '',
                            'regionNumber':
                                similarApartmentData!['regionNumber'] ?? '',
                            'city': similarApartmentData!['city'] ?? '',
                            'district': similarApartmentData!['district'] ?? '',
                            'paidAmount':
                                similarApartmentData!['paidAmount'] ?? 0,
                          });
                        }

                        // حفظ الشقة في قاعدة البيانات
                        await FirebaseFirestore.instance
                            .collection('apartments')
                            .add(apartmentData);

                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('تم إضافة الوحدة بنجاح'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('خطأ في إضافة الوحدة: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('إضافة الوحدة'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _editApartment(
    BuildContext context,
    String id,
    Map<String, dynamic> data,
  ) async {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final isMaster = authProvider.isMaster;

    // التحقق من صلاحيات المدير
    if (!isMaster) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('عذراً، هذه العملية متاحة للمدير فقط'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // إزالة رسالة التحقق من هنا ونقلها إلى زر الحفظ

    final controllers = {
      'number': TextEditingController(text: _formatNumber(data['number'])),
      'projectNumber': TextEditingController(text: data['projectNumber'] ?? ''),
      'direction': TextEditingController(text: data['direction'] ?? ''),
      'description': TextEditingController(text: data['description'] ?? ''),
      'deedNumber': TextEditingController(
        text: data['deedNumber']?.toString() ?? '',
      ),
      'clientRef': TextEditingController(text: data['clientRef'] ?? ''),
    };

    String status = data['status'] ?? 'متاح';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('تعديل الشقة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(controllers['number']!, 'رقم الشقة'),
                _buildTextField(controllers['projectNumber']!, 'رقم المشروع'),
                _buildTextField(controllers['direction']!, 'الاتجاه'),
                _buildDropdownField(status, (value) {
                  setState(() {
                    status = value!;
                  });
                }),
                _buildTextField(controllers['description']!, 'الوصف'),
                _buildTextField(controllers['deedNumber']!, 'رقم الصك'),
                _buildTextField(
                  controllers['clientRef']!,
                  'معرّف العميل (clientRef)',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء'),
            ),
            TextButton(
              onPressed: () async {
                // عرض رسالة تأكيد قبل الحفظ
                final bool? confirmed = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('تأكيد التعديل'),
                        ],
                      ),
                      content: Text(
                        'هل أنت متأكد من رغبتك في حفظ التعديلات على هذه الشقة؟',
                        style: TextStyle(fontSize: 16),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text('إلغاء'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: Text('حفظ'),
                        ),
                      ],
                    );
                  },
                );

                // إذا لم يؤكد المستخدم، لا تقم بالحفظ
                if (confirmed != true) return;

                final updatedData = {
                  'number':
                      int.tryParse(controllers['number']!.text) ??
                      controllers['number']!.text,
                  'projectNumber': controllers['projectNumber']!.text,
                  'direction': controllers['direction']!.text,
                  'status': status,
                  'description': controllers['description']!.text,
                  'deedNumber': controllers['deedNumber']!.text,
                  'clientRef': controllers['clientRef']!.text,
                };

                await FirebaseFirestore.instance
                    .collection('apartments')
                    .doc(id)
                    .update(updatedData);
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('تم تحديث الشقة بنجاح')));
              },
              child: Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  void showSmartAddContractDialog({
    required BuildContext context,
    required String projectNumber,
    required String unitNumber,
    required String direction,
    String? prefilledClientId,
    String? prefilledClientName,
  }) {
    final formKey = GlobalKey<FormState>();

    final identityNumberController = TextEditingController(
      text: prefilledClientId ?? '',
    );
    final totalAmountController = TextEditingController();
    final paidAmountController = TextEditingController();
    final deliveryMonthsController = TextEditingController();
    final deliveryDaysController = TextEditingController();

    String? clientName = prefilledClientName;
    bool loadingClient = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> fetchClientData(String id) async {
              setState(() => loadingClient = true);
              final snapshot =
                  await FirebaseFirestore.instance
                      .collection('customers')
                      .where('identityNumber', isEqualTo: id)
                      .limit(1)
                      .get();

              if (snapshot.docs.isNotEmpty) {
                final data = snapshot.docs.first.data();
                clientName = data['name'];
              } else {
                clientName = null;
              }

              setState(() => loadingClient = false);
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.0),
              ),
              elevation: 10,
              backgroundColor: Colors.white,
              child: SingleChildScrollView(
                child: Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        margin: EdgeInsets.only(bottom: 20),
                        child: Column(
                          children: [
                            Text(
                              'إضافة عقد جديد',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'الشقة $unitNumber - المشروع $projectNumber',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),

                      // Form
                      Form(
                        key: formKey,
                        child: Column(
                          children: [
                            // Identity Field
                            Container(
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: TextFormField(
                                controller: identityNumberController,
                                decoration: InputDecoration(
                                  labelText: 'رقم هوية العميل',
                                  labelStyle: TextStyle(
                                    color: Colors.grey[600],
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  suffixIcon:
                                      loadingClient
                                          ? Padding(
                                            padding: EdgeInsets.all(12),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Theme.of(
                                                      context,
                                                    ).primaryColor,
                                                  ),
                                            ),
                                          )
                                          : IconButton(
                                            icon: Icon(
                                              Icons.search,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).primaryColor,
                                            ),
                                            onPressed: () async {
                                              if (identityNumberController
                                                  .text
                                                  .isNotEmpty) {
                                                await fetchClientData(
                                                  identityNumberController.text
                                                      .trim(),
                                                );
                                              }
                                            },
                                          ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                                onFieldSubmitted: (value) async {
                                  if (value.isNotEmpty) {
                                    await fetchClientData(value.trim());
                                  }
                                },
                                validator:
                                    (value) => value!.isEmpty ? 'مطلوب' : null,
                              ),
                            ),

                            if (clientName != null) ...[
                              AnimatedContainer(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                margin: EdgeInsets.only(top: 12),
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      color: Theme.of(context).primaryColor,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'اسم العميل: $clientName',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Amount Fields
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStyledFormField(
                                    context: context,
                                    controller: totalAmountController,
                                    label: 'المبلغ الإجمالي',
                                    icon: Icons.attach_money,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: _buildStyledFormField(
                                    context: context,
                                    controller: paidAmountController,
                                    label: 'المبلغ المدفوع',
                                    icon: Icons.payment,
                                  ),
                                ),
                              ],
                            ),

                            // Delivery Fields
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStyledFormField(
                                    context: context,
                                    controller: deliveryMonthsController,
                                    label: 'مدة التسليم (أشهر)',
                                    icon: Icons.calendar_today,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: _buildStyledFormField(
                                    context: context,
                                    controller: deliveryDaysController,
                                    label: 'مدة التسليم (أيام)',
                                    icon: Icons.calendar_view_day,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Actions
                      SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(color: Colors.grey[300]!),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'إلغاء',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                                backgroundColor: Theme.of(context).primaryColor,
                              ),
                              onPressed: () async {
                                if (formKey.currentState!.validate()) {
                                  try {
                                    await addNewContract({
                                      'identityNumber':
                                          identityNumberController.text.trim(),
                                      'projectNumber': projectNumber,
                                      'unitNumber': unitNumber,
                                      'direction': direction,
                                      'totalAmount': double.parse(
                                        totalAmountController.text.trim(),
                                      ),
                                      'paidAmount': double.parse(
                                        paidAmountController.text.trim(),
                                      ),
                                      'deliveryMonths': int.parse(
                                        deliveryMonthsController.text.trim(),
                                      ),
                                      'deliveryDays': int.parse(
                                        deliveryDaysController.text.trim(),
                                      ),
                                    });

                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('تم حفظ العقد بنجاح'),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('فشل في الحفظ: $e'),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Text(
                                'حفظ العقد',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow1(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey),
          SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                text: '$label ',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
                children: [
                  TextSpan(
                    text: '$value',
                    style: TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void showApartmentDetailsDialog(
    BuildContext context,
    Map<String, dynamic> apartment,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.apartment, color: Colors.blue),
              SizedBox(width: 8),
              Text('تفاصيل الوحدة'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(),
                _buildInfoRow1(
                  Icons.numbers,
                  'رقم الوحدة:',
                  apartment['number'],
                ),
                _buildInfoRow1(
                  Icons.location_city,
                  'اللهة:',
                  apartment['city'],
                ),
                _buildInfoRow1(
                  Icons.location_on,
                  'الحي:',
                  apartment['district'],
                ),
                _buildInfoRow1(
                  Icons.place,
                  'المنطقة:',
                  apartment['regionNumber'],
                ),
                _buildInfoRow1(
                  Icons.map,
                  'رقم المخطط:',
                  apartment['planNumber'],
                ),
                _buildInfoRow1(
                  Icons.home_work,
                  'رقم المشروع:',
                  apartment['projectNumber'],
                ),
                _buildInfoRow1(Icons.layers, 'الطابق:', apartment['floor']),
                _buildInfoRow1(
                  Icons.aspect_ratio,
                  'المساحة:',
                  '${apartment['area']} م²',
                ),
                _buildInfoRow1(
                  Icons.description,
                  'الوصف:',
                  apartment['description'],
                ),
                _buildInfoRow1(
                  Icons.compass_calibration,
                  'الاتجاه:',
                  apartment['direction'],
                ),
                Divider(),
                _buildInfoRow1(
                  Icons.person,
                  'اسم العميل:',
                  apartment['clientName'],
                ),
                _buildInfoRow1(
                  Icons.badge,
                  'هوية العميل:',
                  apartment['clientIdentity'],
                ),
                _buildInfoRow1(
                  Icons.phone,
                  'جوال العميل:',
                  apartment['clientPhone'] ?? 'غير متوفر',
                ),
                Divider(),
                _buildInfoRow1(
                  Icons.receipt,
                  'رقم الصك:',
                  apartment['deedNumber'],
                ),
                _buildInfoRow1(
                  Icons.date_range,
                  'تاريخ الصك:',
                  apartment['deedDate'],
                ),
                Divider(),
                _buildInfoRow1(
                  Icons.monetization_on,
                  'المبلغ الإجمالي:',
                  '${apartment['totalAmount']} ر.س',
                ),
                _buildInfoRow1(
                  Icons.payment,
                  'المبلغ المدفوع:',
                  '${apartment['paidAmount']} ر.س',
                ),
                _buildInfoRow1(
                  Icons.attach_money,
                  'المدفوع من العميل (tot):',
                  '${apartment['tot']} ر.س',
                ),
                _buildInfoRow1(
                  Icons.calendar_today,
                  'تاريخ العقد:',
                  apartment['تاريخ العقد تحت الانشاء'],
                ),
                Divider(),
                _buildInfoRow1(
                  Icons.check_circle,
                  'الحالة:',
                  apartment['status'],
                ),
                _buildInfoRow1(
                  Icons.confirmation_number,
                  'PN:',
                  apartment['pn'],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إغلاق'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStyledFormField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        validator: (value) => value!.isEmpty ? 'مطلوب' : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600]),
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          prefixIcon: Icon(
            icon,
            color: Theme.of(context).primaryColor,
            size: 20,
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildDropdownField(String currentValue, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: currentValue,
        decoration: InputDecoration(
          labelText: 'الحالة',
          border: OutlineInputBorder(),
        ),
        items:
            [
              'متاح',
              'محجوز',
              'مباع',
              'معروضة للبيع',
              'تم الإفراغ',
              'تحت الاجراء',
            ].map((String value) {
              return DropdownMenuItem<String>(value: value, child: Text(value));
            }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String text,
    double fontSize,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: fontSize, color: color),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: fontSize - 2, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(dynamic number) {
    if (number == null) return 'غير معروف';
    return number.toString();
  }

  int _compareNumbers(dynamic a, dynamic b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;

    // محاولة تحويل إلى أرقام للمقارنة
    int? aInt = int.tryParse(a.toString());
    int? bInt = int.tryParse(b.toString());

    if (aInt != null && bInt != null) {
      return aInt.compareTo(bInt);
    }

    // إذا لم يكن رقمًا، قارن كنص
    return a.toString().compareTo(b.toString());
  }

  void _confirmDeleteAll() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('تأكيد الحذف'),
            content: Text(
              'هل أنت متأكد من رغبتك في حذف جميع الشقق؟ هذا الإجراء لا يمكن التراجع عنه.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء'),
              ),
              TextButton(
                onPressed: () {
                  _deleteAllApartments();
                  Navigator.pop(context);
                },
                child: Text('حذف الكل', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteAllApartments() async {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final isMaster = authProvider.isMaster;

    // التحقق من صلاحيات المدير
    if (!isMaster) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('عذراً، هذه العملية متاحة للمدير فقط'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final batch = FirebaseFirestore.instance.batch();
      final snapshot =
          await FirebaseFirestore.instance.collection('apartments').get();

      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تم حذف جميع الشقق بنجاح')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء الحذف: $e')));
    }
  }

  Future<void> _deleteApartment(String id) async {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final isMaster = authProvider.isMaster;

    // التحقق من صلاحيات المدير
    if (!isMaster) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('عذراً، هذه العملية متاحة للمدير فقط'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // عرض رسالة تأكيد قبل الحذف
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('تأكيد الحذف'),
            ],
          ),
          content: Text(
            'هل أنت متأكد من رغبتك في حذف هذه الشقة؟\n\nهذا الإجراء لا يمكن التراجع عنه.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('حذف'),
            ),
          ],
        );
      },
    );

    // إذا لم يؤكد المستخدم، لا تقم بالحذف
    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('apartments')
          .doc(id)
          .delete();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تم حذف الشقة بنجاح')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء الحذف: $e')));
    }
  }

  Future<void> _changeStatus(
    String id,
    Map<String, dynamic> data,
    String newStatus,
  ) async {
    try {
      FirebaseFirestore.instance.collection('apartments');

      void showResaleContractDialog({
        required BuildContext context,
        required String projectNumber,
        required String unitNumber,
        required String direction,
      }) {
        final formKey = GlobalKey<FormState>();
        final resaleContractService = ResaleContractService();

        final identityNumberController = TextEditingController();
        final totalAmountController = TextEditingController();
        final paidAmountController = TextEditingController();
        final deliveryMonthsController = TextEditingController();
        final deliveryDaysController = TextEditingController();

        String? clientName;
        bool loadingClient = false;

        showDialog(
          context: context,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setState) {
                Future<void> fetchClientData(String id) async {
                  setState(() => loadingClient = true);
                  final snapshot =
                      await FirebaseFirestore.instance
                          .collection('customers')
                          .where('identityNumber', isEqualTo: id)
                          .limit(1)
                          .get();

                  if (snapshot.docs.isNotEmpty) {
                    final data = snapshot.docs.first.data();
                    clientName = data['name'];
                  } else {
                    clientName = null;
                  }

                  setState(() => loadingClient = false);
                }

                return Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24.0),
                  ),
                  elevation: 10,
                  backgroundColor: Colors.white,
                  child: SingleChildScrollView(
                    child: Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Container(
                            margin: EdgeInsets.only(bottom: 20),
                            child: Column(
                              children: [
                                Text(
                                  'إضافة عقد إعادة بيع',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepOrange,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'الشقة $unitNumber - المشروع $projectNumber',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),

                          // Form
                          Form(
                            key: formKey,
                            child: Column(
                              children: [
                                // Identity Field
                                Container(
                                  decoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: TextFormField(
                                    controller: identityNumberController,
                                    decoration: InputDecoration(
                                      labelText: 'رقم هوية العميل الجديد',
                                      labelStyle: TextStyle(
                                        color: Colors.grey[600],
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      suffixIcon:
                                          loadingClient
                                              ? Padding(
                                                padding: EdgeInsets.all(12),
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.deepOrange),
                                                ),
                                              )
                                              : IconButton(
                                                icon: Icon(
                                                  Icons.search,
                                                  color: Colors.deepOrange,
                                                ),
                                                onPressed: () async {
                                                  if (identityNumberController
                                                      .text
                                                      .isNotEmpty) {
                                                    await fetchClientData(
                                                      identityNumberController
                                                          .text
                                                          .trim(),
                                                    );
                                                  }
                                                },
                                              ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                    ),
                                    onFieldSubmitted: (value) async {
                                      if (value.isNotEmpty) {
                                        await fetchClientData(value.trim());
                                      }
                                    },
                                    validator:
                                        (value) =>
                                            value!.isEmpty ? 'مطلوب' : null,
                                  ),
                                ),

                                if (clientName != null) ...[
                                  AnimatedContainer(
                                    duration: Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    margin: EdgeInsets.only(top: 12),
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.deepOrange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.person,
                                          color: Colors.deepOrange,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'اسم العميل: $clientName',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.deepOrange,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Amount Fields
                                SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildStyledFormField(
                                        context: context,
                                        controller: totalAmountController,
                                        label: 'المبلغ الإجمالي',
                                        icon: Icons.attach_money,
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: _buildStyledFormField(
                                        context: context,
                                        controller: paidAmountController,
                                        label: 'المبلغ المدفوع',
                                        icon: Icons.payment,
                                      ),
                                    ),
                                  ],
                                ),

                                // Delivery Fields
                                SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildStyledFormField(
                                        context: context,
                                        controller: deliveryMonthsController,
                                        label: 'مدة التسليم (أشهر)',
                                        icon: Icons.calendar_today,
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: _buildStyledFormField(
                                        context: context,
                                        controller: deliveryDaysController,
                                        label: 'مدة التسليم (أيام)',
                                        icon: Icons.calendar_view_day,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Actions
                          SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    side: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    'إلغاء',
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    backgroundColor: Colors.deepOrange,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                  onPressed: () async {
                                    if (formKey.currentState!.validate() &&
                                        clientName != null) {
                                      try {
                                        final data = {
                                          'projectNumber': projectNumber,
                                          'unitNumber': unitNumber,
                                          'direction': direction,
                                          'identityNumber':
                                              identityNumberController.text
                                                  .trim(),
                                          'totalAmount':
                                              double.tryParse(
                                                totalAmountController.text,
                                              ) ??
                                              0,
                                          'secondPartyAmount':
                                              double.tryParse(
                                                paidAmountController.text,
                                              ) ??
                                              0,
                                          'deliveryMonths':
                                              int.tryParse(
                                                deliveryMonthsController.text,
                                              ) ??
                                              0,
                                          'deliveryDays':
                                              int.tryParse(
                                                deliveryDaysController.text,
                                              ) ??
                                              0,
                                        };

                                        await resaleContractService
                                            .addResaleContract(data);

                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'تم إضافة عقد إعادة البيع بنجاح',
                                            ),
                                          ),
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text('حدث خطأ: $e'),
                                          ),
                                        );
                                      }
                                    } else if (clientName == null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'يرجى البحث عن العميل أولاً',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Text(
                                    'إضافة العقد',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      }

      await FirebaseFirestore.instance.collection('apartments').doc(id).update({
        'status': newStatus,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تغيير حالة الشقة إلى: $newStatus')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء تغيير الحالة: $e')));
    }
  }

  void _showCancelReservationDialog(
    BuildContext context,
    String apartmentId,
    Map<String, dynamic> data,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'تأكيد إلغاء الحجز',
              style: TextStyle(color: Colors.red[700]),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('هل أنت متأكد من إلغاء حجز الشقة رقم ${data['number']}؟'),
                SizedBox(height: 8),
                Text(
                  'سيتم حذف جميع العمليات المالية المرتبطة بهذا الحجز وإعادة حالة الشقة إلى "متاح".',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                if (data['clientName'] != null) ...[
                  SizedBox(height: 8),
                  Text(
                    'العميل: ${data['clientName']}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
                if (data['depositAmount'] != null) ...[
                  Text(
                    'مبلغ العربون: ${data['depositAmount']} ر.س',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _cancelReservation(apartmentId, data);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text('تأكيد الإلغاء'),
              ),
            ],
          ),
    );
  }

  Future<void> _cancelReservation(
    String apartmentId,
    Map<String, dynamic> data,
  ) async {
    try {
      // الحصول على رقم pn للشقة
      final apartmentPn = data['pn'];

      if (apartmentPn != null) {
        // التحقق من وجود عقد تحت الإنشاء بنفس رقم pn
        final contractsQuery =
            await FirebaseFirestore.instance
                .collection('contracts')
                .where('pn', isEqualTo: apartmentPn)
                .get();

        if (contractsQuery.docs.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'لا يمكن حذف العربون - يوجد عقد تحت الإنشاء بنفس رقم الوحدة',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      final batch = FirebaseFirestore.instance.batch();

      if (apartmentPn != null) {
        // حذف جميع العمليات المالية المرتبطة بهذه الشقة (العربون)
        final financialTransactions =
            await FirebaseFirestore.instance
                .collection('financialTransactions')
                .where('apartmentPn', isEqualTo: apartmentPn)
                .get();

        for (var doc in financialTransactions.docs) {
          final data = doc.data();
          // فقط حذف العمليات من نوع عربون
          if (data.containsKey('operationType') &&
              data['operationType'] == 'عربون') {
            batch.delete(doc.reference);
          }
        }
      }

      // تحديث بيانات الشقة - إعادة الحالة إلى متاح وحذف بيانات العميل
      final apartmentRef = FirebaseFirestore.instance
          .collection('apartments')
          .doc(apartmentId);
      batch.update(apartmentRef, {
        'status': 'متاح',
        'clientName': FieldValue.delete(),
        'depositAmount': FieldValue.delete(),
        'clientIdentity': FieldValue.delete(),
        'depositDate': FieldValue.delete(),
        'reservedAt': FieldValue.delete(),
      });

      // تنفيذ جميع العمليات
      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إلغاء الحجز بنجاح وحذف العمليات المالية المرتبطة'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء إلغاء الحجز: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // دالة لجلب ملخص البيانات المالية من جدول العمليات المالية
  Future<Map<String, double>> _getFinancialSummary(String? pn) async {
    if (pn == null || pn.isEmpty) {
      return {'total': 0, 'paid': 0};
    }

    try {
      final query =
          await FirebaseFirestore.instance
              .collection('financialTransactions')
              .where('apartmentPn', isEqualTo: pn)
              .get();

      double totalCredit = 0;
      double totalDebit = 0;

      for (var doc in query.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0).toDouble();
        final debitCredit = data['debitCredit'] ?? '';

        if (debitCredit == 'عليه') {
          totalCredit += amount;
        } else if (debitCredit == 'له' || debitCredit == 'لة') {
          totalDebit += amount;
        }
      }

      return {
        'total': totalDebit, // إجمالي المبلغ المطلوب (له)
        'paid': totalCredit, // المبلغ المدفوع (عليه)
      };
    } catch (e) {
      print('خطأ في جلب البيانات المالية: $e');
      return {'total': 0, 'paid': 0};
    }
  }

  void _showActionDialog(
    BuildContext context,
    String apartmentId,
    Map<String, dynamic> data,
  ) {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final isMaster = authProvider.isMaster;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text("اختر إجراء"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // خيار التعديل - متاح للمدير فقط
                if (isMaster)
                  ListTile(
                    leading: Icon(Icons.edit),
                    title: Text("تعديل"),
                    onTap: () {
                      Navigator.pop(context);
                      _editApartment(context, apartmentId, data);
                    },
                  )
                else
                  ListTile(
                    leading: Icon(Icons.edit, color: Colors.grey),
                    title: Text("تعديل", style: TextStyle(color: Colors.grey)),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('عذراً، هذه العملية متاحة للمدير فقط'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    },
                  ),
                // خيار الحذف - متاح للمدير فقط
                if (isMaster)
                  ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text("حذف"),
                    onTap: () {
                      Navigator.pop(context);
                      _deleteApartment(apartmentId);
                    },
                  )
                else
                  ListTile(
                    leading: Icon(Icons.delete, color: Colors.grey),
                    title: Text("حذف", style: TextStyle(color: Colors.grey)),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('عذراً، هذه العملية متاحة للمدير فقط'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    },
                  ),
                // خيار البيع المشروط للشقق المحجوزة
                if (data['status'] == 'محجوز')
                  ListTile(
                    leading: Icon(Icons.sell, color: Colors.purple),
                    title: Text("بيع للعميل الحاجز"),
                    onTap: () {
                      Navigator.pop(context);
                      _showConditionalSaleDialog(context, data);
                    },
                  ),
                Divider(),
                ...['متاح', 'محجوز', 'مباع', 'معروضة للبيع', 'تم الإفراغ'].map(
                  (status) => ListTile(
                    title: Text(status),
                    onTap: () {
                      Navigator.pop(context);
                      _changeStatus(apartmentId, data, status);
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  // دالة إظهار حوار حجز الشقة
  void _showReservationDialog(
    BuildContext context,
    String apartmentId,
    Map<String, dynamic> data,
  ) {
    final TextEditingController idController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController(
      text: 'عربون حجز شقة رقم ${data['number']}',
    );
    Map<String, dynamic>? clientData;
    bool isLoading = false;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text(
                    'حجز الشقة رقم ${data['number']}',
                    style: TextStyle(color: Colors.green[700]),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: idController,
                          decoration: InputDecoration(
                            labelText: 'رقم الهوية',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          onChanged: (value) async {
                            if (value.length >= 10) {
                              setState(() => isLoading = true);
                              try {
                                final querySnapshot =
                                    await FirebaseFirestore.instance
                                        .collection('customers')
                                        .where(
                                          'identityNumber',
                                          isEqualTo: value,
                                        )
                                        .get();

                                if (querySnapshot.docs.isNotEmpty) {
                                  setState(() {
                                    clientData =
                                        querySnapshot.docs.first.data();
                                    isLoading = false;
                                  });
                                } else {
                                  setState(() {
                                    clientData = null;
                                    isLoading = false;
                                  });
                                }
                              } catch (e) {
                                setState(() {
                                  clientData = null;
                                  isLoading = false;
                                });
                              }
                            }
                          },
                        ),
                        SizedBox(height: 16),
                        if (isLoading) CircularProgressIndicator(),
                        if (clientData != null) ...[
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'الاسم: ${clientData!['name']}',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text('الهاتف: ${clientData!['phoneNumber']}'),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),
                        ],
                        TextField(
                          controller: amountController,
                          decoration: InputDecoration(
                            labelText: 'مبلغ العربون',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: descriptionController,
                          decoration: InputDecoration(
                            labelText: 'الوصف',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.description),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('إلغاء'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _processReservation(
                          apartmentId,
                          data,
                          clientData!,
                          double.parse(amountController.text),
                          descriptionController.text,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('تأكيد الحجز'),
                    ),
                  ],
                ),
          ),
    );
  }

  // دالة معالجة الحجز
  Future<void> _processReservation(
    String apartmentId,
    Map<String, dynamic> apartmentData,
    Map<String, dynamic> clientData,
    double amount,
    String description,
  ) async {
    try {
      // إنشاء معرف فريد للعملية
      String transactionId =
          FirebaseFirestore.instance
              .collection('financialTransactions')
              .doc()
              .id;

      // إعداد بيانات العملية مع تحسين الأمان
      final transactionData = {
        'transactionId': transactionId,
        'date': DateTime.now().toIso8601String().split('T')[0],
        'customerName': clientData['name'],
        'amount': amount,
        'debitCredit': 'له',
        'idNumber': clientData['identityNumber'],
        'customerId': clientData['identityNumber'],
        'description': description,
        'transactionType': 'عربون',
        'operationType': 'عربون',
        'isIndependent': true,
        'isDeposit': true,
        'pn': apartmentData['pn'],
        'independentOperationType': 'عربون',
        'apartmentPn': apartmentData['pn'],
        'apartmentId': apartmentId,
        'projectNumber': apartmentData['projectNumber'],
        'unitNumber': apartmentData['number'],
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseFirestore.instance.app.options.projectId,
        'lastModified': FieldValue.serverTimestamp(),
        'transactionHash': _generateTransactionHash(
          clientData['identityNumber'],
          amount,
          DateTime.now().toIso8601String().split('T')[0],
        ),
      };

      // إضافة العملية المالية إلى قاعدة البيانات
      await FirebaseFirestore.instance
          .collection('financialTransactions')
          .doc(transactionId)
          .set(transactionData);

      // تحديث بيانات الشقة
      await FirebaseFirestore.instance
          .collection('apartments')
          .doc(apartmentId)
          .update({
            'status': 'محجوز',
            'clientName': clientData['name'],
            'depositAmount': amount,
            'clientIdentity': clientData['identityNumber'],
            'depositDate': DateTime.now().toIso8601String().split('T')[0],
            'reservedAt': FieldValue.serverTimestamp(),
          });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حفظ العربون وحجز الشقة بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء الحجز: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // دالة إظهار حوار البيع المشروط
  void _showConditionalSaleDialog(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'بيع الشقة للعميل الحاجز',
              style: TextStyle(color: Colors.purple[700]),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الشقة رقم: ${data['number']}'),
                SizedBox(height: 8),
                Text('العميل الحاجز: ${data['clientName'] ?? 'غير محدد'}'),
                Text('رقم الهوية: ${data['clientIdentity'] ?? 'غير محدد'}'),
                Text('مبلغ العربون: ${data['depositAmount'] ?? 'غير محدد'}'),
                SizedBox(height: 16),
                Text(
                  'سيتم فتح نموذج البيع للعميل الحاجز فقط.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _proceedWithConditionalSale(data);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
                child: Text('متابعة البيع'),
              ),
            ],
          ),
    );
  }

  // دالة متابعة البيع المشروط
  void _proceedWithConditionalSale(Map<String, dynamic> data) {
    // التحقق من وجود بيانات العميل الحاجز
    if (data['clientIdentity'] == null || data['clientName'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لا توجد بيانات للعميل الحاجز'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // فتح نموذج البيع مع تمرير بيانات العميل الحاجز
    showSmartAddContractDialog(
      context: context,
      projectNumber: data['projectNumber'] ?? '',
      unitNumber: data['number'].toString(),
      direction: data['direction'] ?? '',
      prefilledClientId: data['clientIdentity'],
      prefilledClientName: data['clientName'],
    );
  }

  // دالة إنشاء hash للمعاملة
  String _generateTransactionHash(String idNumber, double amount, String date) {
    final String rawData =
        '$idNumber-$amount-${DateTime.parse(date).millisecondsSinceEpoch}';
    int hash = 0;
    for (int i = 0; i < rawData.length; i++) {
      hash = (hash * 31 + rawData.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return hash.toString();
  }

  // دالة حذف المشروع كاملاً
  Future<void> _deleteProject() async {
    if (searchProjectNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى البحث عن مشروع أولاً'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // عرض حوار التأكيد
    bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'تأكيد حذف المشروع',
              style: TextStyle(color: Colors.red[700]),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning, color: Colors.red, size: 48),
                SizedBox(height: 16),
                Text(
                  'هل أنت متأكد من حذف جميع شقق المشروع رقم $searchProjectNumber؟',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'هذا الإجراء لا يمكن التراجع عنه!',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text('حذف المشروع'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      // جلب جميع الشقق للمشروع
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance
              .collection('apartments')
              .where('projectNumber', isEqualTo: searchProjectNumber)
              .get();

      // حذف كل شقة
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (QueryDocumentSnapshot doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      // تنفيذ الحذف
      await batch.commit();

      // إخفاء زر الحذف وإعادة تعيين البحث
      setState(() {
        showDeleteProjectButton = false;
        searchProjectNumber = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم حذف المشروع وجميع شققه بنجاح (${snapshot.docs.length} شقة)',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء حذف المشروع: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
