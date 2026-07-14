import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:html' as html;
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'customer_update_service.dart';

class CustomerFormPage extends StatefulWidget {
  const CustomerFormPage({super.key});

  @override
  _CustomerFormPageState createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends State<CustomerFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  Map<String, dynamic> extraFields = {};
  String? editingDocId;
  String _searchQuery = '';
  String _selectedTypeFilter = 'الكل';
  String _selectedProjectFilter = 'الكل';
  String _selectedContractTypeFilter = 'الكل';
  bool _showSearchFilters = false;
  List<String> _projectNumbers = [];
  bool _loadCustomers = false;
  bool _isSearching = false;

  Set<String> _customersWithResale = {};
  Set<String> _customersWithReceipt = {};
  StreamSubscription<QuerySnapshot>? _resaleSub;
  StreamSubscription<QuerySnapshot>? _receiptSub;

  @override
  void initState() {
    super.initState();
    _loadProjectNumbers();
    _subscribeContractTypeSets();
  }

  /// عرض تقرير توزيع بيانات العميل قبل التحديث
  Future<void> _showCustomerDataDistribution(String identityNumber) async {
    final distribution = await CustomerUpdateService.checkCustomerDataDistribution(identityNumber);
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('توزيع بيانات العميل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('سيتم تحديث البيانات في الجداول التالية:'),
            const SizedBox(height: 10),
            ...distribution.entries.map((entry) => 
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('${entry.key}: ${entry.value} سجل'),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'إجمالي السجلات: ${distribution.values.fold(0, (sum, count) => sum + count)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _resaleSub?.cancel();
    _receiptSub?.cancel();
    super.dispose();
  }

  Future<void> _loadProjectNumbers() async {
    try {
      final apartmentsSnapshot = await FirebaseFirestore.instance.collection('apartments').get();
      Set<String> projectNumbersSet = {};
      for (var doc in apartmentsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['projectNumber'] != null && data['projectNumber'].toString().isNotEmpty) {
          projectNumbersSet.add(data['projectNumber'].toString());
        }
      }
      setState(() {
        _projectNumbers = projectNumbersSet.toList();
        _projectNumbers.sort();
      });
    } catch (e) {
      print('خطأ في تحميل أرقام المشاريع: $e');
    }
  }

  void _subscribeContractTypeSets() {
    _resaleSub = FirebaseFirestore.instance
        .collection('resale_contracts')
        .snapshots()
        .listen((snapshot) {
      final ids = snapshot.docs
          .map((d) => ((d.data() as Map<String, dynamic>)['identityNumber'] ?? '')
              .toString())
          .where((s) => s.isNotEmpty)
          .toSet();
      setState(() {
        _customersWithResale = ids;
      });
    });

    _receiptSub = FirebaseFirestore.instance
        .collection('astlam')
        .snapshots()
        .listen((snapshot) {
      final ids = snapshot.docs
          .map((d) => ((d.data() as Map<String, dynamic>)['clientIdentityNumber'] ?? '')
              .toString())
          .where((s) => s.isNotEmpty)
          .toSet();
      setState(() {
        _customersWithReceipt = ids;
      });
    });
  }

  void _copyToClipboard(String value) async {
    try {
      await html.window.navigator.clipboard?.writeText(value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم نسخ "$value"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر النسخ')),
        );
      }
    }
  }

  Future<void> _launchDialer(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('رقم غير صالح')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: clean);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر فتح الاتصال')),
      );
    }
  }

  void saveCustomer() async {
    if (_formKey.currentState!.validate()) {
      final customerData = {
        'type': extraFields['type'],
        'name': extraFields['name'],
        'description': extraFields['description'],
        'identityNumber': extraFields['identityNumber'],
        'phoneNumber': extraFields['phoneNumber'],
      };

      if (editingDocId != null) {
        // الحصول على البيانات القديمة للعميل
        final oldCustomerDoc = await FirebaseFirestore.instance
            .collection('customers')
            .doc(editingDocId)
            .get();
        
        final oldIdentityNumber = oldCustomerDoc.data()?['identityNumber'] ?? '';
        
        // تحديث بيانات العميل في جدول العملاء
        await FirebaseFirestore.instance
            .collection('customers')
            .doc(editingDocId)
            .update(customerData);
        
        // إذا تم تغيير رقم الهوية أو الاسم، قم بتحديث جميع الجداول المرتبطة
        if (oldIdentityNumber != extraFields['identityNumber'] || 
            oldCustomerDoc.data()?['name'] != extraFields['name']) {
          
          // استخدام خدمة التحديث الشاملة
          await CustomerUpdateService.updateCustomerDataEverywhere(
            oldIdentityNumber: oldIdentityNumber,
            newCustomerData: {
              'name': extraFields['name'],
              'identityNumber': extraFields['identityNumber'],
              'phoneNumber': extraFields['phoneNumber'],
            },
            context: context,
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(
            content: Text('تم تعديل العميل بنجاح'),
            backgroundColor: Colors.green,
          ));
        }
      } else {
        await FirebaseFirestore.instance
            .collection('customers')
            .add(customerData);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(
          content: Text('تم إضافة العميل بنجاح'),
          backgroundColor: Colors.green,
        ));
      }

      Navigator.of(context).pop();
      editingDocId = null;
      extraFields = {};
      setState(() {});
    }
  }

  Future<bool> _isCustomerLinkedToContract(String customerId) async {
    try {
      // البحث في مجموعة العقود
      final contractsQuery = await FirebaseFirestore.instance
          .collection('contracts')
          .where('customerId', isEqualTo: customerId)
          .limit(1)
          .get();

      if (contractsQuery.docs.isNotEmpty) {
        return true;
      }

      // البحث في مجموعة الشقق
      final apartmentsQuery = await FirebaseFirestore.instance
          .collection('apartments')
          .where('clientRef', isEqualTo: customerId)
          .limit(1)
          .get();

      return apartmentsQuery.docs.isNotEmpty;
    } catch (e) {
      print('خطأ في التحقق من ارتباط العميل بعقد: $e');
      return false;
    }
  }

  void deleteCustomer(String docId, Map<String, dynamic> customerData) async {
    // التحقق من ارتباط العميل بعقد
    final isLinked = await _isCustomerLinkedToContract(docId);
    
    if (isLinked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لا يمكن حذف العميل لأنه مرتبط بعقد أو شقة'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // إظهار تأكيد الحذف
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من حذف العميل "${customerData['name']}"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('إلغاء'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await FirebaseFirestore.instance
                    .collection('customers')
                    .doc(docId)
                    .delete();
                // التحقق من أن الـ widget ما زال نشطاً قبل إظهار SnackBar
                if (context.mounted) {
                  try {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تم حذف العميل بنجاح'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    print('تم حذف العميل بنجاح');
                  }
                }
              },
              child: Text('حذف', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  static Future<void> removeContractFromCustomer(
    String identityNumber,
    String contractNumber,
  ) async {
    try {
      if (identityNumber.isEmpty || contractNumber.isEmpty) return;

      final customersQuery =
          await FirebaseFirestore.instance
              .collection('customers')
              .where('identityNumber', isEqualTo: identityNumber)
              .limit(1)
              .get();

      if (customersQuery.docs.isEmpty) return;
      final customerDoc = customersQuery.docs.first;
      final customerId = customerDoc.id;
      final customerData = customerDoc.data();

      List<String> contractNumbers = [];
      if (customerData.containsKey('contractNumbers') &&
          customerData['contractNumbers'] is List) {
        contractNumbers = List<String>.from(customerData['contractNumbers']);
        if (contractNumbers.contains(contractNumber)) {
          contractNumbers.remove(contractNumber);
        }
      }
      final Map<String, dynamic> updateData = {
        'contractNumbers': contractNumbers,
      };
      if (customerData.containsKey('pn') &&
          customerData['pn'] == contractNumber) {
        updateData['pn'] = FieldValue.delete();
      }
      await FirebaseFirestore.instance
          .collection('customers')
          .doc(customerId)
          .update(updateData);
    } catch (e) {
      print('خطأ في إزالة رقم العقد من بيانات العميل: $e');
    }
  }

  Widget _buildSearchAndFilters() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Column(
        children: [
          // شريط البحث
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.9),
                  Colors.blue[50]!.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'البحث بالاسم أو رقم الهوية أو رقم الهاتف...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: Icon(Icons.search, color: Colors.blue[700]),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[600]),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      ),
                    IconButton(
                      icon: Icon(
                        _showSearchFilters ? Icons.filter_list : Icons.tune,
                        color: Colors.blue[700],
                      ),
                      onPressed: () {
                        setState(() {
                          _showSearchFilters = !_showSearchFilters;
                        });
                      },
                    ),
                  ],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                  if (_searchQuery.isNotEmpty) {
                    _isSearching = true;
                  }
                });
              },
            ),
          ),
          
          // فلاتر البحث
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            height: _showSearchFilters ? 200 : 0,
            child: _showSearchFilters ? Container(
              margin: EdgeInsets.only(top: 16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.9),
                    Colors.blue[50]!.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // فلتر النوع
                  Row(
                    children: [
                      Text(
                        'فلترة حسب النوع:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ['الكل', 'تحت الإنشاء', 'جاهز'].map((type) {
                              final isSelected = _selectedTypeFilter == type;
                              return Container(
                                margin: EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(type),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedTypeFilter = type;
                                    });
                                  },
                                  selectedColor: Colors.blue[100],
                                  checkmarkColor: Colors.blue[800],
                                  backgroundColor: Colors.white.withOpacity(0.7),
                                  labelStyle: TextStyle(
                                    color: isSelected ? Colors.blue[800] : Colors.grey[700],
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  // فلتر المشروع
                  Row(
                    children: [
                      Text(
                        'فلترة حسب المشروع:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ['الكل', ..._projectNumbers].map((project) {
                              final isSelected = _selectedProjectFilter == project;
                              return Container(
                                margin: EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(project == 'الكل' ? 'الكل' : 'مشروع $project'),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedProjectFilter = project;
                                    });
                                  },
                                  selectedColor: Colors.green[100],
                                  checkmarkColor: Colors.green[800],
                                  backgroundColor: Colors.white.withOpacity(0.7),
                                  labelStyle: TextStyle(
                                    color: isSelected ? Colors.green[800] : Colors.grey[700],
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  // فلتر نوع العقد
                  Row(
                    children: [
                      Text(
                        'فلترة حسب نوع العقد:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple[800],
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ['الكل', 'عقد إعادة بيع', 'محضر الاستلام', 'غير مفرغ ولم يعد البيع']
                                .map((ct) {
                              final isSelected = _selectedContractTypeFilter == ct;
                              return Container(
                                margin: EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(ct),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedContractTypeFilter = ct;
                                    });
                                  },
                                  selectedColor: Colors.purple[100],
                                  checkmarkColor: Colors.purple[800],
                                  backgroundColor: Colors.white.withOpacity(0.7),
                                  labelStyle: TextStyle(
                                    color: isSelected ? Colors.purple[800] : Colors.grey[700],
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ) : SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFormField(
              label: 'اسم العميل',
              initialValue: extraFields['name'],
              onChanged: (val) => extraFields['name'] = val,
              icon: Icons.person,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'يرجى إدخال اسم العميل';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            _buildFormField(
              label: 'الوصف',
              initialValue: extraFields['description'],
              onChanged: (val) => extraFields['description'] = val,
              icon: Icons.description,
            ),
            SizedBox(height: 16),
            _buildFormField(
              label: 'رقم الهوية',
              initialValue: extraFields['identityNumber'],
              onChanged: (val) => extraFields['identityNumber'] = val,
              icon: Icons.badge,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'يرجى إدخال رقم الهوية';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            _buildFormField(
              label: 'رقم الهاتف',
              initialValue: extraFields['phoneNumber'],
              onChanged: (val) => extraFields['phoneNumber'] = val,
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'يرجى إدخال رقم الهاتف';
                }
                return null;
              },
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.blue[50],
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'نوع العميل:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: Text('تحت الإنشاء'),
                          value: 'تحت الإنشاء',
                          groupValue: extraFields['type'],
                          onChanged: (val) {
                            setState(() {
                              extraFields['type'] = val!;
                            });
                          },
                          activeColor: Colors.orange[700],
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: Text('جاهز'),
                          value: 'جاهز',
                          groupValue: extraFields['type'],
                          onChanged: (val) {
                            setState(() {
                              extraFields['type'] = val!;
                            });
                          },
                          activeColor: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [Colors.blue[600]!, Colors.blue[800]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: saveCustomer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  editingDocId != null ? 'تحديث العميل' : 'حفظ العميل',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    String? initialValue,
    required Function(String) onChanged,
    IconData? icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      initialValue: initialValue,
      onChanged: onChanged,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: Colors.blue[600]) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.8),
        labelStyle: TextStyle(color: Colors.blue[700]),
      ),
    );
  }

  Widget _buildProjectsRow(Map<String, dynamic> data) {
    List<String> customerProjects = [];
    
    // استخراج أرقام المشاريع من contractNumbers
    if (data.containsKey('contractNumbers') && data['contractNumbers'] is List) {
      List<String> contractNumbers = List<String>.from(data['contractNumbers']);
      Set<String> projectsSet = {};
      
      for (String contractNumber in contractNumbers) {
        if (contractNumber.contains('-')) {
          String projectNumber = contractNumber.split('-')[0];
          projectsSet.add(projectNumber);
        }
      }
      
      customerProjects = projectsSet.toList();
      customerProjects.sort();
    }
    
    if (customerProjects.isEmpty) {
      return Row(
        children: [
          Icon(Icons.business, size: 14, color: Colors.grey[400]),
          SizedBox(width: 4),
          Text(
            'لا توجد مشاريع',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }
    
    return Row(
      children: [
        Icon(Icons.business, size: 14, color: Colors.green[600]),
        SizedBox(width: 4),
        Expanded(
          child: Text(
            customerProjects.length == 1 
                ? 'مشروع ${customerProjects[0]}'
                : 'مشاريع: ${customerProjects.join(', ')}',
            style: TextStyle(
              color: Colors.green[700],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  List<DocumentSnapshot> _filterCustomers(List<DocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['name'] ?? '').toString().toLowerCase();
      final identityNumber = (data['identityNumber'] ?? '').toString().toLowerCase();
      final phoneNumber = (data['phoneNumber'] ?? '').toString().toLowerCase();
      final type = data['type'] ?? '';

      final idRaw = (data['identityNumber'] ?? '').toString();
      final hasResale = _customersWithResale.contains(idRaw);
      final hasReceipt = _customersWithReceipt.contains(idRaw);

      // فلترة حسب النص المدخل
      final matchesSearch = _searchQuery.isEmpty ||
          name.contains(_searchQuery) ||
          identityNumber.contains(_searchQuery) ||
          phoneNumber.contains(_searchQuery);

      // فلترة حسب النوع
      final matchesType = _selectedTypeFilter == 'الكل' || type == _selectedTypeFilter;

      // فلترة حسب المشروع
      bool matchesProject = true;
      if (_selectedProjectFilter != 'الكل') {
        matchesProject = false;
        // التحقق من وجود contractNumbers في بيانات العميل
        if (data.containsKey('contractNumbers') && data['contractNumbers'] is List) {
          List<String> contractNumbers = List<String>.from(data['contractNumbers']);
          // البحث عن أي عقد يبدأ برقم المشروع المحدد
          for (String contractNumber in contractNumbers) {
            if (contractNumber.startsWith(_selectedProjectFilter + '-')) {
              matchesProject = true;
              break;
            }
          }
        }
      }

      // فلترة حسب نوع العقد
      bool matchesContractType = true;
      if (_selectedContractTypeFilter != 'الكل') {
        if (_selectedContractTypeFilter == 'عقد إعادة بيع') {
          matchesContractType = hasResale;
        } else if (_selectedContractTypeFilter == 'محضر الاستلام') {
          matchesContractType = hasReceipt;
        } else if (_selectedContractTypeFilter == 'غير مفرغ ولم يعد البيع') {
          matchesContractType = !hasResale && !hasReceipt;
        }
      }

      return matchesSearch && matchesType && matchesProject && matchesContractType;
    }).toList();
  }

  Widget _buildCustomerList() {
    // إذا لم يتم تحميل العملاء بعد، عرض زر التحميل
    if (!_loadCustomers && _searchQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.blue[300],
            ),
            SizedBox(height: 24),
            Text(
              'اضغط على الزر أدناه لعرض جميع العملاء',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: LinearGradient(
                  colors: [Colors.green[600]!, Colors.green[800]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 15,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _loadCustomers = true;
                  });
                },
                icon: Icon(Icons.download, size: 24, color: Colors.white),
                label: Text(
                  'جلب جميع العملاء',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // إذا كان هناك بحث، ابدأ البحث
    if (_searchQuery.isNotEmpty) {
      return _buildSearchResults();
    }

    // عرض جميع العملاء
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('customers').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.blue[600]),
                SizedBox(height: 16),
                Text(
                  'جاري تحميل البيانات...',
                  style: TextStyle(color: Colors.blue[600]),
                ),
              ],
            ),
          );
        }

        final allDocs = snapshot.data!.docs;
        final filteredDocs = _filterCustomers(allDocs);

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Colors.grey[400],
                ),
                SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'لا توجد نتائج للبحث'
                      : 'لا توجد عملاء مسجلين',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_searchQuery.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Text(
                    'جرب البحث بكلمات مختلفة',
                    style: TextStyle(
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = 1;
            if (constraints.maxWidth >= 1200) {
              crossAxisCount = 3;
            } else if (constraints.maxWidth >= 800) {
              crossAxisCount = 2;
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.5,
              ),
              itemCount: filteredDocs.length,
              itemBuilder: (context, index) {
                final doc = filteredDocs[index];
                final data = doc.data() as Map<String, dynamic>;
                final type = data['type'];
                
                Color avatarColor;
                IconData typeIcon;
                switch (type) {
                  case 'تحت الإنشاء':
                    avatarColor = Colors.orange[700]!;
                    typeIcon = Icons.construction;
                    break;
                  case 'جاهز':
                    avatarColor = Colors.green[800]!;
                    typeIcon = Icons.check_circle;
                    break;
                  default:
                    avatarColor = Colors.grey[600]!;
                    typeIcon = Icons.person;
                }

                return GestureDetector(
                  onTap: () => showCustomerDetailsDialog(data),
                  child: EnhancedGlassCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [avatarColor, avatarColor.withOpacity(0.7)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: avatarColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                (data['name'] ?? '؟').substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Icon(
                                typeIcon,
                                color: Colors.white,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                data['name'] ?? 'بدون اسم',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.phone, size: 12, color: Colors.grey[600]),
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      data['phoneNumber'] ?? "غير محدد",
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: IconButton(
                                      icon: Icon(Icons.copy, size: 14, color: Colors.grey[700]),
                                      onPressed: () {
                                        final phone = (data['phoneNumber'] ?? '').toString();
                                        if (phone.isNotEmpty) _copyToClipboard(phone);
                                      },
                                      tooltip: 'نسخ رقم الهاتف',
                                      padding: EdgeInsets.all(6),
                                      constraints: BoxConstraints(minWidth: 28, minHeight: 28),
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: IconButton(
                                      icon: Icon(Icons.call, size: 14, color: Colors.green[600]),
                                      onPressed: () {
                                        final phone = (data['phoneNumber'] ?? '').toString();
                                        if (phone.isNotEmpty) _launchDialer(phone);
                                      },
                                      tooltip: 'اتصال',
                                      padding: EdgeInsets.all(6),
                                      constraints: BoxConstraints(minWidth: 28, minHeight: 28),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.badge, size: 12, color: Colors.grey[600]),
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      data['identityNumber'] ?? "غير محدد",
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: IconButton(
                                      icon: Icon(Icons.copy, size: 14, color: Colors.grey[700]),
                                      onPressed: () {
                                        final id = (data['identityNumber'] ?? '').toString();
                                        if (id.isNotEmpty) _copyToClipboard(id);
                                      },
                                      tooltip: 'نسخ رقم الهوية',
                                      padding: EdgeInsets.all(6),
                                      constraints: BoxConstraints(minWidth: 28, minHeight: 28),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 2),
                              // عرض المشاريع
                              _buildProjectsRow(data),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FutureBuilder<bool>(
                              future: () async {
                                List<String> contractNumbers = [];
                                if (data.containsKey('contractNumbers') && data['contractNumbers'] is List) {
                                  contractNumbers = List<String>.from(data['contractNumbers']);
                                }
                                return contractNumbers.isNotEmpty ? await _hasAnyUnitWithCode(contractNumbers) : false;
                              }(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return Container(
                                    width: 32,
                                    height: 32,
                                    child: Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                
                                if (snapshot.hasData && snapshot.data == true) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.description,
                                        color: Colors.green[600],
                                        size: 16,
                                      ),
                                      onPressed: () => _sendWhatsAppMessage(data),
                                      tooltip: 'بيانات الصك',
                                      padding: EdgeInsets.all(8),
                                      constraints: BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                    ),
                                  );
                                }
                                
                                // إذا لم يكن هناك صك، لا نعرض أي شيء
                                return SizedBox.shrink();
                              },
                            ),
                            SizedBox(height: 2),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.edit,
                                  color: Colors.blue[600],
                                  size: 16,
                                ),
                                onPressed: () => editCustomer(doc),
                                tooltip: 'تعديل العميل',
                                padding: EdgeInsets.all(8),
                                constraints: BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                            ),
                            SizedBox(height: 2),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.delete,
                                  color: Colors.red[600],
                                  size: 16,
                                ),
                                onPressed: () => deleteCustomer(doc.id, data),
                                tooltip: 'حذف العميل',
                                padding: EdgeInsets.all(8),
                                constraints: BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('customers')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.blue[600]),
                SizedBox(height: 16),
                Text(
                  'جاري البحث...',
                  style: TextStyle(color: Colors.blue[600]),
                ),
              ],
            ),
          );
        }

        final allDocs = snapshot.data!.docs;
        final filteredDocs = _filterCustomers(allDocs);

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Colors.grey[400],
                ),
                SizedBox(height: 16),
                Text(
                  'لا توجد نتائج للبحث "$_searchQuery"',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'جرب البحث بكلمات مختلفة',
                  style: TextStyle(
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = 1;
            if (constraints.maxWidth >= 1200) {
              crossAxisCount = 3;
            } else if (constraints.maxWidth >= 800) {
              crossAxisCount = 2;
            }

            return Column(
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: Colors.green[600]),
                      SizedBox(width: 8),
                      Text(
                        'نتائج البحث: ${filteredDocs.length} عميل',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 2.5,
                  ),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final type = data['type'];
                    
                    Color avatarColor;
                    IconData typeIcon;
                    switch (type) {
                      case 'تحت الإنشاء':
                        avatarColor = Colors.orange[700]!;
                        typeIcon = Icons.construction;
                        break;
                      case 'جاهز':
                        avatarColor = Colors.green[800]!;
                        typeIcon = Icons.check_circle;
                        break;
                      default:
                        avatarColor = Colors.grey[600]!;
                        typeIcon = Icons.person;
                    }

                    return GestureDetector(
                      onTap: () => showCustomerDetailsDialog(data),
                      child: EnhancedGlassCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [avatarColor, avatarColor.withOpacity(0.7)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: avatarColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    (data['name'] ?? '؟').substring(0, 1).toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Icon(
                                    typeIcon,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    data['name'] ?? 'بدون اسم',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[900],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                                      SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          data['phoneNumber'] ?? "غير محدد",
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(Icons.badge, size: 14, color: Colors.grey[600]),
                                      SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          data['identityNumber'] ?? "غير محدد",
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 2),
                                  // عرض المشاريع
                                  _buildProjectsRow(data),
                                ],
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.edit,
                                      color: Colors.blue[600],
                                      size: 16,
                                    ),
                                    onPressed: () => editCustomer(doc),
                                    tooltip: 'تعديل العميل',
                                    padding: EdgeInsets.all(8),
                                    constraints: BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.delete,
                                      color: Colors.red[600],
                                      size: 16,
                                    ),
                                    onPressed: () => deleteCustomer(doc.id, data),
                                    tooltip: 'حذف العميل',
                                    padding: EdgeInsets.all(8),
                                    constraints: BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<double> _calculateCustomerBalance(String identityNumber) async {
    double balance = 0.0;
    try {
      final transactionsQuery =
          await FirebaseFirestore.instance
              .collection('financialTransactions')
              .where('idNumber', isEqualTo: identityNumber)
              .get();
      for (var doc in transactionsQuery.docs) {
        final amount = doc['amount'] as double;
        final type = doc['debitCredit'] as String;
        balance += type == 'له' ? amount : -amount;
      }
      return balance;
    } catch (e) {
      print('خطأ في حساب رصيد العميل: $e');
      return 0.0;
    }
  }

  Future<Map<String, double>> _getDetailedFinancialSummary(String identityNumber) async {
    double totalCredit = 0.0;
    double totalDebit = 0.0;
    
    try {
      final transactionsQuery = await FirebaseFirestore.instance
          .collection('financialTransactions')
          .where('idNumber', isEqualTo: identityNumber)
          .get();
      
      for (var doc in transactionsQuery.docs) {
        final amount = doc['amount'] as double;
        final type = doc['debitCredit'] as String;
        
        if (type == 'له') {
          totalCredit += amount;
        } else {
          totalDebit += amount;
        }
      }
    } catch (e) {
      print('خطأ في جلب الملخص المالي: $e');
    }
    
    return {
      'totalCredit': totalCredit,
      'totalDebit': totalDebit,
    };
  }

  Widget _buildFinancialRow(String label, double amount, MaterialColor color) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color[800],
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '${amount.toStringAsFixed(2)} ر.س',
            style: TextStyle(
              color: color[800],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void showCustomerDetailsDialog(Map<String, dynamic> data) async {
    final identityNumber = data['identityNumber'] ?? "";
    
    // جلب أرقام العقود من قاعدة البيانات
    List<String> contractNumbers = [];
    
    try {
      // جلب أرقام العقود من حقل contractNumbers في بيانات العميل
      if (data.containsKey('contractNumbers') && data['contractNumbers'] is List) {
        contractNumbers = List<String>.from(data['contractNumbers']);
      }
      
      // البحث عن عقود إضافية في مجموعة العقود
      final contractsQuery = await FirebaseFirestore.instance
          .collection('contracts')
          .where('identityNumber', isEqualTo: identityNumber)
          .get();
      
      for (var doc in contractsQuery.docs) {
        final contractData = doc.data();
        final pn = contractData['pn']?.toString();
        if (pn != null && !contractNumbers.contains(pn)) {
          contractNumbers.add(pn);
        }
      }
      
      // البحث في مجموعة العقود الأخرى
      final otherContractsQuery = await FirebaseFirestore.instance
          .collection('okod')
          .where('identityNumber', isEqualTo: identityNumber)
          .get();
      
      for (var doc in otherContractsQuery.docs) {
        final contractData = doc.data();
        final pn = contractData['pn']?.toString();
        if (pn != null && !contractNumbers.contains(pn)) {
          contractNumbers.add(pn);
        }
      }
      
    } catch (e) {
      print('خطأ في جلب أرقام العقود: $e');
    }
    
    // حساب الرصيد
    final balance = await _calculateCustomerBalance(identityNumber);
    
    // جلب تفاصيل مالية إضافية
    Map<String, double> financialSummary = await _getDetailedFinancialSummary(identityNumber);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // تحديد العرض بناءً على حجم الشاشة
        double dialogWidth = MediaQuery.of(context).size.width;
        if (dialogWidth > 1200) {
          dialogWidth = dialogWidth * 0.4; // للشاشات الكبيرة
        } else if (dialogWidth > 800) {
          dialogWidth = dialogWidth * 0.6; // للابتوب
        } else {
          dialogWidth = dialogWidth * 0.9; // للموبايل
        }
        
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person,
                    color: Colors.blue[700],
                    size: 20,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'تفاصيل العميل',
                  style: TextStyle(
                    color: Colors.blue[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          content: Container(
            width: dialogWidth,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // معلومات العميل الأساسية - مضغوطة
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      children: [
                        _buildCompactDetailRow(Icons.person, 'الاسم', data['name'] ?? "-"),
                        _buildCompactDetailRow(Icons.badge, 'رقم الهوية', data['identityNumber'] ?? "-"),
                        _buildCompactDetailRow(Icons.phone, 'رقم الجوال', data['phoneNumber'] ?? "-"),
                        _buildCompactDetailRow(Icons.category, 'النوع', data['type'] ?? "-"),
                        if (data['description'] != null && data['description'].toString().isNotEmpty)
                          _buildCompactDetailRow(Icons.description, 'الوصف', data['description']),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 12),
                  
                  // أرقام العقود - مضغوطة
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.assignment, color: Colors.green[700], size: 18),
                            SizedBox(width: 6),
                            Text(
                              'العقود (${contractNumbers.length}):',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[800],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        if (contractNumbers.isNotEmpty) 
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: contractNumbers.map(
                              (contractNumber) => Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.green[300]!),
                                ),
                                child: Text(
                                  contractNumber,
                                  style: TextStyle(
                                    color: Colors.green[800],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ).toList(),
                          )
                        else
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.grey[600], size: 16),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'لا توجد عقود',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 12),
                  
                  // الملخص المالي المضغوط
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: balance >= 0
                            ? [Colors.green[50]!, Colors.green[100]!]
                            : [Colors.red[50]!, Colors.red[100]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: balance >= 0 ? Colors.green[200]! : Colors.red[200]!,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet,
                              color: balance >= 0 ? Colors.green[700] : Colors.red[700],
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'الملخص المالي:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: balance >= 0 ? Colors.green[800] : Colors.red[800],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        
                        // تفاصيل مالية مضغوطة
                        if (financialSummary['totalCredit']! > 0)
                          _buildCompactFinancialRow(
                            'له',
                            financialSummary['totalCredit']!,
                            Colors.green,
                          ),
                        if (financialSummary['totalDebit']! > 0)
                          _buildCompactFinancialRow(
                            'عليه',
                            financialSummary['totalDebit']!,
                            Colors.red,
                          ),
                        
                        if (financialSummary['totalCredit']! > 0 || financialSummary['totalDebit']! > 0)
                          Divider(color: Colors.grey[400], height: 16),
                        
                        // صافي الحساب
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: balance >= 0 ? Colors.green[200] : Colors.red[200],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'صافي الحساب:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: balance >= 0 ? Colors.green[800] : Colors.red[800],
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${balance.toStringAsFixed(2)} ر.س',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: balance >= 0 ? Colors.green[800] : Colors.red[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () => _showAddPaymentDialog(context, data),
              icon: Icon(Icons.payment, size: 18),
              label: Text('إضافة دفعة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            SizedBox(width: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                backgroundColor: Colors.blue[50],
                foregroundColor: Colors.blue[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text('إغلاق', style: TextStyle(fontSize: 14)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue[600], size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // دالة مضغوطة لعرض تفاصيل العميل
  Widget _buildCompactDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue[600], size: 16),
          SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      color: Colors.grey[800],
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

  // دالة مضغوطة لعرض المعلومات المالية
  Widget _buildCompactFinancialRow(String label, double amount, MaterialColor color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color[700],
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          Text(
            '${amount.toStringAsFixed(2)} ر.س',
            style: TextStyle(
              color: color[800],
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  void editCustomer(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    editingDocId = doc.id;
    extraFields = {
      'type': data['type'],
      'name': data['name'],
      'description': data['description'],
      'identityNumber': data['identityNumber'],
      'phoneNumber': data['phoneNumber'],
    };
    showEditCustomerDialog();
  }

  void showEditCustomerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.edit,
                  color: Colors.orange[700],
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'تعديل عميل',
                  style: TextStyle(
                    color: Colors.orange[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // زر عرض تقرير توزيع البيانات
              IconButton(
                onPressed: () {
                  final identityNumber = extraFields['identityNumber'] ?? '';
                  if (identityNumber.isNotEmpty) {
                    _showCustomerDataDistribution(identityNumber);
                  }
                },
                icon: Icon(
                  Icons.analytics_outlined,
                  color: Colors.blue[600],
                ),
                tooltip: 'عرض توزيع البيانات',
              ),
            ],
          ),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            child: _buildCustomerForm(),
          ),
        );
      },
    );
  }

  void showAddCustomerDialog() {
    extraFields = {};
    editingDocId = null;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.person_add,
                  color: Colors.green[700],
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'إضافة عميل جديد',
                style: TextStyle(
                  color: Colors.green[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            child: _buildCustomerForm(),
          ),
        );
      },
    );
  }

  // دالة إضافة دفعة مالية للعميل
  void _showAddPaymentDialog(BuildContext context, Map<String, dynamic> customer) {
    final _formKey = GlobalKey<FormState>();
    final _amountController = TextEditingController();
    final _descriptionController = TextEditingController();
    final _apartmentSearchController = TextEditingController();

    String? _transactionType = 'نقدي';
    String? _debitCredit = 'له';
    String? _operationType = 'عادية';
    String? _selectedApartmentPn;
    String? _selectedApartmentId;
    DateTime _selectedDate = DateTime.now();
    bool _isLoading = false;
    List<Map<String, dynamic>> _availableApartments = [];
    List<Map<String, dynamic>> _filteredApartments = [];
    
    // متغيرات جديدة لربط وحدات العميل
    List<Map<String, dynamic>> _customerApartments = [];
    Map<String, dynamic>? _selectedCustomerApartment;
    bool _linkToUnit = false; // خيار ربط العملية بوحدة

    final List<String> _transactionTypes = ['نقدي', 'شيك', 'حوالة'];
    final List<String> _debitCreditTypes = ['له', 'عليه'];
    final List<String> _operationTypes = ['عادية', 'عربون'];

    // إنشاء hash للعملية
    String _generateTransactionHash(String idNumber, double amount, DateTime date) {
      final String rawData = '$idNumber-$amount-${date.millisecondsSinceEpoch}';
      int hash = 0;
      for (int i = 0; i < rawData.length; i++) {
        hash = (hash * 31 + rawData.codeUnitAt(i)) & 0xFFFFFFFF;
      }
      return hash.toString();
    }

    // تحميل وحدات العميل المرتبطة
    Future<void> _loadCustomerApartments() async {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('apartments')
            .where('clientIdentity', isEqualTo: customer['identityNumber'])
            .get();

        _customerApartments = querySnapshot.docs.map((doc) => {
          'pn': doc['pn'],
          'number': doc['number'],
          'projectNumber': doc['projectNumber'],
          'id': doc.id,
          'status': doc['status'],
          'clientName': doc['clientName'],
          'data': doc.data(),
        }).toList();

        // إذا كان لدى العميل وحدة واحدة فقط، اختارها تلقائياً
        if (_customerApartments.length == 1) {
          _selectedCustomerApartment = _customerApartments.first;
          _linkToUnit = true;
        }
      } catch (e) {
        print('خطأ في تحميل وحدات العميل: $e');
      }
    }

    // تحميل الشقق المتاحة
    Future<void> _loadAvailableApartments() async {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('apartments')
            .where('status', isEqualTo: 'متاح')
            .get();

        _availableApartments = querySnapshot.docs.map((doc) => {
          'pn': doc['pn'],
          'number': doc['number'],
          'projectNumber': doc['projectNumber'],
          'id': doc.id,
          'data': doc.data(),
        }).toList();
        _filteredApartments = _availableApartments;
      } catch (e) {
        print('خطأ في تحميل الشقق: $e');
      }
    }

    // البحث في الشقق المتاحة
    void _searchApartments(String query) {
      if (query.isEmpty) {
        _filteredApartments = _availableApartments;
        return;
      }

      _filteredApartments = _availableApartments
          .where((apartment) =>
              apartment['pn'].toString().toLowerCase().contains(query.toLowerCase()) ||
              apartment['number'].toString().toLowerCase().contains(query.toLowerCase()) ||
              apartment['projectNumber'].toString().toLowerCase().contains(query.toLowerCase()))
          .toList();
    }

    // إرسال العملية المالية
    Future<void> _submitPayment() async {
      if (!_formKey.currentState!.validate()) return;

      // التحقق من اختيار الشقة في حالة العربون
      if (_operationType == 'عربون' && _selectedApartmentPn == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('الرجاء اختيار الشقة للعربون')),
        );
        return;
      }

      // التحقق من صحة المبلغ
      if (_amountController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('الرجاء إدخال المبلغ')),
        );
        return;
      }

      final double? amount = double.tryParse(_amountController.text);
      if (amount == null || amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('الرجاء إدخال مبلغ صحيح أكبر من صفر')),
        );
        return;
      }

      // طلب تأكيد من المستخدم
      bool confirmOperation = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('تأكيد العملية المالية'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('هل أنت متأكد من إجراء هذه العملية؟'),
              SizedBox(height: 10),
              Text('العميل: ${customer['name']}', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('المبلغ: ${amount.toStringAsFixed(2)} ر.س'),
              Text('نوع العملية: $_debitCredit'),
              Text('طريقة الدفع: $_transactionType'),
              Text('نوع العملية: $_operationType', style: TextStyle(fontWeight: FontWeight.bold)),
              if (_operationType == 'عربون' && _selectedApartmentPn != null)
                Text('رقم الشقة: $_selectedApartmentPn', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              if (_operationType == 'عادية' && _linkToUnit && _selectedCustomerApartment != null)
                Container(
                  margin: EdgeInsets.only(top: 8),
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('مربوطة بالوحدة: ${_selectedCustomerApartment!['pn']}', 
                           style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                      Text('سيتم تحديث المبلغ المدفوع في الوحدة والعقد', 
                           style: TextStyle(fontSize: 12, color: Colors.orange.shade600)),
                    ],
                  ),
                ),
              if (_operationType == 'عادية' && !_linkToUnit)
                Container(
                  margin: EdgeInsets.only(top: 8),
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('عملية مستقلة - غير مربوطة بوحدة', 
                       style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: Text('تأكيد'),
            ),
          ],
        ),
      ) ?? false;

      if (!confirmOperation) return;

      _isLoading = true;

      try {
        // إنشاء معرف فريد للعملية
        String transactionId = FirebaseFirestore.instance.collection('financialTransactions').doc().id;

        // إعداد بيانات العملية
        final transactionData = {
          'transactionId': transactionId,
          'date': _selectedDate,
          'customerName': customer['name'],
          'amount': amount,
          'debitCredit': _debitCredit,
          'idNumber': customer['identityNumber'],
          'customerId': customer['identityNumber'],
          'description': _descriptionController.text.trim(),
          'transactionType': _transactionType,
          'operationType': _operationType,
          'independentOperationType': _operationType,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': FirebaseFirestore.instance.app.options.projectId,
          'lastModified': FieldValue.serverTimestamp(),
          'transactionHash': _generateTransactionHash(customer['identityNumber'], amount, _selectedDate),
        };

        // إضافة بيانات الوحدة حسب نوع العملية
        if (_operationType == 'عربون' && _selectedApartmentPn != null) {
          // عملية عربون - ربط بوحدة جديدة
          transactionData.addAll({
            'isIndependent': true,
            'isDeposit': true,
            'apartmentPn': _selectedApartmentPn,
            'apartmentId': _selectedApartmentId,
            'projectNumber': _selectedApartmentPn?.split('-')[0],
            'unitNumber': _selectedApartmentPn?.split('-')[1],
          });
        } else if (_linkToUnit && _selectedCustomerApartment != null) {
          // عملية عادية مربوطة بوحدة العميل
          transactionData.addAll({
            'isIndependent': false,
            'isDeposit': false,
            'pn': _selectedCustomerApartment!['pn'],
            'projectNumber': _selectedCustomerApartment!['projectNumber'],
            'unitNumber': _selectedCustomerApartment!['number'],
            'apartmentId': _selectedCustomerApartment!['id'],
          });
        } else {
          // عملية مستقلة غير مربوطة بوحدة
          transactionData.addAll({
            'isIndependent': true,
            'isDeposit': false,
          });
        }

        // إضافة العملية المالية إلى قاعدة البيانات
        await FirebaseFirestore.instance
            .collection('financialTransactions')
            .doc(transactionId)
            .set(transactionData);

        // تحديث بيانات الوحدة حسب نوع العملية
        if (_operationType == 'عربون' && _selectedApartmentId != null) {
          // في حالة العربون، تحديث بيانات الشقة
          await FirebaseFirestore.instance
              .collection('apartments')
              .doc(_selectedApartmentId)
              .update({
            'status': 'محجوز',
            'clientName': customer['name'],
            'depositAmount': amount,
            'clientIdentity': customer['identityNumber'],
            'depositDate': _selectedDate,
            'reservedAt': FieldValue.serverTimestamp(),
          });
        } else if (_linkToUnit && _selectedCustomerApartment != null) {
          // في حالة العملية المربوطة بوحدة، تحديث المبلغ المدفوع
          final apartmentRef = FirebaseFirestore.instance
              .collection('apartments')
              .doc(_selectedCustomerApartment!['id']);
          
          await FirebaseFirestore.instance.runTransaction((transaction) async {
            final apartmentDoc = await transaction.get(apartmentRef);
            if (apartmentDoc.exists) {
              final currentPaidAmount = apartmentDoc.data()?['paidAmount'] ?? 0.0;
              final newPaidAmount = _debitCredit == 'له' 
                  ? currentPaidAmount + amount 
                  : currentPaidAmount - amount;
              
              transaction.update(apartmentRef, {
                'paidAmount': newPaidAmount,
                'lastPaymentDate': _selectedDate,
                'lastPaymentAmount': amount,
              });
            }
          });

          // تحديث العقد إذا وجد
          try {
            final contractQuery = await FirebaseFirestore.instance
                .collection('contracts')
                .where('pn', isEqualTo: _selectedCustomerApartment!['pn'])
                .get();
            
            if (contractQuery.docs.isNotEmpty) {
              final contractRef = contractQuery.docs.first.reference;
              await FirebaseFirestore.instance.runTransaction((transaction) async {
                final contractDoc = await transaction.get(contractRef);
                if (contractDoc.exists) {
                  final currentPaidAmount = contractDoc.data()?['paidAmount'] ?? 0.0;
                  final newPaidAmount = _debitCredit == 'له' 
                      ? currentPaidAmount + amount 
                      : currentPaidAmount - amount;
                  
                  transaction.update(contractRef, {
                    'paidAmount': newPaidAmount,
                    'lastPaymentDate': _selectedDate,
                    'lastPaymentAmount': amount,
                  });
                }
              });
            }
          } catch (e) {
            print('خطأ في تحديث العقد: $e');
          }
        }

        Navigator.of(context).pop(); // إغلاق نافذة إضافة الدفعة
        Navigator.of(context).pop(); // إغلاق نافذة تفاصيل العميل

        // رسالة النجاح حسب نوع العملية
        String successMessage;
        if (_operationType == 'عربون') {
          successMessage = 'تم حفظ العربون وحجز الشقة بنجاح';
        } else if (_linkToUnit && _selectedCustomerApartment != null) {
          successMessage = 'تم حفظ العملية وتحديث الوحدة ${_selectedCustomerApartment!['pn']} بنجاح';
        } else {
          successMessage = 'تم حفظ العملية المستقلة بنجاح';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        print('خطأ في حفظ العملية: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء حفظ العملية: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        _isLoading = false;
      }
    }

    // اختيار التاريخ
    Future<void> _selectDate(BuildContext context) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2101),
      );
      if (picked != null && picked != _selectedDate) {
        _selectedDate = picked;
      }
    }



    // تحميل الشقق المتاحة ووحدات العميل عند فتح النافذة
    _loadAvailableApartments();
    _loadCustomerApartments();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.payment, color: Colors.green[700]),
                  SizedBox(width: 8),
                  Text('إضافة دفعة مالية'),
                ],
              ),
              content: Container(
                width: MediaQuery.of(context).size.width * 0.6,
                height: MediaQuery.of(context).size.height * 0.7,
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // معلومات العميل
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.person, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'العميل: ${customer['name']}',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),

                        // ربط العملية بوحدة العميل (للعمليات العادية فقط)
                        if (_operationType == 'عادية') ...[
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.link, color: Colors.orange),
                                    SizedBox(width: 8),
                                    Text('ربط العملية بوحدة:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                SizedBox(height: 8),
                                CheckboxListTile(
                                  title: Text('ربط هذه العملية بوحدة العميل'),
                                  subtitle: Text('سيتم تحديث المبلغ المدفوع في الوحدة'),
                                  value: _linkToUnit,
                                  onChanged: (value) {
                                    setState(() {
                                      _linkToUnit = value ?? false;
                                      if (_linkToUnit && _customerApartments.isEmpty) {
                                        _loadCustomerApartments();
                                      }
                                    });
                                  },
                                ),
                                if (_linkToUnit) ...[
                                  SizedBox(height: 8),
                                  if (_customerApartments.isEmpty)
                                    Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.info, color: Colors.grey),
                                          SizedBox(width: 8),
                                          Text('لا توجد وحدات مرتبطة بهذا العميل'),
                                        ],
                                      ),
                                    )
                                  else ...[
                                    Text('اختيار الوحدة:', style: TextStyle(fontWeight: FontWeight.bold)),
                                    SizedBox(height: 8),
                                    DropdownButtonFormField<Map<String, dynamic>>(
                                      value: _selectedCustomerApartment,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.apartment),
                                      ),
                                      hint: Text('اختر الوحدة'),
                                      items: _customerApartments.map((apartment) {
                                        return DropdownMenuItem<Map<String, dynamic>>(
                                          value: apartment,
                                          child: Text('وحدة ${apartment['number']} - مشروع ${apartment['projectNumber']} (${apartment['pn']})'),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedCustomerApartment = value;
                                        });
                                      },
                                    ),
                                    if (_selectedCustomerApartment != null)
                                      Container(
                                        margin: EdgeInsets.only(top: 8),
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.check_circle, color: Colors.green, size: 16),
                                            SizedBox(width: 8),
                                            Text('الوحدة المختارة: ${_selectedCustomerApartment!['pn']}',
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                          SizedBox(height: 16),
                        ],

                        // نوع العملية
                        Text('نوع العملية:', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Row(
                          children: _operationTypes.map((type) {
                            return Expanded(
                              child: RadioListTile<String>(
                                title: Text(type),
                                value: type,
                                groupValue: _operationType,
                                onChanged: (value) {
                                  setState(() {
                                    _operationType = value;
                                    if (value != 'عربون') {
                                      _selectedApartmentPn = null;
                                      _selectedApartmentId = null;
                                      _apartmentSearchController.clear();
                                    }
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                        SizedBox(height: 16),

                        // اختيار الشقة (في حالة العربون فقط)
                        if (_operationType == 'عربون') ...[
                          Text('اختيار الشقة:', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          TextFormField(
                            controller: _apartmentSearchController,
                            decoration: InputDecoration(
                              labelText: 'بحث برقم الشقة',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.search),
                              suffixIcon: _selectedApartmentPn != null
                                  ? Icon(Icons.check_circle, color: Colors.green)
                                  : null,
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchApartments(value);
                              });
                            },
                          ),
                          if (_filteredApartments.isNotEmpty && _selectedApartmentPn == null)
                            Container(
                              margin: EdgeInsets.only(top: 8),
                              height: 150,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListView.builder(
                                itemCount: _filteredApartments.length,
                                itemBuilder: (context, index) {
                                  final apartment = _filteredApartments[index];
                                  return ListTile(
                                    title: Text('وحدة ${apartment['number']} - مشروع ${apartment['projectNumber']}'),
                                    subtitle: Text('رقم الوحدة: ${apartment['pn']}'),
                                    onTap: () {
                                      setState(() {
                                        _selectedApartmentPn = apartment['pn'].toString();
                                        _selectedApartmentId = apartment['id'];
                                        _apartmentSearchController.text = apartment['pn'].toString();
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          if (_selectedApartmentPn != null)
                            Container(
                              margin: EdgeInsets.only(top: 8),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.apartment, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('الشقة المختارة: $_selectedApartmentPn',
                                      style: TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          SizedBox(height: 16),
                        ],

                        // التاريخ
                        InkWell(
                          onTap: () => _selectDate(context),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'التاريخ',
                              border: OutlineInputBorder(),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(DateFormat('yyyy/MM/dd').format(_selectedDate)),
                                Icon(Icons.calendar_today),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 16),

                        // المبلغ
                        TextFormField(
                          controller: _amountController,
                          decoration: InputDecoration(
                            labelText: _operationType == 'عربون' ? 'مبلغ العربون' : 'المبلغ',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى إدخال المبلغ';
                            }
                            if (double.tryParse(value) == null) {
                              return 'يرجى إدخال رقم صحيح';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),

                        // الوصف
                        TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            labelText: 'الوصف',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.description),
                          ),
                          maxLines: 2,
                        ),
                        SizedBox(height: 16),

                        // نوع العملية وله/عليه
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('طريقة الدفع:'),
                                  SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    value: _transactionType,
                                    decoration: InputDecoration(border: OutlineInputBorder()),
                                    items: _transactionTypes
                                        .map((type) => DropdownMenuItem(
                                              value: type,
                                              child: Text(type),
                                            ))
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _transactionType = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('له/عليه:'),
                                  SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    value: _debitCredit,
                                    decoration: InputDecoration(border: OutlineInputBorder()),
                                    items: _debitCreditTypes
                                        .map((type) => DropdownMenuItem(
                                              value: type,
                                              child: Text(type),
                                            ))
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _debitCredit = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitPayment,
                  icon: _isLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_operationType == 'عربون' ? Icons.home : Icons.save),
                  label: Text(_operationType == 'عربون' ? 'حفظ العربون' : 'حفظ الدفعة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _operationType == 'عربون' ? Colors.orange : Colors.green,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.blue[900],
        title: Row(
          children: [
            Icon(Icons.people, color: Colors.blue[800]),
            SizedBox(width: 8),
            Text(
              'إدارة العملاء',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: Icon(Icons.refresh, color: Colors.blue[700]),
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                  _selectedTypeFilter = 'الكل';
                  _showSearchFilters = false;
                });
              },
              tooltip: 'إعادة تعيين الفلاتر',
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // خلفية متدرجة محسنة
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue[50]!.withOpacity(0.8),
                    Colors.white.withOpacity(0.9),
                    Colors.blue[100]!.withOpacity(0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          
          // المحتوى الرئيسي
          ListView(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            children: [
              SizedBox(height: 80), // مساحة للـ AppBar
              
              // زر إضافة عميل محسن
              Container(
                margin: EdgeInsets.symmetric(horizontal: 8),
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [Colors.blue[600]!, Colors.blue[800]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 15,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: showAddCustomerDialog,
                  icon: Icon(Icons.person_add, size: 28, color: Colors.white),
                  label: Text(
                    'إضافة عميل جديد',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: 20),
              
              // شريط البحث والفلاتر
              _buildSearchAndFilters(),
              
              SizedBox(height: 16),
              
              // قائمة العملاء
              _buildCustomerList(),
              
              SizedBox(height: 48),
            ],
          ),
        ],
      ),
    );
  }

  // دالة إرسال رسالة واتساب
  // دالة للتحقق من وجود صك للوحدة
  Future<bool> _hasUnitCode(String contractNumber) async {
    try {
      final apartmentsSnapshot = await FirebaseFirestore.instance
          .collection('apartments')
          .where('pn', isEqualTo: contractNumber)
          .get();
      
      if (apartmentsSnapshot.docs.isNotEmpty) {
        final apartmentData = apartmentsSnapshot.docs.first.data();
        return apartmentData.containsKey('code') && apartmentData['code'] != null;
      }
      return false;
    } catch (e) {
      print('خطأ في التحقق من وجود الصك: $e');
      return false;
    }
  }

  // دالة للتحقق من وجود صك لأي من عقود العميل
  Future<bool> _hasAnyUnitWithCode(List<String> contractNumbers) async {
    for (String contractNumber in contractNumbers) {
      if (await _hasUnitCode(contractNumber)) {
        return true;
      }
    }
    return false;
  }

  void _sendWhatsAppMessage(Map<String, dynamic> customerData) async {
    try {
      final customerName = customerData['name'] ?? 'العميل الكريم';
      final phoneNumber = customerData['phoneNumber'] ?? '';
      
      if (phoneNumber.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('رقم الهاتف غير متوفر لهذا العميل'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // جلب أرقام العقود للعميل
      List<String> contractNumbers = [];
      if (customerData.containsKey('contractNumbers') && customerData['contractNumbers'] is List) {
        contractNumbers = List<String>.from(customerData['contractNumbers']);
      }
      
      if (contractNumbers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('لا توجد عقود مرتبطة بهذا العميل'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // إرسال رسالة فقط للعقود التي لها صك
      List<String> contractsWithCode = [];
      for (String contractNumber in contractNumbers) {
        if (await _hasUnitCode(contractNumber)) {
          contractsWithCode.add(contractNumber);
        }
      }
      
      if (contractsWithCode.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('لا توجد وحدات بصك لهذا العميل'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // إرسال رسالة لكل عقد له صك
      for (String contractNumber in contractsWithCode) {
        final message = '''
السلام عليكم ورحمة الله وبركاته.
عزيزنا العميل السيد/ة : $customerName
مالك الشقة رقم $contractNumber
تبارك لك شركة مساكن الرفاهية
بصدور صك شقتك
ونتمنى منكم القدوم الى مقر الشركة لعملية افراغ الصك في مدة اقصاها شهر.

للتواصل عن طريق الواتساب لحجز موعد على الرقم 0509996115''';
        
        // تنظيف رقم الهاتف
        String cleanPhoneNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
        if (cleanPhoneNumber.startsWith('0')) {
          cleanPhoneNumber = '+966' + cleanPhoneNumber.substring(1);
        } else if (!cleanPhoneNumber.startsWith('+')) {
          cleanPhoneNumber = '+966' + cleanPhoneNumber;
        }
        
        // إنشاء رابط واتساب
        final encodedMessage = Uri.encodeComponent(message);
        final whatsappUrl = 'https://wa.me/$cleanPhoneNumber?text=$encodedMessage';
        
        // فتح رابط واتساب
        try {
          await _launchUrl(whatsappUrl);
          
          // إظهار رسالة نجاح
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم فتح واتساب لإرسال رسالة للعقد $contractNumber'),
              backgroundColor: Colors.green,
            ),
          );
          
          // انتظار قصير بين الرسائل إذا كان هناك أكثر من عقد
          if (contractsWithCode.length > 1 && contractNumber != contractsWithCode.last) {
            await Future.delayed(Duration(seconds: 2));
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في فتح واتساب للعقد $contractNumber'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء إرسال الرسالة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // دالة فتح الرابط
  Future<void> _launchUrl(String url) async {
    try {
      // استخدام JavaScript لفتح الرابط في المتصفح
      html.window.open(url, '_blank');
    } catch (e) {
      throw 'Could not launch $url';
    }
  }
}

// بطاقة محسنة بدون تمويه وأكثر بروزاً
class EnhancedGlassCard extends StatelessWidget {
  final Widget child;
  const EnhancedGlassCard({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 480;
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        border: Border.all(
          color: Colors.blue[300]!,
          width: isMobile ? 1.2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(isMobile ? 0.12 : 0.15),
            blurRadius: isMobile ? 10 : 12,
            offset: Offset(0, isMobile ? 5 : 6),
            spreadRadius: isMobile ? 1 : 2,
          ),
          BoxShadow(
            color: Colors.blue.withOpacity(isMobile ? 0.06 : 0.08),
            blurRadius: isMobile ? 16 : 20,
            offset: Offset(0, isMobile ? 8 : 10),
            spreadRadius: isMobile ? 3 : 4,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: isMobile ? 12 : 16),
        child: child,
      ),
    );
  }
}

// بطاقة زجاجية أساسية (للتوافق مع الكود القديم)
class GlassCard extends StatelessWidget {
  final Widget child;
  const GlassCard({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return EnhancedGlassCard(child: child);
  }
}
