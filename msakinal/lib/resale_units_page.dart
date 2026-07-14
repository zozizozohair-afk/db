import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:msakinal/priovider/auth_provider.dart';
import 'package:provider/provider.dart';

class ResaleUnitsPage extends StatefulWidget {
  @override
  _ResaleUnitsPageState createState() => _ResaleUnitsPageState();
}

class _ResaleUnitsPageState extends State<ResaleUnitsPage> {
  final TextEditingController searchController = TextEditingController();
  String searchProjectNumber = '';
  String? expandedCardId;

  Color _getStatusColor(String status) {
    switch (status) {
      case 'محجوز':
        return Colors.amber[700]!;
      case 'معاد بيعها':
        return Colors.red[700]!;
      case 'معروضة للبيع':
      default:
        return Colors.purple[700]!;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'محجوز':
        return Icons.bookmark;
      case 'معاد بيعها':
        return Icons.check_circle;
      case 'معروضة للبيع':
      default:
        return Icons.sell;
    }
  }

  void _showPriceUpdateDialog(Map<String, dynamic> unitData, String docId) {
    final TextEditingController priceController = TextEditingController(
      text:
          unitData['resalePrice']?.toString() ??
          unitData['totalAmount']?.toString() ??
          '',
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('تحديث سعر الوحدة'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('وحدة رقم: ${unitData['number']}'),
                SizedBox(height: 16),
                TextFormField(
                  controller: priceController,
                  decoration: InputDecoration(
                    labelText: 'السعر الجديد',
                    border: OutlineInputBorder(),
                    suffixText: 'ر.س',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newPrice = double.tryParse(priceController.text);
                  if (newPrice != null && newPrice > 0) {
                    await FirebaseFirestore.instance
                        .collection('apartments')
                        .doc(docId)
                        .update({'resalePrice': newPrice});
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تم تحديث السعر بنجاح')),
                    );
                  }
                },
                child: Text('حفظ'),
              ),
            ],
          ),
    );
  }

  void _showBuyerDialog(Map<String, dynamic> unitData, String docId) {
    final TextEditingController buyerNameController = TextEditingController();
    final TextEditingController buyerPhoneController = TextEditingController();
    final TextEditingController buyerIdController = TextEditingController();
    final TextEditingController searchIdController = TextEditingController();
    bool isReservation = false;
    bool isSearching = false;
    String? searchMessage;

    Future<void> searchCustomer(
      String identityNumber,
      StateSetter setState,
    ) async {
      if (identityNumber.trim().isEmpty) return;

      setState(() {
        isSearching = true;
        searchMessage = null;
      });

      try {
        final customerQuery =
            await FirebaseFirestore.instance
                .collection('customers')
                .where('identityNumber', isEqualTo: identityNumber.trim())
                .limit(1)
                .get();

        if (customerQuery.docs.isNotEmpty) {
          final customerData = customerQuery.docs.first.data();
          setState(() {
            buyerNameController.text = customerData['name'] ?? '';
            buyerPhoneController.text = customerData['phoneNumber'] ?? '';
            buyerIdController.text = identityNumber.trim();
            searchMessage = 'تم العثور على العميل وتم ملء البيانات';
          });
        } else {
          setState(() {
            searchMessage = 'لم يتم العثور على عميل بهذا الرقم';
          });
        }
      } catch (e) {
        setState(() {
          searchMessage = 'خطأ في البحث: $e';
        });
      } finally {
        setState(() {
          isSearching = false;
        });
      }
    }

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text(isReservation ? 'حجز الوحدة' : 'إضافة مشتري'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('وحدة رقم: ${unitData['number']}'),
                        SizedBox(height: 16),
                        SwitchListTile(
                          title: Text('حجز فقط'),
                          value: isReservation,
                          onChanged:
                              (value) => setState(() => isReservation = value),
                        ),
                        SizedBox(height: 16),

                        // البحث عن العميل بالهوية
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'البحث عن عميل موجود:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: searchIdController,
                                      decoration: InputDecoration(
                                        labelText: 'رقم الهوية للبحث',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed:
                                        isSearching
                                            ? null
                                            : () => searchCustomer(
                                              searchIdController.text,
                                              setState,
                                            ),
                                    child:
                                        isSearching
                                            ? SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                            : Icon(Icons.search),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      minimumSize: Size(50, 48),
                                    ),
                                  ),
                                ],
                              ),
                              if (searchMessage != null) ...[
                                SizedBox(height: 8),
                                Text(
                                  searchMessage!,
                                  style: TextStyle(
                                    color:
                                        searchMessage!.contains('تم العثور')
                                            ? Colors.green[700]
                                            : Colors.red[700],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        SizedBox(height: 16),
                        TextFormField(
                          controller: buyerNameController,
                          decoration: InputDecoration(
                            labelText:
                                isReservation ? 'اسم الحاجز' : 'اسم المشتري',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: buyerPhoneController,
                          decoration: InputDecoration(
                            labelText: 'رقم الهاتف',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        if (!isReservation) ...[
                          SizedBox(height: 8),
                          TextFormField(
                            controller: buyerIdController,
                            decoration: InputDecoration(
                              labelText: 'رقم الهوية',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('إلغاء'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (buyerNameController.text.isNotEmpty &&
                            buyerPhoneController.text.isNotEmpty) {
                          final updateData = {
                            'buyerName': buyerNameController.text,
                            'buyerPhone': buyerPhoneController.text,
                            'status': isReservation ? 'محجوز' : 'معاد بيعها',
                            'lastUpdated': FieldValue.serverTimestamp(),
                          };

                          if (!isReservation) {
                            updateData['buyerIdentityNumber'] =
                                buyerIdController.text;
                            updateData['saleDate'] =
                                FieldValue.serverTimestamp();
                          } else {
                            updateData['reservationDate'] =
                                FieldValue.serverTimestamp();
                          }

                          await FirebaseFirestore.instance
                              .collection('apartments')
                              .doc(docId)
                              .update(updateData);

                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isReservation
                                    ? 'تم حجز الوحدة بنجاح'
                                    : 'تم بيع الوحدة بنجاح',
                              ),
                            ),
                          );
                        }
                      },
                      child: Text(isReservation ? 'حجز' : 'بيع'),
                    ),
                  ],
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الوحدات المعروضة للبيع'),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // شريط البحث
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'بحث برقم المشروع',
                filled: true,
                fillColor: Colors.grey.shade100,
                prefixIcon: Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      searchController.clear();
                      searchProjectNumber = '';
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  searchProjectNumber = value.trim();
                });
              },
            ),
          ),
          // قائمة الوحدات
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  searchProjectNumber.isNotEmpty
                      ? FirebaseFirestore.instance
                          .collection('apartments')
                          .where(
                            'status',
                            whereIn: ['معروضة للبيع', 'محجوز', 'معاد بيعها'],
                          )
                          .where(
                            'projectNumber',
                            isEqualTo: searchProjectNumber,
                          )
                          .snapshots()
                      : FirebaseFirestore.instance
                          .collection('apartments')
                          .where(
                            'status',
                            whereIn: ['معروضة للبيع', 'محجوز', 'معاد بيعها'],
                          )
                          .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('حدث خطأ في جلب البيانات'));
                }

                final units = snapshot.data!.docs;

                if (units.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sell_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'لا توجد وحدات معروضة للبيع',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // ترتيب الوحدات حسب الرقم
                units.sort((a, b) {
                  final aNumber =
                      int.tryParse(a['number']?.toString() ?? '0') ?? 0;
                  final bNumber =
                      int.tryParse(b['number']?.toString() ?? '0') ?? 0;
                  return aNumber.compareTo(bNumber);
                });

                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: units.length,
                  itemBuilder: (context, index) {
                    final unit = units[index];
                    final data = unit.data() as Map<String, dynamic>;
                    final docId = unit.id;
                    final status = data['status'] ?? 'معروضة للبيع';
                    final isExpanded = expandedCardId == docId;

                    return AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      margin: EdgeInsets.only(bottom: 12),
                      child: Card(
                        elevation: isExpanded ? 8 : 4,
                        shadowColor: _getStatusColor(status).withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: _getStatusColor(status),
                            width: 2,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            setState(() {
                              expandedCardId = isExpanded ? null : docId;
                            });
                          },
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // العنوان الرئيسي
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(
                                          status,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        _getStatusIcon(status),
                                        color: _getStatusColor(status),
                                        size: 24,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'وحدة رقم ${data['number']}',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: _getStatusColor(status),
                                            ),
                                          ),
                                          Text(
                                            'مشروع ${data['projectNumber']}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // مؤشر الحالة
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(status),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(
                                      isExpanded
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      color: _getStatusColor(status),
                                    ),
                                  ],
                                ),

                                // المعلومات الموسعة
                                AnimatedCrossFade(
                                  duration: Duration(milliseconds: 300),
                                  crossFadeState:
                                      isExpanded
                                          ? CrossFadeState.showSecond
                                          : CrossFadeState.showFirst,
                                  firstChild: SizedBox.shrink(),
                                  secondChild: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(height: 16),
                                      Divider(
                                        color: _getStatusColor(
                                          status,
                                        ).withOpacity(0.3),
                                      ),
                                      SizedBox(height: 12),

                                      // معلومات الوحدة
                                      _buildInfoRow(
                                        'الاتجاه',
                                        data['direction'] ?? 'غير محدد',
                                      ),
                                      _buildInfoRow(
                                        'الدور',
                                        data['floor']?.toString() ?? 'غير محدد',
                                      ),
                                      _buildInfoRow(
                                        'المساحة',
                                        data['area']?.toString() ?? 'غير محدد',
                                      ),
                                      _buildInfoRow(
                                        'السعر الأصلي',
                                        '${data['totalAmount']?.toString() ?? '0'} ر.س',
                                      ),
                                      if (data['resalePrice'] != null)
                                        _buildInfoRow(
                                          'سعر إعادة البيع',
                                          '${data['resalePrice']} ر.س',
                                        ),

                                      // معلومات العميل البائع الأصلي
                                      if (data['clientName'] != null) ...[
                                        SizedBox(height: 8),
                                        Container(
                                          padding: EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.blue.withOpacity(
                                                0.3,
                                              ),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'بيانات العميل البائع:',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue[700],
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              _buildInfoRow(
                                                'الاسم',
                                                data['clientName'],
                                              ),
                                              if (data['clientPhone'] != null)
                                                _buildInfoRow(
                                                  'الهاتف',
                                                  data['clientPhone'],
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],

                                      // معلومات المشتري/الحاجز
                                      if (data['buyerName'] != null) ...[
                                        SizedBox(height: 8),
                                        Container(
                                          padding: EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(
                                              status,
                                            ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: _getStatusColor(
                                                status,
                                              ).withOpacity(0.3),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                status == 'محجوز'
                                                    ? 'بيانات الحاجز:'
                                                    : 'بيانات المشتري:',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: _getStatusColor(
                                                    status,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              _buildInfoRow(
                                                'الاسم',
                                                data['buyerName'],
                                              ),
                                              _buildInfoRow(
                                                'الهاتف',
                                                data['buyerPhone'],
                                              ),
                                              if (data['buyerIdentityNumber'] !=
                                                  null)
                                                _buildInfoRow(
                                                  'رقم الهوية',
                                                  data['buyerIdentityNumber'],
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],

                                      SizedBox(height: 16),

                                      // أزرار العمليات
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed:
                                                  () => _showPriceUpdateDialog(
                                                    data,
                                                    docId,
                                                  ),
                                              icon: Icon(Icons.edit),
                                              label: Text('تحديث السعر'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.blue[600],
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed:
                                                  status == 'معاد بيعها'
                                                      ? null
                                                      : () => _showBuyerDialog(
                                                        data,
                                                        docId,
                                                      ),
                                              icon: Icon(
                                                status == 'محجوز'
                                                    ? Icons.shopping_cart
                                                    : Icons.person_add,
                                              ),
                                              label: Text(
                                                status == 'محجوز'
                                                    ? 'إتمام البيع'
                                                    : 'حجز/بيع',
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    status == 'معاد بيعها'
                                                        ? Colors.grey
                                                        : _getStatusColor(
                                                          status,
                                                        ),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(child: Text(value, style: TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
