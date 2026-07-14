// تم دمج جميع التعديلات المطلوبة على صفحة عقود إعادة البيع
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:msakinal/brozinshin/admin/agency_manager.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../class/edit_delete_helper.dart';
import '../../class/contract_delete_helper.dart';
import '../../class/logger.dart';
import 'agency_form.dart' as forms;

class ResaleContractsListPage extends StatefulWidget {
  const ResaleContractsListPage({super.key});

  @override
  State<ResaleContractsListPage> createState() =>
      _ResaleContractsListPageState();
}

class _ResaleContractsListPageState extends State<ResaleContractsListPage> {
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            color: Color(0xFFE8EBF0),
            boxShadow: [
              BoxShadow(
                color: Color(0xFFBEC3C9),
                offset: Offset(0, 8),
                blurRadius: 16,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.white,
                offset: Offset(0, -8),
                blurRadius: 16,
                spreadRadius: 0,
              ),
            ],
          ),
          child: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            title:
                _isSearching
                    ? Container(
                      decoration: BoxDecoration(
                        color: Color(0xFFE8EBF0),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFFBEC3C9),
                            offset: Offset(4, 4),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                          BoxShadow(
                            color: Colors.white,
                            offset: Offset(-4, -4),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'ابحث برقم العقد أو اسم العميل',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          hintStyle: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.trim();
                          });
                        },
                      ),
                    )
                    : Text(
                      'عقود إعادة البيع',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
            actions: [
              Container(
                margin: EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Color(0xFFE8EBF0),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFBEC3C9),
                      offset: Offset(3, 3),
                      blurRadius: 6,
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.white,
                      offset: Offset(-3, -3),
                      blurRadius: 6,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    _isSearching ? Icons.close_rounded : Icons.search_rounded,
                    color: Color(0xFF475569),
                    size: 24,
                  ),
                  onPressed: () {
                    setState(() {
                      if (_isSearching) {
                        _searchQuery = '';
                      }
                      _isSearching = !_isSearching;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: Color(0xFFE8EBF0), // خلفية Neumorphic متناسقة
      body: _buildContractsList(context),
    );
  }

  Widget _buildContractsList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance.collection('resale_contracts').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('حدث خطأ في جلب البيانات'));
        }

        var contracts = snapshot.data!.docs;

        // تطبيق فلتر البحث
        if (_searchQuery.isNotEmpty) {
          contracts =
              contracts.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final pn = data['pn']?.toString().toLowerCase() ?? '';
                final clientName =
                    data['clientName']?.toString().toLowerCase() ?? '';
                final searchLower = _searchQuery.toLowerCase();

                return pn.contains(searchLower) ||
                    clientName.contains(searchLower);
              }).toList();
        }

        if (contracts.isEmpty) {
          return Center(
            child: Text(
              _searchQuery.isNotEmpty
                  ? 'لا توجد نتائج للبحث عن "$_searchQuery"'
                  : 'لا توجد عقود إعادة بيع مسجلة',
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = 1; // الافتراضي للجوال

            if (constraints.maxWidth >= 1200) {
              crossAxisCount = 4; // لابتوب كبير
            } else if (constraints.maxWidth >= 800) {
              crossAxisCount = 3; // لابتوب متوسط أو تابلت عرضي
            } else if (constraints.maxWidth >= 600) {
              crossAxisCount = 2; // تابلت أو موبايل كبير
            }

            return GridView.builder(
              padding: EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1,
              ),
              itemCount: contracts.length,
              itemBuilder: (context, index) {
                final contract =
                    contracts[index].data() as Map<String, dynamic>;
                final docId = contracts[index].id;
                return _buildResaleContractCard(contract, docId, context);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildResaleContractCard(
    Map<String, dynamic> contract,
    String docId,
    BuildContext context,
  ) {
    return NeumorphicContractCard(
      contract: contract,
      docId: docId,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ContractDetailsPage(docId: docId),
          ),
        );
      },
      onEdit: () {
        showDialog(
          context: context,
          builder:
              (_) => EditResaleContractDialog(docId: docId, contract: contract),
        );
      },
      onDelete: () => _deleteContract(context, docId, contract),
      onPrint: () {
        ResalePrinter(
          docId: contract['pn'] ?? '',
        ).printContract(contract['pn'] ?? '');
      },
      onAgency: () {
        showDialog(
          context: context,
          builder:
              (context) => forms.AgencyForm(
                contractId: contract['pn'],
                principalId: contract['identityNumber'],
                principalName: contract['clientName'],
                principalPhone: contract['phoneNumber'],
                onAgencySaved: (agencyData) async {
                  try {
                    // Log agency usage
                    await FirebaseFirestore.instance
                        .collection('agencyUsages')
                        .add({
                          'agencyId': agencyData['id'],
                          'contractId': contract['pn'],
                          'contractType': 'عقد إعادة بيع',
                          'usageDate': FieldValue.serverTimestamp(),
                          'usageDetails': 'استخدام في عقد إعادة بيع',
                          'usedBy': FirebaseAuth.instance.currentUser?.email,
                        });

                    // Update agency with contract reference
                    await FirebaseFirestore.instance
                        .collection('agencies')
                        .doc(agencyData['id'])
                        .update({
                          'usedIn': FieldValue.arrayUnion([contract['pn']]),
                          'lastUsed': FieldValue.serverTimestamp(),
                        });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تم تسجيل استخدام الوكالة بنجاح')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('حدث خطأ في تسجيل استخدام الوكالة: $e'),
                      ),
                    );
                  }
                },
              ),
        );
      },
    );
  }

  Future<void> _deleteContract(
    BuildContext context,
    String docId,
    Map<String, dynamic> contract,
  ) async {
    final editDeleteHelper = EditDeleteHelper();
    final shouldDelete = await editDeleteHelper.showDeleteConfirmationDialog(
      context,
      'عقد إعادة البيع',
    );
    String? userEmail = FirebaseAuth.instance.currentUser?.email;
    final rs = contract['pn'];
    if (shouldDelete) {
      await editDeleteHelper.createDeleteRequest(
        context: context,
        section: 'resale_contracts',
        itemId: contract['pn'],
        requesterName:
            FirebaseAuth.instance.currentUser?.displayName ?? 'مستخدم',
        requesterEmail: userEmail ?? '',
        details: 'طلب حذف عقد إعادة البيع رقم ${contract['pn'] ?? ''}',
      );

      if (userEmail == 'zizoalzohairy@gmail.com') {
        final contractDeleteHelper = ContractDeleteHelper();
        await contractDeleteHelper.deleteResaleContractByPn(rs, context);
      }
    }
  }
}

class NeumorphicContractCard extends StatefulWidget {
  final Map<String, dynamic> contract;
  final String docId;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPrint;
  final VoidCallback onAgency;

  const NeumorphicContractCard({
    Key? key,
    required this.contract,
    required this.docId,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onPrint,
    required this.onAgency,
  }) : super(key: key);

  @override
  _NeumorphicContractCardState createState() => _NeumorphicContractCardState();
}

class _NeumorphicContractCardState extends State<NeumorphicContractCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'تم البيع':
        return Color(0xFF10B981);
      case 'معروض للبيع':
        return Color(0xFFF59E0B);
      case 'مكتمل':
        return Color(0xFF10B981);
      case 'قيد المراجعة':
        return Color(0xFF3B82F6);
      case 'مرفوض':
        return Color(0xFFEF4444);
      case 'معلق':
        return Color(0xFF6B7280);
      default:
        return Color(0xFF6B7280);
    }
  }

  IconData getStatusIcon(String status) {
    switch (status) {
      case 'تم البيع':
        return Icons.check_circle_rounded;
      case 'معروض للبيع':
        return Icons.storefront_rounded;
      case 'مكتمل':
        return Icons.check_circle_rounded;
      case 'قيد المراجعة':
        return Icons.pending_actions_rounded;
      case 'مرفوض':
        return Icons.cancel_rounded;
      case 'معلق':
        return Icons.pause_circle_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
          if (_isExpanded) {
            _animationController.forward();
          } else {
            _animationController.reverse();
          }
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        margin: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        decoration: BoxDecoration(
          color: Color(0xFFE8EBF0),
          borderRadius: BorderRadius.circular(_isExpanded ? 24 : 16),
          boxShadow: [
            BoxShadow(
              color: Color(0xFFBEC3C9),
              offset: Offset(8, 8),
              blurRadius: 16,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.white,
              offset: Offset(-8, -8),
              blurRadius: 16,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(_isExpanded ? 20 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // رأس البطاقة المضغوط
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'عقد ${widget.contract['pn'] ?? 'غير معروف'}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: getStatusColor(widget.contract['status'] ?? ''),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          getStatusIcon(widget.contract['status'] ?? ''),
                          color: Colors.white,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          widget.contract['status'] ?? 'غير محدد',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                widget.contract['clientName'] ?? 'غير معروف',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),

              // المحتوى القابل للتوسع
              AnimatedBuilder(
                animation: _expandAnimation,
                builder: (context, child) {
                  return SizeTransition(
                    sizeFactor: _expandAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 16),
                        _buildInfoRow(
                          Icons.business_rounded,
                          'رقم المشروع',
                          widget.contract['projectNumber'] ?? '—',
                        ),
                        _buildInfoRow(
                          Icons.home_rounded,
                          'رقم الوحدة',
                          widget.contract['unitNumber'] ?? '—',
                        ),
                        _buildInfoRow(
                          Icons.attach_money_rounded,
                          'مبلغ الطرف الثاني',
                          '${widget.contract['secondPartyAmount']?.toStringAsFixed(2) ?? '0'} ر.س',
                        ),
                        _buildInfoRow(
                          Icons.receipt_rounded,
                          'رسوم إعادة البيع',
                          '${widget.contract['resaleFee']?.toStringAsFixed(2) ?? '0'} ر.س',
                        ),
                        SizedBox(height: 16),

                        // أزرار الإجراءات
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color(0xFFE8EBF0),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFFBEC3C9),
                                offset: Offset(4, 4),
                                blurRadius: 8,
                                spreadRadius: 0,
                              ),
                              BoxShadow(
                                color: Colors.white,
                                offset: Offset(-4, -4),
                                blurRadius: 8,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _actionButton(
                                Icons.edit_rounded,
                                'تعديل',
                                Color(0xFF3B82F6),
                                widget.onEdit,
                              ),
                              _actionButton(
                                Icons.delete_rounded,
                                'حذف',
                                Color(0xFFEF4444),
                                widget.onDelete,
                              ),
                              _actionButton(
                                Icons.print_rounded,
                                'طباعة',
                                Color(0xFF10B981),
                                widget.onPrint,
                              ),
                              _actionButton(
                                Icons.person_add_rounded,
                                'وكالة',
                                Color(0xFF8B5CF6),
                                widget.onAgency,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Color(0xFF6B7280)),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onPressed,
  ) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: Color(0xFFE8EBF0),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Color(0xFFBEC3C9),
              offset: Offset(2, 2),
              blurRadius: 4,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.white,
              offset: Offset(-2, -2),
              blurRadius: 4,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    String docId,
    Map<String, dynamic> contract,
  ) {
    showDialog(
      context: context,
      builder:
          (_) => EditResaleContractDialog(docId: docId, contract: contract),
    );
  }

  void printContract(String contractNumber) {
    ResalePrinter(docId: contractNumber).printContract(contractNumber);
    // الدالة التي تستدعي صفحة الطباعة باستخدام رقم العقد
    print('طباعة العقد رقم: $contractNumber');
    // هنا تستدعي الدالة الحقيقية للطباعة إذا كانت جاهزة عندك
  }

  void _showAgencyDialog(BuildContext context, Map<String, dynamic> contract) {
    showDialog(
      context: context,
      builder:
          (context) => forms.AgencyForm(
            contractId: contract['pn'],
            principalId: contract['identityNumber'],
            principalName: contract['clientName'],
            principalPhone: contract['phoneNumber'],
            onAgencySaved: (agencyData) async {
              try {
                // تسجيل استخدام الوكالة
                await FirebaseFirestore.instance
                    .collection('agencyUsages')
                    .add({
                      'agencyId': agencyData['id'],
                      'contractId': contract['pn'],
                      'contractType': 'عقد إعادة بيع',
                      'usageDate': FieldValue.serverTimestamp(),
                      'usageDetails': 'استخدام في عقد إعادة بيع',
                      'usedBy': FirebaseAuth.instance.currentUser?.email,
                    });

                // تحديث الوكالة بإضافة معرف العقد
                await FirebaseFirestore.instance
                    .collection('agencies')
                    .doc(agencyData['id'])
                    .update({
                      'usedIn': FieldValue.arrayUnion([contract['pn']]),
                      'lastUsed': FieldValue.serverTimestamp(),
                    });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم تسجيل استخدام الوكالة بنجاح')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('حدث خطأ في تسجيل استخدام الوكالة: $e'),
                  ),
                );
              }
            },
          ),
    );
  }
}

class ContractDetailsPage extends StatelessWidget {
  final String docId;
  const ContractDetailsPage({super.key, required this.docId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تفاصيل العقد')),
      body: FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance
                .collection('resale_contracts')
                .doc(docId)
                .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('العقد غير موجود'));
          }
          final contract = snapshot.data!.data() as Map<String, dynamic>;

          return Padding(
            padding: EdgeInsets.all(16),
            child: ListView(
              children: [
                Text(
                  'عقد #${contract['pn']}',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                _buildInfoRow('اسم العميل', contract['clientName'] ?? '—'),
                _buildInfoRow('حالة العقد', contract['status'] ?? '—'),
                _buildInfoRow('رقم المشروع', contract['projectNumber'] ?? '—'),
                _buildInfoRow('رقم الوحدة', contract['unitNumber'] ?? '—'),
                _buildInfoRow(
                  'مبلغ الطرف الثاني',
                  '${contract['secondPartyAmount']?.toStringAsFixed(2) ?? '0'} ر.س',
                ),
                _buildInfoRow(
                  'رسوم إعادة البيع',
                  '${contract['resaleFee']?.toStringAsFixed(2) ?? '0'} ر.س',
                ),
                _buildInfoRow(
                  'تاريخ الإنشاء',
                  formatDate(contract['createdAt']),
                ),
                _buildInfoRow('آخر تحديث', formatDate(contract['updatedAt'])),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(width: 4),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'غير معروف';
    return DateFormat('yyyy/MM/dd').format(timestamp.toDate());
  }
}

class EditResaleContractDialog extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> contract;
  const EditResaleContractDialog({
    super.key,
    required this.docId,
    required this.contract,
  });

  @override
  State<EditResaleContractDialog> createState() =>
      _EditResaleContractDialogState();
}

class _EditResaleContractDialogState extends State<EditResaleContractDialog> {
  late TextEditingController _clientNameController;
  late TextEditingController _statusController;
  late TextEditingController _secondPartyAmountController;
  late TextEditingController _resaleFeeController;
  late TextEditingController _projectNumberController;
  late TextEditingController _unitNumberController;

  @override
  void initState() {
    super.initState();
    _clientNameController = TextEditingController(
      text: widget.contract['clientName'] ?? '',
    );
    _statusController = TextEditingController(
      text: widget.contract['status'] ?? '',
    );
    _secondPartyAmountController = TextEditingController(
      text: widget.contract['secondPartyAmount']?.toString() ?? '',
    );
    _resaleFeeController = TextEditingController(
      text: widget.contract['resaleFee']?.toString() ?? '',
    );
    _projectNumberController = TextEditingController(
      text: widget.contract['projectNumber'] ?? '',
    );
    _unitNumberController = TextEditingController(
      text: widget.contract['unitNumber'] ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('تعديل العقد'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _clientNameController,
              decoration: InputDecoration(labelText: 'اسم العميل'),
            ),
            TextField(
              controller: _statusController,
              decoration: InputDecoration(labelText: 'حالة العقد'),
            ),
            TextField(
              controller: _secondPartyAmountController,
              decoration: InputDecoration(labelText: 'مبلغ الطرف الثاني'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _resaleFeeController,
              decoration: InputDecoration(labelText: 'رسوم إعادة البيع'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _projectNumberController,
              decoration: InputDecoration(labelText: 'رقم المشروع'),
            ),
            TextField(
              controller: _unitNumberController,
              decoration: InputDecoration(labelText: 'رقم الوحدة'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: Text('إلغاء'),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          child: Text('حفظ'),
          onPressed: () async {
            final clientName = _clientNameController.text.trim();
            final status = _statusController.text.trim();
            final secondAmount = double.tryParse(
              _secondPartyAmountController.text.trim(),
            );
            final resaleFee = double.tryParse(_resaleFeeController.text.trim());
            final projectNumber = _projectNumberController.text.trim();
            final unitNumber = _unitNumberController.text.trim();

            if (clientName.isEmpty ||
                status.isEmpty ||
                secondAmount == null ||
                resaleFee == null ||
                projectNumber.isEmpty ||
                unitNumber.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('يرجى تعبئة جميع الحقول بشكل صحيح')),
              );
              return;
            }

            if (secondAmount < 0 || resaleFee < 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('المبالغ يجب أن تكون موجبة')),
              );
              return;
            }

            await FirebaseFirestore.instance
                .collection('resale_contracts')
                .doc(widget.docId)
                .update({
                  'clientName': clientName,
                  'status': status,
                  'secondPartyAmount': secondAmount,
                  'resaleFee': resaleFee,
                  'projectNumber': projectNumber,
                  'unitNumber': unitNumber,
                  'updatedAt': Timestamp.now(),
                });

            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

class ResalePrinter {
  final String docId;

  ResalePrinter({required this.docId});

  Future<Map<String, dynamic>?> _getAgencyData(String contractId) async {
    try {
      final agencySnapshot =
          await FirebaseFirestore.instance
              .collection('agencies')
              .where(
                'usedIn',
                arrayContains: contractId,
              ) // تحقق من استخدام الوكالة
              .get();

      if (agencySnapshot.docs.isEmpty) return null;

      final sortedDocs =
          agencySnapshot.docs.toList()..sort((a, b) {
            final aTime = (a.data()['lastUsed'] as Timestamp).toDate();
            final bTime = (b.data()['lastUsed'] as Timestamp).toDate();
            return bTime.compareTo(aTime);
          });

      return sortedDocs.first.data();
    } catch (e) {
      print('Error fetching agency data: $e');
      return null;
    }
  }

  String getAgentDataText(Map<String, dynamic>? agencyData) {
    if (agencyData != null) {
      return '  ووكيلاً عنه: ${agencyData['agentName']}\n'
          'حامل الهوية: ${agencyData['agentId']}\n'
          'برقم وكالة: ${agencyData['agencyNumber']}\n';
    }
    return '';
  }

  Future<void> printContract(docId) async {
    final querySnapshot =
        await FirebaseFirestore.instance
            .collection('resale_contracts')
            .where('pn', isEqualTo: docId)
            .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('العقد غير موجود');
    }

    final contractData = querySnapshot.docs.first.data();
    final cont = contractData['contractNumber'];
    final clientName = contractData['clientName'] ?? '';
    final companyFee =
        double.tryParse(contractData['companyFee'].toString()) ?? 0;
    final secondPartyAmount =
        double.tryParse(contractData['secondPartyAmount'].toString()) ?? 0;
    final unitNumber = contractData['unitNumber'] ?? '';
    final direction = contractData['direction'] ?? '';
    final paidAmount =
        double.tryParse(contractData['paidAmount'].toString()) ?? 0;
    final totalAmount =
        double.tryParse(contractData['totalAmount'].toString()) ?? 0;
    final marketingFee =
        double.tryParse(contractData['marketingFee'].toString()) ?? 0;
    final lawyerFee =
        double.tryParse(contractData['lawyerFee'].toString()) ?? 0;
    final resaleFee =
        double.tryParse(contractData['resaleFee'].toString()) ?? 0;
    final dateGregorian = contractData['dateGregorian'] ?? '';
    final dateHijri = contractData['dateHijri'] ?? '';
    final identityNumber = contractData['identityNumber'] ?? '';

    // جلب بيانات الوكيل
    final agencyData = await _getAgencyData(docId);
    final arabicFont = pw.Font.ttf(
      await rootBundle.load('assets/arm/Amiri-Regular.ttf'),
    );
    // إضافة معالجة البيانات في حالة وجود وكيل
    final agentSection =
        agencyData != null
            ? pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'وذلك بموجب الوكالة:',
                  style: pw.TextStyle(font: arabicFont, fontSize: 12),
                ),
                pw.Text(
                  'اسم الوكيل: ${agencyData['agentName']}',
                  style: pw.TextStyle(font: arabicFont, fontSize: 12),
                ),
                pw.Text(
                  'رقم الهوية: ${agencyData['agentId']}',
                  style: pw.TextStyle(font: arabicFont, fontSize: 12),
                ),
                pw.Text(
                  'رقم الوكالة: ${agencyData['agencyNumber']}',
                  style: pw.TextStyle(font: arabicFont, fontSize: 12),
                ),
                pw.Text(
                  'تاريخ الوكالة: ${agencyData['agencyDate']}',
                  style: pw.TextStyle(font: arabicFont, fontSize: 12),
                ),
              ],
            )
            : pw.Container();

    final pdf = pw.Document();

    final imageData = await rootBundle.load('images/m.png');
    final imageDaa = await rootBundle.load('images/4.jpg');
    final image = pw.MemoryImage(imageData.buffer.asUint8List());

    final image1 = pw.MemoryImage(imageDaa.buffer.asUint8List());
    // احسب المبلغ النهائي بعد الخصومات
    double totalFees = companyFee + marketingFee + lawyerFee + resaleFee;
    double finalAmount = paidAmount - totalFees;

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        pageFormat: PdfPageFormat.a4,
        build:
            (context) => [
              pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10),
                  decoration: pw.BoxDecoration(
                    image: pw.DecorationImage(
                      image: image1,
                      fit: pw.BoxFit.cover,
                    ),
                    border: pw.Border.all(width: 1, color: PdfColors.black),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(height: 1),
                      pw.Image(image),
                      pw.SizedBox(height: 2),
                      pw.Divider(),
                      pw.SizedBox(height: 5),
                      pw.Center(
                        child: pw.Text(
                          'بسم الله الرحمن الرحيم',
                          style: pw.TextStyle(font: arabicFont, fontSize: 14),
                        ),
                      ),
                      pw.SizedBox(height: 7),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'الحمد لله والصلاة والسلام على رسول الله ',
                            style: pw.TextStyle(
                              font: arabicFont,
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            'التاريخ : ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                            style: pw.TextStyle(font: arabicFont, fontSize: 12),
                          ),
                        ],
                      ),

                      pw.SizedBox(height: 8),
                      pw.Text(
                        '     السيد /ة/  $clientName   المحترم    (رقم الهوية: $identityNumber)   ',
                        style: pw.TextStyle(font: arabicFont, fontSize: 12),
                      ),

                      pw.Text(
                        'تحية طيبة وبعد،،،',
                        style: pw.TextStyle(font: arabicFont, fontSize: 12),
                      ),

                      pw.SizedBox(height: 5),
                      pw.Text(
                        'نحيطكم علماً بانكم قد قمتم بشراء شقة رقم .$unitNumber. في الدور رقم ..${contractData['unitData']?['floor'] ?? ''}.. بمشروع رقم .${contractData['projectNumber'] ?? ''}. بمدينة ..${contractData['unitData']?['city'] ?? ''}..  في حي .${contractData['unitData']['district']}. وهي شقة| .$direction. وفقا للعقد المبرم بينكم  وبين شركة مساكن الرفاهية للمقاولات العامة والتطوير العقارى بتاريخ ${contractData['dateHijri']}.',
                        style: pw.TextStyle(font: arabicFont, fontSize: 12),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'ونظراً لرغبتكم في التنازل عن العقد والتخلي عن ملكية الشقة المذكورة , '
                        'وعدم قبولكم افراغ الصك باسمكم وتسليم الشقة لكم , ورغبتكم باعطاء الشركة حق التصرف في بيعها .'
                        ' نفيدكم باننا نقبل هذا التنازل بشرط دفع مبلغ اضافي , ونرغب في توضيح الشروط كما يلي',
                        style: pw.TextStyle(
                          font: arabicFont,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),

                      pw.Text(
                        'الطرف الاول :  شركة مساكن الرفاهية',
                        style: pw.TextStyle(
                          font: arabicFont,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),

                      pw.Text(
                        'الطرف الثاني :  المبرم للعقد مع الشركة \nالطرف الثالث :  المشترى للشقة الخاصة بالطرف الثاني وهو الطرف الاخير في جميع التعاملات ',
                        style: pw.TextStyle(
                          font: arabicFont,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),

                      pw.Text(
                        'المبلغ الاضافة الذى تم الاتفاق عليه لتنفيذ عملية التنازل هو ($resaleFee) ريال سعودى غير مسترد نظير التكاليف التشغيلية للشقة لحين بيع الشقة من قبل الشركة \n (1) يتم دفع هذا البلغ قبل توقيع عقد التنازل وستلام سند قبض \n (2) يتم تسديد المبلغ النهائي وبشكل كامل , دون اى التزام اضافي من الطرف الاول وسداد جميع المستحقات التي عليك قبل التوقيع . \n (3) الشركة ستقوم ببيع الشقة بالسعر الذى تم ذكرة من قبلك وهو  (${contractData['secondPartyAmount']}) ريال سعودى + المبلغ المذكور ادناه وبالتوقيع تقر انك ذكرته من قبلك والشركة غير مسؤلة عن عدم بيع الشقة في وقت قياسي حيث انه لا يوجد اوقات معلومة لبيع الشقة ولا تتحمل الشركة اى مسئووليات في التأخير \n (4) السعر المتفق عليه لا يشمل دلالة المسوق ومبلغ الخدمات المقدمة من الشركة ورسوم المحاماة وغيرها من الرسوم المتعلقة بالبيع والافراغ . \n (5) وتكلفة رسوم اتعاب التسويق مبلغ وقدرة  ($marketingFee) ريال سعودى  و.$companyFee. ريال سعودى  اتعاب الشركة و.$lawyerFee. ريال سعودى اتعاب المحاماه وتدفع حين بيع الشقة للطرف الثالث . \n (6) اذا كان الشيك المقدم للشركة وقت توقيع عقد بيع شقة مسجلا بملاحظة ( شراء شقة - شراء عقار - قيمة شقة - الخ.... ) يتم احتساب ضريبة التصرف العقارى بنسبة 5% من مبلغ الشيك وتدفع للشركة وقت الافراغ للطرف الثالث ',
                        style: pw.TextStyle(
                          font: arabicFont,
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),

                      pw.Text(
                        'نرجو منكم التوقيع على هذا الاخطار كتاكيد لموافقتكم على الشروط المذكورة اعلاه . ',
                        style: pw.TextStyle(
                          font: arabicFont,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),

                      pw.Text(
                        'شاكرين لكم تعاونكم , ونتطلع الى اتمام هذه العملية بكل سهولة ويسر. ',
                        style: pw.TextStyle(
                          font: arabicFont,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),

                      pw.Text(
                        'مع خالص التحية والتقدير  . ',
                        style: pw.TextStyle(
                          font: arabicFont,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),

                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Column(
                            mainAxisAlignment: pw.MainAxisAlignment.start,
                            children: [
                              pw.Text(
                                '[ شركة مساكن الرفاهية للمقاولات العامة ] . ',
                                style: pw.TextStyle(
                                  font: arabicFont,
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 12),
                              pw.Text(
                                'التوقيع  . ',
                                style: pw.TextStyle(
                                  font: arabicFont,
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 10),
                            ],
                          ),
                          pw.Column(
                            mainAxisAlignment: pw.MainAxisAlignment.start,
                            children: [
                              pw.Text(
                                'الطرف الثاني: $clientName',
                                style: pw.TextStyle(
                                  font: arabicFont,
                                  fontSize: 14,
                                  color: PdfColor.fromHex('#0086BF'),
                                ),
                              ),
                              if (agencyData != null) ...[
                                pw.Text(
                                  'بواسطة وكيله:',
                                  style: pw.TextStyle(
                                    font: arabicFont,
                                    fontSize: 12,
                                  ),
                                ),
                                pw.Text(
                                  '${agencyData['agentName']}',
                                  style: pw.TextStyle(
                                    font: arabicFont,
                                    fontSize: 12,
                                  ),
                                ),
                                pw.Text(
                                  'بموجب الوكالة رقم: ${agencyData['agencyNumber']}',
                                  style: pw.TextStyle(
                                    font: arabicFont,
                                    fontSize: 12,
                                  ),
                                ),
                                pw.Text(
                                  'تاريخ: ${agencyData['agencyDate']}',
                                  style: pw.TextStyle(
                                    font: arabicFont,
                                    fontSize: 12,
                                  ),
                                ),
                                pw.Text(
                                  'هوية رقم: ${agencyData['agentId']}',
                                  style: pw.TextStyle(
                                    font: arabicFont,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              pw.SizedBox(height: 30),
                              pw.Container(
                                width: 120,
                                height: 1,
                                color: PdfColors.black,
                              ),
                              pw.Text(
                                'التوقيع',
                                style: pw.TextStyle(
                                  font: arabicFont,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
      ),
    );

    if (kIsWeb) {
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'عقد اعادة بيع-$cont.pdf',
      );
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    }
  }

  pw.Widget _contractField(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Text('$label $value', style: pw.TextStyle(fontSize: 12)),
    );
  }
}
