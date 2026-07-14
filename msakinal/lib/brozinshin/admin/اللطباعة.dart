import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:msakinal/brozinshin/admin/%D8%AC%D9%84%D8%A8.dart';
import 'package:msakinal/brozinshin/admin/create_assignment.dart';
import 'package:msakinal/brozinshin/admin/priner.dart';
import 'package:provider/provider.dart';

import '../../astlam.dart';
import '../../class/logger.dart';
import '../../mony.dart';
import '../../priovider/auth_provider.dart';
import '../../class/edit_delete_helper.dart';
import '../../class/contract_delete_helper.dart';
import '../dashpordadmin.dart';

class ContractsPage0 extends StatefulWidget {
  const ContractsPage0({super.key});

  @override
  _ContractsPageState createState() => _ContractsPageState();
}

class _ContractsPageState extends State<ContractsPage0> {
  final ContractController _controller = ContractController();

  final TextEditingController _searchController = TextEditingController();
  late bool colorss = true;

  @override
  void initState() {
    super.initState();
    _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // دالة حساب الإحصائيات الحقيقية
  Map<String, dynamic> _calculateRealStats(
    List<QueryDocumentSnapshot> contracts,
    List<QueryDocumentSnapshot> payments,
  ) {
    int totalContracts = contracts.length;
    double totalPaid = 0.0;
    double totalRemaining = 0.0;

    // حساب إجمالي المبالغ من العقود
    Map<String, double> contractTotals = {};
    for (var contract in contracts) {
      final data = contract.data() as Map<String, dynamic>;
      final pn = data['pn']?.toString();
      final totalAmount = (data['totalAmount'] ?? 0.0).toDouble();

      if (pn != null) {
        contractTotals[pn] = totalAmount;
      }
    }

    // حساب المبالغ المدفوعة من المعاملات المالية
    Map<String, double> paidAmounts = {};
    for (var payment in payments) {
      final data = payment.data() as Map<String, dynamic>;
      final pn = data['pn']?.toString();
      final amount = (data['amount'] ?? 0.0).toDouble();
      final debitCredit = data['debitCredit']?.toString();

      if (pn != null && debitCredit == 'له') {
        // المدفوعات تكون "له"
        paidAmounts[pn] = (paidAmounts[pn] ?? 0.0) + amount;
      }
    }

    // حساب الإجماليات
    contractTotals.forEach((pn, total) {
      final paid = paidAmounts[pn] ?? 0.0;
      totalPaid += paid;
      totalRemaining += (total - paid);
    });

    return {
      'totalContracts': totalContracts,
      'totalPaid': totalPaid,
      'totalRemaining': totalRemaining,
    };
  }

  @override
  Widget build(BuildContext context) {
    final userty =
        Provider.of<AppAuthProvider>(context, listen: false).userType;
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1E293B),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.assignment_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'إدارة العقود',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: Color(0xFF1E293B),
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (userty == 'مستر')
            Container(
              margin: EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF3B82F6).withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: () async {
                  // التنقل إلى الصفحة المطلوبة
                  final username =
                      Provider.of<AppAuthProvider>(
                        context,
                        listen: false,
                      ).username;

                  if (username == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('اسم المستخدم غير متوفر'),
                        backgroundColor: Color(0xFFEF4444),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                    return;
                  }

                  // استخدمه بأمان بعد التحقق
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EpicMasterDashboard(username: username),
                    ),
                  );
                },
                icon: Icon(Icons.home_rounded, color: Colors.white, size: 22),
                tooltip: 'الصفحة الرئيسية',
              ),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: CustomScrollView(
          physics: BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  children: [
                    _buildStatsCard(),
                    SizedBox(height: 24),
                    _buildSearchBar(),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              sliver: _buildContractsList(),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: 100), // مساحة إضافية للـ FAB
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF3B82F6).withOpacity(0.4),
              blurRadius: 20,
              offset: Offset(0, 8),
              spreadRadius: 2,
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddContractDialog(),
          backgroundColor: Color(0xFF3B82F6),
          foregroundColor: Colors.white,
          elevation: 0,
          extendedPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          label: Text(
            'إضافة عقد جديد',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              letterSpacing: 0.2,
            ),
          ),
          icon: Container(
            padding: EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.add_rounded, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF64748B).withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Color(0xFF64748B).withOpacity(0.04),
            blurRadius: 4,
            offset: Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF3B82F6).withOpacity(0.3),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.analytics_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إحصائيات العقود',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'نظرة شاملة على أداء المبيعات',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 32),
            StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('contracts')
                      .snapshots(),
              builder: (context, contractsSnapshot) {
                if (contractsSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          'إجمالي العقود',
                          '...',
                          Icons.assignment,
                          Colors.blue,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildStatItem(
                          'المدفوع',
                          '...',
                          Icons.payment,
                          Colors.green,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildStatItem(
                          'المتبقي',
                          '...',
                          Icons.money_off,
                          Colors.orange,
                        ),
                      ),
                    ],
                  );
                }

                return StreamBuilder<QuerySnapshot>(
                  stream:
                      FirebaseFirestore.instance
                          .collection('financialTransactions')
                          .snapshots(),
                  builder: (context, paymentsSnapshot) {
                    if (paymentsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Row(
                        children: [
                          Expanded(
                            child: _buildStatItem(
                              'إجمالي العقود',
                              contractsSnapshot.hasData
                                  ? '${contractsSnapshot.data!.docs.length}'
                                  : '...',
                              Icons.assignment,
                              Colors.blue,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildStatItem(
                              'المدفوع',
                              '...',
                              Icons.payment,
                              Colors.green,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildStatItem(
                              'المتبقي',
                              '...',
                              Icons.money_off,
                              Colors.orange,
                            ),
                          ),
                        ],
                      );
                    }

                    final stats = _calculateRealStats(
                      contractsSnapshot.data?.docs ?? [],
                      paymentsSnapshot.data?.docs ?? [],
                    );

                    return Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            'إجمالي العقود',
                            '${stats['totalContracts']}',
                            Icons.assignment,
                            Colors.blue,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildStatItem(
                            'المدفوع',
                            '${NumberFormat('#,###').format(stats['totalPaid'])} ر.س',
                            Icons.payment,
                            Colors.green,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildStatItem(
                            'المتبقي',
                            '${NumberFormat('#,###').format(stats['totalRemaining'])} ر.س',
                            Icons.money_off,
                            Colors.orange,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.08), color.withOpacity(0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 12,
            offset: Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.2), color.withOpacity(0.15)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.25),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 28, color: color),
          ),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF64748B).withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Color(0xFF64748B).withOpacity(0.04),
            blurRadius: 4,
            offset: Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Color(0xFFE2E8F0), width: 1.5),
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'ابحث برقم العقد أو اسم العميل',
                    hintStyle: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    prefixIcon: Container(
                      margin: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF3B82F6).withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.search_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  onSubmitted: (value) => _performSearch(value),
                ),
              ),
            ),
            SizedBox(width: 16),
            Container(
              decoration: BoxDecoration(
                color: Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Color(0xFFE2E8F0), width: 1.5),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.clear_rounded,
                  color: Color(0xFF64748B),
                  size: 22,
                ),
                onPressed: () {
                  _searchController.clear();
                  _performSearch('');
                },
                tooltip: 'مسح البحث',
                padding: EdgeInsets.all(12),
              ),
            ),
            SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF3B82F6).withOpacity(0.4),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () => _performSearch(_searchController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'بحث',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContractsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _controller.contractsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(50),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('حدث خطأ في جلب البيانات: ${snapshot.error}'),
              ),
            ),
          );
        }

        final contracts = snapshot.data!.docs;

        if (contracts.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(50),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      _controller.searchQuery.isEmpty
                          ? 'لا توجد عقود مسجلة بعد'
                          : 'لا توجد نتائج للبحث عن: ${_controller.searchQuery}',
                      style: TextStyle(fontSize: 18),
                    ),
                    if (_controller.searchQuery.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                        child: Text('عرض جميع العقود'),
                      ),
                  ],
                ),
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final contract = contracts[index].data() as Map<String, dynamic>;
            final docId = contracts[index].id;

            return _buildContractCard(contract, docId);
          }, childCount: contracts.length),
        );
      },
    );
  }

  Widget _buildContractCard(Map<String, dynamic> contract, String docId) {
    Color getBorderColor(String status) {
      switch (status) {
        case 'تحت الإنشاء':
          return Colors.orange.shade700;
        case 'تم التسليم':
          return Colors.green.shade700;
        case 'إعادة بيع':
          return Colors.blue.shade700;
        case 'تمت إعادة البيع':
          return Colors.red.shade700;
        case 'تم الافراغ':
          return Colors.purple.shade700;
        case 'تم التنازل':
          return Colors.brown.shade700;
        default:
          return Colors.grey.shade800;
      }
    }

    return _ContractCard(
      contract: contract,
      docId: docId,
      borderColor: getBorderColor(contract['status'] ?? 'تحت الانشاء'),
      onActionButtonPressed:
          (action) => _handleContractAction(action, contract, context),
    );
  }

  // Helper method for compact detail rows
  Widget _buildCompactDetailRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Action buttons based on contract status
  Widget _buildActionButtons(
    Map<String, dynamic> contract,
    BuildContext context,
  ) {
    final status = contract['status'] ?? 'تحت الانشاء';

    switch (status) {
      case 'تحت الإنشاء':
        return _buildUnderConstructionButtons(contract, context);
      case 'إعادة بيع':
        return _buildResaleButtons(contract, context);
      case 'تمت إعادة البيع':
        return _buildCompletedResaleButtons(contract, context);
      case 'تم التنازل':
        return LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 400;
            return Column(
              children: [
                if (isSmallScreen) ...[
                  _buildStyledButton(
                    text: 'افراغ',
                    color: Colors.red,
                    icon: Icons.exit_to_app,
                    onPressed:
                        () => _navigateWithAnimation(
                          context,
                          Aistlam(progect: contract['pn']),
                        ),
                    isFullWidth: true,
                  ),
                  SizedBox(height: 8),
                  _buildStyledButton(
                    text: 'اعادة بيع',
                    color: Colors.green,
                    icon: Icons.shopping_cart,
                    onPressed:
                        () =>
                            _navigateToResaleContract(context, contract['pn']),
                    isFullWidth: true,
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildStyledButton(
                          text: 'افراغ',
                          color: Colors.red,
                          icon: Icons.exit_to_app,
                          onPressed:
                              () => _navigateWithAnimation(
                                context,
                                Aistlam(progect: contract['pn']),
                              ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _buildStyledButton(
                          text: 'اعادة بيع',
                          color: Colors.green,
                          icon: Icons.shopping_cart,
                          onPressed:
                              () => _navigateToResaleContract(
                                context,
                                contract['pn'],
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        );
      default:
        return SizedBox.shrink();
    }
  }

  Widget _buildUnderConstructionButtons(
    Map<String, dynamic> contract,
    BuildContext context,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen =
            constraints.maxWidth < 600; // زيادة العرض للأزرار الثلاثة

        return Column(
          children: [
            if (isSmallScreen) ...[
              _buildStyledButton(
                text: 'تنازل',
                color: Colors.orange,
                icon: Icons.assignment_turned_in,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) =>
                              CreateAssignment(contractId: '${contract['pn']}'),
                    ),
                  );
                },
                isFullWidth: true,
              ),
              SizedBox(height: 8),
              _buildStyledButton(
                text: 'اعادة بيع',
                color: Colors.green,
                icon: Icons.shopping_cart,
                onPressed:
                    () => _navigateToResaleContract(context, contract['pn']),
                isFullWidth: true,
              ),
              SizedBox(height: 8),
              _buildStyledButton(
                text: 'افراغ',
                color: Colors.red,
                icon: Icons.exit_to_app,
                onPressed:
                    () => _navigateWithAnimation(
                      context,
                      Aistlam(progect: contract['pn']),
                    ),
                isFullWidth: true,
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _buildStyledButton(
                      text: 'تنازل',
                      color: Colors.orange,
                      icon: Icons.assignment_turned_in,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => CreateAssignment(
                                  contractId: '${contract['pn']}',
                                ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildStyledButton(
                      text: 'اعادة بيع',
                      color: Colors.green,
                      icon: Icons.shopping_cart,
                      onPressed:
                          () => _navigateToResaleContract(
                            context,
                            contract['pn'],
                          ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildStyledButton(
                      text: 'افراغ',
                      color: Colors.red,
                      icon: Icons.exit_to_app,
                      onPressed:
                          () => _navigateWithAnimation(
                            context,
                            Aistlam(progect: contract['pn']),
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildResaleButtons(
    Map<String, dynamic> contract,
    BuildContext context,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 400;

        return Column(
          children: [
            if (isSmallScreen) ...[
              _buildStyledButton(
                text: 'تسوية مالية',
                color: Colors.blue,
                icon: Icons.account_balance,
                onPressed:
                    () => _navigateWithAnimation(
                      context,
                      FinancialSettlementContract(progect: contract['pn']),
                    ),
                isFullWidth: true,
              ),
              SizedBox(height: 8),
              _buildStyledButton(
                text: 'الغاء اعادة بيع',
                color: Colors.red,
                icon: Icons.cancel,
                onPressed: () => _handleCancelResale(contract, context),
                isFullWidth: true,
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _buildStyledButton(
                      text: 'تسوية مالية',
                      color: Colors.blue,
                      icon: Icons.account_balance,
                      onPressed:
                          () => _navigateWithAnimation(
                            context,
                            FinancialSettlementContract(
                              progect: contract['pn'],
                            ),
                          ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildStyledButton(
                      text: 'الغاء اعادة بيع',
                      color: Colors.red,
                      icon: Icons.cancel,
                      onPressed: () => _handleCancelResale(contract, context),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCompletedResaleButtons(
    Map<String, dynamic> contract,
    BuildContext context,
  ) {
    return _buildStyledButton(
      text: 'افراغ',
      color: Colors.red,
      icon: Icons.exit_to_app,
      onPressed:
          () =>
              _navigateWithAnimation(context, Aistlam(progect: contract['pn'])),
      isFullWidth: true,
    );
  }

  Widget _buildStyledButton({
    required String text,
    required Color color,
    required IconData icon,
    required VoidCallback onPressed,
    bool isFullWidth = false,
  }) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 12,
              offset: Offset(0, 6),
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.1),
              blurRadius: 1,
              offset: Offset(0, 1),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 18, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateWithAnimation(BuildContext context, Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: Duration(milliseconds: 500),
      ),
    );
  }

  void _navigateToResaleContract(BuildContext context, String contractId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ResaleContractFormPage(originalContractId: contractId),
      ),
    );
  }

  Future<void> _handleCancelResale(
    Map<String, dynamic> contract,
    BuildContext context,
  ) async {
    final editDeleteHelper = EditDeleteHelper();
    final shouldDelete = await editDeleteHelper.showDeleteConfirmationDialog(
      context,
      'الغاء عقد اعادة بيع',
    );
    String? userEmail = FirebaseAuth.instance.currentUser?.email;
    final rs = contract['pn'];

    if (shouldDelete) {
      final userType =
          Provider.of<AppAuthProvider>(context, listen: false).userType;
      await editDeleteHelper.createDeleteRequest(
        context: context,
        section: 'resale_contracts',
        itemId: contract['pn'],
        requesterName:
            FirebaseAuth.instance.currentUser?.displayName ?? 'مستخدم',
        requesterEmail: userEmail ?? '',
        details: 'طلب الغاء عقد إعادة البيع رقم ${contract['pn'] ?? ''}',
      );

      if (userType == 'مستر') {
        final contractDeleteHelper = ContractDeleteHelper();
        await contractDeleteHelper.deleteResaleContractByPn(rs, context);
      }
    }
  }

  Widget _buildContractDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildPaymentProgress(Map<String, dynamic> contract, String docId) {
    return FutureBuilder<List<QuerySnapshot>>(
      future: Future.wait([
        FirebaseFirestore.instance
            .collection('financialTransactions')
            .where('pn', isEqualTo: contract['pn'])
            .where('debitCredit', isEqualTo: 'له')
            .get(),
        FirebaseFirestore.instance
            .collection('financialTransactions')
            .where('pn', isEqualTo: contract['pn'])
            .where('debitCredit', isEqualTo: 'عليه')
            .get(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Text('حدث خطأ');
        }

        final paidDocs = snapshot.data![0].docs;
        final returnedDocs = snapshot.data![1].docs;

        final totalPaid = paidDocs.fold<double>(0.0, (sum, doc) {
          final amount =
              doc['amount'] is int
                  ? (doc['amount'] as int).toDouble()
                  : (doc['amount']?.toDouble() ?? 0.0);
          return sum + amount;
        });

        final totalReturned = returnedDocs.fold<double>(0.0, (sum, doc) {
          final amount =
              doc['amount'] is int
                  ? (doc['amount'] as int).toDouble()
                  : (doc['amount']?.toDouble() ?? 0.0);
          return sum + amount;
        });

        final netPaid = totalPaid;
        final total = contract['totalAmount']?.toDouble() ?? 1.0;
        final progress = netPaid / total;
        final percentage = (progress * 100).clamp(0, 100).toStringAsFixed(1);

        Color getBorderColor(String status) {
          switch (status) {
            case 'تحت الإنشاء':
              return Colors.orange;
            case 'تم التسليم':
              return Colors.green;
            case 'إعادة بيع':
              return Colors.blue;
            case 'تم التنازل':
              return const Color.fromARGB(255, 33, 219, 243);
            case 'تمت إعادة البيع':
              return Colors.red;
            default:
              return Colors.black;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('حالة السداد:'),
            SizedBox(height: 5),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress == 1
                            ? Colors.green
                            : Color.lerp(
                              getBorderColor(
                                contract['status'],
                              ).withOpacity(0.3),
                              getBorderColor(contract['status']),
                              progress,
                            )!,
                      ),
                      minHeight: 8,
                      semanticsLabel: 'Progress',
                      semanticsValue: '${(progress * 100).round()}%',
                    ),
                    Positioned.fill(
                      child: Center(
                        child: Text(
                          '${(progress * 100).round()}%',
                          style: TextStyle(
                            color: progress > 0.5 ? Colors.white : Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 5),
            Text(
              '$percentage% مدفوع (بعد الخصومات)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${netPaid.toStringAsFixed(2)} ر.س'), // الصافي
                Text('${total.toStringAsFixed(2)} ر.س'), // إجمالي العقد
              ],
            ),
            SizedBox(height: 5),
            PopupMenuButton(
              itemBuilder:
                  (context) => [
                    PopupMenuItem(value: 'edit', child: Text('تعديل')),
                    PopupMenuItem(value: 'delete', child: Text('حذف')),
                    PopupMenuItem(value: 'print', child: Text('طباعة العقد')),
                    PopupMenuItem(value: 'ef', child: Text('فراغ')),
                  ],
              onSelected: (value) async {
                String pn = contract['pn'];
                if (value == 'edit') {
                  _showEditContractDialog(contract, docId);
                } else if (value == 'delete') {
                  final authProvider = Provider.of<AppAuthProvider>(
                    context,
                    listen: false,
                  );
                  final editDeleteHelper = EditDeleteHelper();
                  final shouldDelete = await editDeleteHelper
                      .showDeleteConfirmationDialog(context, 'العقد');
                  String? userEmail = FirebaseAuth.instance.currentUser?.email;

                  if (shouldDelete) {
                    final userType =
                        Provider.of<AppAuthProvider>(
                          context,
                          listen: false,
                        ).userType;
                    if (userType == 'مستر') {
                      // حذف مباشر بدون إنشاء طلب
                      final contractDeleteHelper = ContractDeleteHelper();
                      final pn = contract['pn'];
                      if (pn != null && pn.toString().isNotEmpty) {
                        await contractDeleteHelper.cleanContractDataByPn(
                          pn,
                          context,
                        );
                        await FirebaseFirestore.instance
                            .collection('contracts')
                            .doc(docId)
                            .delete();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '✅ تم حذف العقد والبيانات المرتبطة به بنجاح',
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '❌ رقم العقد غير موجود، لا يمكن الحذف',
                            ),
                          ),
                        );
                      }
                    } else {
                      // مستخدم عادي: ينشأ طلب حذف فقط
                      await editDeleteHelper.createDeleteRequest(
                        context: context,
                        section: 'contracts',
                        itemId: docId,
                        requesterName: authProvider.username ?? 'مستخدم',
                        requesterEmail: userEmail ?? '',
                        details: 'طلب حذف العقد رقم ${contract['pn'] ?? ''}',
                      );
                    }
                  }
                }
                if (value == 'print') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Prinerer(contractId: docId),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('yyyy/MM/dd').format(date);
    } catch (e) {
      return dateString;
    }
  }

  void _showAddContractDialog() {
    showDialog(
      context: context,
      builder:
          (context) => ContractDialog(
            controller: _controller,
            onSave: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('تم حفظ العقد بنجاح')));
            },
          ),
    );
  }

  void _showEditContractDialog(
    Map<String, dynamic> contract,
    String docId,
  ) async {
    // التحقق من صلاحية المستخدم للتعديل
    final currentUser = FirebaseAuth.instance.currentUser;
    final userEmail = currentUser?.email ?? '';
    final editDeleteHelper = EditDeleteHelper();
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);

    final canEdit = await editDeleteHelper.canEditItem(userEmail);

    // إنشاء نموذج تعديل مبسط يحتوي على المبالغ ومدة استيفاء المبلغ والحقول الجديدة
    final paidAmountController = TextEditingController(
      text: (contract['paidAmount']?.toString() ?? '0'),
    );
    final totalAmountController = TextEditingController(
      text: (contract['totalAmount']?.toString() ?? '0'),
    );
    final paymentPeriodController = TextEditingController(
      text: (contract['paymentPeriod']?.toString() ?? '0'),
    );
    final deliveryMonthsController = TextEditingController(
      text: (contract['deliveryMonths']?.toString() ?? '0'),
    );
    final deliveryDaysController = TextEditingController(
      text: (contract['deliveryDays']?.toString() ?? '0'),
    );
    final phoneNumberController = TextEditingController(
      text: (contract['clientData']?['phoneNumber']?.toString() ?? ''),
    );

    // حفظ البيانات الأصلية للعقد لاستخدامها في تحديث جدول العمليات المالية
    final originalPaidAmount = contract['paidAmount'] ?? 0;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('تعديل العقد'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'رقم العقد: ${contract['pn'] ?? ''}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'العميل: ${contract['clientName'] ?? ''}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: paidAmountController,
                    decoration: InputDecoration(
                      labelText: 'المبلغ المدفوع',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: totalAmountController,
                    decoration: InputDecoration(
                      labelText: 'المبلغ الإجمالي',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: paymentPeriodController,
                    decoration: InputDecoration(
                      labelText: 'مدة استيفاء المبلغ (بالأشهر)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: deliveryMonthsController,
                    decoration: InputDecoration(
                      labelText: 'أشهر التسليم',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: deliveryDaysController,
                    decoration: InputDecoration(
                      labelText: 'أيام التسليم',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: phoneNumberController,
                    decoration: InputDecoration(
                      labelText: 'رقم جوال العميل',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
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
                  // تحويل القيم إلى أرقام
                  final double newPaidAmount =
                      double.tryParse(paidAmountController.text) ?? 0;
                  final double newTotalAmount =
                      double.tryParse(totalAmountController.text) ?? 0;
                  final int newPaymentPeriod =
                      int.tryParse(paymentPeriodController.text) ?? 0;
                  final int newDeliveryMonths =
                      int.tryParse(deliveryMonthsController.text) ?? 0;
                  final int newDeliveryDays =
                      int.tryParse(deliveryDaysController.text) ?? 0;
                  final String newPhoneNumber =
                      phoneNumberController.text.trim();

                  // إنشاء بيانات التعديل
                  final Map<String, dynamic> newData = {
                    'paidAmount': newPaidAmount,
                    'totalAmount': newTotalAmount,
                    'paymentPeriod': newPaymentPeriod,
                    'deliveryMonths': newDeliveryMonths,
                    'deliveryDays': newDeliveryDays,
                    'clientData.phoneNumber': newPhoneNumber,
                  };

                  Navigator.pop(context);

                  if (canEdit) {
                    // إذا كان المستخدم هو المستر، يمكنه التعديل مباشرة
                    await FirebaseFirestore.instance
                        .collection('contracts')
                        .doc(docId)
                        .update(newData);

                    // تحديث جدول العمليات المالية (تعديل وليس إضافة)
                    if (newPaidAmount != originalPaidAmount) {
                      // إضافة سجل في جدول العمليات المالية يوضح التعديل
                      await FirebaseFirestore.instance
                          .collection('financial_transactions')
                          .add({
                            'contractId': docId,
                            'contractNumber': contract['pn'],
                            'clientName': contract['clientName'],
                            'type': 'تعديل',
                            'amount':
                                newPaidAmount -
                                originalPaidAmount, // الفرق بين المبلغين
                            'notes':
                                'تعديل المبلغ المدفوع من $originalPaidAmount إلى $newPaidAmount',
                            'timestamp': FieldValue.serverTimestamp(),
                            'userId': userEmail,
                          });
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تم تحديث العقد بنجاح')),
                    );
                  } else {
                    // إنشاء طلب موافقة للتعديل
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('سيتم إرسال طلب للموافقة على التعديل'),
                      ),
                    );

                    await editDeleteHelper.createEditRequest(
                      context: context,
                      section: 'contracts',
                      itemId: docId,
                      requesterName: authProvider.username ?? 'مستخدم',
                      requesterEmail: userEmail,
                      details: 'طلب تعديل العقد رقم ${contract['pn'] ?? ''}',
                      newData: newData, // إرسال بيانات التعديل مع الطلب
                    );
                  }
                },
                child: Text('حفظ'),
              ),
            ],
          ),
    );
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('الرجاء إدخال نص للبحث')));
      return;
    }

    setState(() {
      // تحديث واجهة المستخدم لإظهار أننا نبحث
      colorss = !colorss; // تغيير حالة لإعادة بناء الواجهة
    });

    // تعديل تدفق البيانات في وحدة التحكم للبحث
    _controller.searchQuery = query.trim();

    // إظهار رسالة للمستخدم
  }

  void _handleContractAction(
    String action,
    Map<String, dynamic> contract,
    BuildContext context,
  ) {
    // Handle contract actions here
    switch (action) {
      case 'print':
        _printContract(contract);
        break;
      case 'edit':
        // Handle edit action
        break;
      case 'delete':
        // Handle delete action
        break;
    }
  }

  void _printContract(Map<String, dynamic> contract) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Prinerer(contractId: contract['id']),
      ),
    );
  }
}

class _ContractCard extends StatefulWidget {
  final Map<String, dynamic> contract;
  final String docId;
  final Color borderColor;
  final Function(String) onActionButtonPressed;

  const _ContractCard({
    Key? key,
    required this.contract,
    required this.docId,
    required this.borderColor,
    required this.onActionButtonPressed,
  }) : super(key: key);

  @override
  _ContractCardState createState() => _ContractCardState();
}

class _ContractCardState extends State<_ContractCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: widget.borderColor.withOpacity(0.12),
            blurRadius: 20,
            offset: Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Color(0xFF64748B).withOpacity(0.06),
            blurRadius: 8,
            offset: Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: widget.borderColor.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Minimized Card Content
            _buildMinimizedCard(),
            // Expanded Content
            SizeTransition(
              sizeFactor: _expandAnimation,
              child: _buildExpandedContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimizedCard() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return InkWell(
      onTap: _toggleExpansion,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, widget.borderColor.withOpacity(0.02)],
          ),
        ),
        child: Row(
          children: [
            // Contract Icon
            Container(
              padding: EdgeInsets.all(isMobile ? 8 : 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.borderColor.withOpacity(0.15),
                    widget.borderColor.withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                border: Border.all(
                  color: widget.borderColor.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.borderColor.withOpacity(0.15),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.description_rounded,
                color: widget.borderColor,
                size: isMobile ? 18 : 22,
              ),
            ),
            SizedBox(width: isMobile ? 8 : 12),
            // Contract Info
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.contract['clientName'] ?? 'غير محدد',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: isMobile ? 2 : 4),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 4 : 6,
                      vertical: isMobile ? 1 : 2,
                    ),
                    decoration: BoxDecoration(
                      color: widget.borderColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(isMobile ? 4 : 6),
                    ),
                    child: Text(
                      'عقد رقم: ${widget.contract['pn'] ?? '0'}',
                      style: TextStyle(
                        fontSize: isMobile ? 9 : 11,
                        color: widget.borderColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: isMobile ? 4 : 8),
            // Options Menu (Print)
            if (isMobile)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Prinerer(contractId: widget.docId),
                    ),
                  );
                },
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF3B82F6).withOpacity(0.3),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.print_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              )
            else
              Container(
                child: PopupMenuButton(
                  icon: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF3B82F6).withOpacity(0.3),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.more_vert_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: Color(0xFF64748B).withOpacity(0.2),
                  itemBuilder:
                      (context) => [
                        PopupMenuItem(
                          value: 'print',
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF3B82F6).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.print_rounded,
                                    color: Color(0xFF3B82F6),
                                    size: 20,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'طباعة العقد',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                  onSelected: (value) {
                    if (value == 'print') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => Prinerer(contractId: widget.docId),
                        ),
                      );
                    }
                  },
                  tooltip: 'خيارات العقد',
                ),
              ),
            SizedBox(width: isMobile ? 4 : 8),
            // Status Badge
            Flexible(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 6 : 8,
                  vertical: isMobile ? 4 : 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.borderColor,
                      widget.borderColor.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
                  boxShadow: [
                    BoxShadow(
                      color: widget.borderColor.withOpacity(0.4),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  widget.contract['status'] ?? 'تحت الانشاء',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 8 : 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            SizedBox(width: 12),
            // Expand/Collapse Icon
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.borderColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.borderColor.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: AnimatedRotation(
                turns: _isExpanded ? 0.5 : 0,
                duration: Duration(milliseconds: 300),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: widget.borderColor,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedContent() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(
          top: BorderSide(
            color: widget.borderColor.withOpacity(0.15),
            width: 1.5,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contract Details Section
            _buildDetailSection(),
            SizedBox(height: 20),
            // Action Buttons Section
            _buildActionButtonsSection(),
            SizedBox(height: 20),
            // Payment Progress Section
            _buildPaymentProgressSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF64748B).withOpacity(0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.info_rounded, color: Colors.white, size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'تفاصيل العقد',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildCompactDetailRow(
            'المشروع',
            widget.contract['projectNumber'] ?? '',
            Icons.business_rounded,
            Color(0xFF10B981),
          ),
          _buildCompactDetailRow(
            'الوحدة',
            widget.contract['unitNumber'] ?? '',
            Icons.home_rounded,
            Color(0xFFF59E0B),
          ),
          _buildCompactDetailRow(
            'اتجاه الوحدة',
            widget.contract['unitDirection'] ??
                widget.contract['direction'] ??
                'غير محدد',
            Icons.explore_rounded,
            Color(0xFFEF4444),
          ),
          _buildCompactDetailRow(
            'التاريخ',
            _formatDate(widget.contract['dateGregorian']) ?? '',
            Icons.calendar_today_rounded,
            Color(0xFF8B5CF6),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDetailRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.06), color.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.2), color.withOpacity(0.15)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtonsSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Color(0xFFF8FAFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF64748B).withOpacity(0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF3B82F6).withOpacity(0.15),
                      Color(0xFF1E40AF).withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.settings_rounded,
                  color: Color(0xFF3B82F6),
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'الإجراءات',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Use the original _buildActionButtons method from ContractsPage0
          Builder(
            builder: (context) {
              // Find the parent ContractsPage0 to access its methods
              final contractsPage =
                  context.findAncestorStateOfType<_ContractsPageState>();
              if (contractsPage != null) {
                return contractsPage._buildActionButtons(
                  widget.contract,
                  context,
                );
              }
              return SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentProgressSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Color(0xFFF0FDF4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFFDCFCE7), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF10B981).withOpacity(0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF10B981).withOpacity(0.15),
                      Color(0xFF059669).withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.payment_rounded,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'حالة الدفع',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Use the original _buildPaymentProgress method from ContractsPage0
          Builder(
            builder: (context) {
              // Find the parent ContractsPage0 to access its methods
              final contractsPage =
                  context.findAncestorStateOfType<_ContractsPageState>();
              if (contractsPage != null) {
                return contractsPage._buildPaymentProgress(
                  widget.contract,
                  widget.docId,
                );
              }
              return SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  String? _formatDate(dynamic date) {
    if (date == null) return null;
    // Implement date formatting logic
    return date.toString();
  }
}

class ContractController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> projects = [];
  final Map<String, String> unitStatuses = {};
  List<String> units = [];
  Map<String, dynamic> currentContract = {};
  String _searchQuery = '';

  String get searchQuery => _searchQuery;
  set searchQuery(String value) {
    _searchQuery = value;
  }

  Stream<QuerySnapshot> get contractsStream {
    if (_searchQuery.isEmpty) {
      return _firestore.collection('contracts').snapshots();
    } else {
      // محاولة البحث برقم العقد أولاً
      return searchContracts(_searchQuery);
    }
  }

  Stream<QuerySnapshot> searchContracts(String query) {
    // تحقق ما إذا كان الاستعلام رقمًا بسيطًا (للبحث عن رقم العقد pn)
    if (RegExp(r'^\d+$').hasMatch(query)) {
      return _firestore
          .collection('contracts')
          .where('pn', isEqualTo: query)
          .snapshots();
    }
    // تحقق ما إذا كان الاستعلام يحتوي على رقم عقد مثل "119-11"
    else if (RegExp(r'^\d+-\d+$').hasMatch(query)) {
      return _firestore
          .collection('contracts')
          .where('pn', isEqualTo: query)
          .snapshots();
    }
    // تحقق ما إذا كان الاستعلام يحتوي على أرقام وحروف (للبحث في حقل pn)
    else if (RegExp(r'[0-9]').hasMatch(query)) {
      return _firestore
          .collection('contracts')
          .where('pn', isGreaterThanOrEqualTo: query)
          .where('pn', isLessThanOrEqualTo: '$query\uf8ff')
          .snapshots();
    }
    // البحث حسب اسم العميل
    else {
      return _firestore
          .collection('contracts')
          .where('clientName', isGreaterThanOrEqualTo: query)
          .where('clientName', isLessThanOrEqualTo: '$query\uf8ff')
          .snapshots();
    }
  }

  void init() async {
    await _loadProjects();
  }

  Future<void> _loadProjects() async {
    final snapshot = await _firestore.collection('apartments').get();
    projects =
        snapshot.docs
            .map((doc) => doc['projectNumber'].toString())
            .toSet()
            .toList();
  }

  Future<void> loadUnits(String project) async {
    try {
      if (project.isEmpty) {
        units.clear();
        unitStatuses.clear();
        return;
      }

      final snapshot =
          await _firestore
              .collection('apartments')
              .where('projectNumber', isEqualTo: project)
              .get();

      units.clear();
      unitStatuses.clear();

      for (var doc in snapshot.docs) {
        final number = doc['number']?.toString() ?? '';
        if (number.isNotEmpty) {
          final status = doc['status']?.toString() ?? 'غير متاح';
          units.add(number);
          unitStatuses[number] = status;
        }
      }

      // ترتيب الوحدات
      units.sort((a, b) {
        final numA = int.tryParse(a) ?? 0;
        final numB = int.tryParse(b) ?? 0;
        return numA.compareTo(numB);
      });
    } catch (e) {
      print('Error loading units: $e');
      units.clear();
      unitStatuses.clear();
      // إظهار رسالة خطأ للمستخدم
    }
  }

  Future<void> saveContract(Map<String, dynamic> data, {String? docId}) async {
    try {
      // جلب بيانات العميل
      final clientSnapshot =
          await _firestore
              .collection('customers')
              .where('identityNumber', isEqualTo: data['identityNumber'])
              .limit(1)
              .get();

      // جلب بيانات الوحدة
      final unitSnapshot =
          await _firestore
              .collection('apartments')
              .where('projectNumber', isEqualTo: data['projectNumber'])
              .where('number', isEqualTo: data['unitNumber'])
              .limit(1)
              .get();

      if (unitSnapshot.docs.isEmpty) {
        throw 'الوحدة غير موجودة';
      }
      final now = DateTime.now();
      final formattedDate =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

      final unitData = unitSnapshot.docs.first.data();
      final unitRef = unitSnapshot.docs.first.reference;

      // التحقق من عدم وجود عقد سابق مرتبط بنفس pn
      final existingContractWithPn =
          await _firestore
              .collection('contracts')
              .where('pn', isEqualTo: unitData['pn'])
              .get();

      if (existingContractWithPn.docs.isNotEmpty && docId == null) {
        throw 'رقم العقد مستخدم مسبقًا ولا يمكن تكراره';
      }

      // دمج بيانات العميل
      if (clientSnapshot.docs.isNotEmpty) {
        final clientData = clientSnapshot.docs.first.data();
        final clientRef = clientSnapshot.docs.first.reference;

        data.addAll({'clientData': clientData});

        // إضافة رقم العقد (pn) إلى جدول العملاء كمصفوفة
        // التحقق مما إذا كان لدى العميل مصفوفة عقود موجودة بالفعل
        final customerDoc = await clientRef.get();
        final customerData = customerDoc.data() as Map<String, dynamic>;

        List<String> contractNumbers = [];
        if (customerData.containsKey('contractNumbers') &&
            customerData['contractNumbers'] is List) {
          contractNumbers = List<String>.from(customerData['contractNumbers']);
        }

        // إضافة رقم العقد الجديد إذا لم يكن موجودًا بالفعل
        if (!contractNumbers.contains(unitData['pn'])) {
          contractNumbers.add(unitData['pn']);
        }

        // تحديث وثيقة العميل بمصفوفة العقود
        await clientRef.update({'contractNumbers': contractNumbers});

        // تحديث الوحدة بحقول إضافية
        await unitRef.update({
          'status': 'مباع',
          'totalAmount': data['totalAmount'],
          'tot': data['paidAmount'],
          'تاريخ العقد تحت الانشاء': formattedDate,
          'clientName': clientData['name'],
          'clientIdentity': clientData['identityNumber'],
          'clientPhone': clientData['phone'],
        });

        // حفظ العملية المالية للمبلغ الكلي فقط (بدون المبلغ المدفوع)
        if (data['totalAmount'] != null && data['totalAmount'] > 0) {
          await _firestore.collection('financialTransactions').add({
            'date': Timestamp.fromDate(now),
            'pn': unitData['pn'],
            'customerName': clientData['name'],
            'amount': data['totalAmount'],
            'cod':
                '${data['pn'] ?? ''}${data['projectNumber'] ?? ''}' != ''
                    ? '${data['pn'] ?? ''}${data['projectNumber'] ?? ''}'
                    : '11111',
            'debitCredit': 'عليه', // تسجيل كله على العميل
            'idNumber': clientData['identityNumber'],
            'unitNumber': data['unitNumber'],
            'description': 'قيمة توقيع العقد  ${unitData['pn']}',
            'projectNumber': data['projectNumber'],
            'transactionType': 'عقد بيع',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // دمج بيانات الوحدة
      data.addAll({
        'unitData': unitData,
        'pn': unitData['pn'], // رقم العقد
      });

      data['remainingAmount'] =
          (data['totalAmount'] ?? 0) - (data['paidAmount'] ?? 0);

      // استخدام التاريخ المختار من المستخدم أو التاريخ الحالي كافتراضي
      DateTime contractDate;
      if (data.containsKey('contractDate') && data['contractDate'] != null) {
        contractDate = DateTime.parse(data['contractDate']);
      } else {
        contractDate = DateTime.now();
      }

      data['dateGregorian'] = contractDate.toIso8601String();
      data['dateHijri'] = DateFormat('dd-MM-yyyy').format(contractDate);

      // حفظ أو تحديث العقد
      if (docId != null) {
        await _firestore.collection('contracts').doc(docId).update(data);
      } else {
        await _firestore.collection('contracts').add(data);
      }
    } catch (e) {
      print('Error saving contract: $e');
      throw 'فشل في حفظ العقد: $e';
      // تسجيل الخطأ في سجل النظام
      await logAction(
        category: 'أخطاء',
        action: 'فشل في حفظ العقد',
        itemId: data['pn'] ?? '',
        userId: FirebaseAuth.instance.currentUser?.email ?? 'غير معروف',
        oldData: {},
        newData: {'error': e.toString()},
      );
    }
  }

  Future<void> cancelContract(Map<String, dynamic> data) async {
    try {
      // جلب بيانات العميل
      final clientSnapshot =
          await _firestore
              .collection('customers')
              .where('identityNumber', isEqualTo: data['identityNumber'])
              .limit(1)
              .get();

      // جلب بيانات الوحدة
      final unitSnapshot =
          await _firestore
              .collection('apartments')
              .where('projectNumber', isEqualTo: data['projectNumber'])
              .where('number', isEqualTo: data['unitNumber'])
              .limit(1)
              .get();

      if (unitSnapshot.docs.isEmpty) {
        throw 'الوحدة غير موجودة';
      }

      final unitRef = unitSnapshot.docs.first.reference;
      final unitData = unitSnapshot.docs.first.data();

      final String pn = unitData['pn'];

      // تحديث الوحدة: حذف الحقول وتغيير الحالة إلى "متاح"
      await unitRef.update({
        'status': 'متاح',
        'totalAmount': FieldValue.delete(),
        'tot': FieldValue.delete(),
        'تاريخ العقد تحت الانشاء': FieldValue.delete(),
        'clientName': FieldValue.delete(),
        'clientIdentity': FieldValue.delete(),
        'clientPhone': FieldValue.delete(),
      });

      // تعديل بيانات العميل وحذف رقم العقد من القائمة
      if (clientSnapshot.docs.isNotEmpty) {
        final clientRef = clientSnapshot.docs.first.reference;
        final customerDoc = await clientRef.get();
        final customerData = customerDoc.data() as Map<String, dynamic>;

        if (customerData.containsKey('contractNumbers')) {
          List<String> contractNumbers = List<String>.from(
            customerData['contractNumbers'],
          );
          contractNumbers.remove(pn);

          await clientRef.update({'contractNumbers': contractNumbers});
        }
      }

      // حذف العمليات المالية المرتبطة برقم العقد
      final financialSnapshot =
          await _firestore
              .collection('financialTransactions')
              .where('pn', isEqualTo: pn)
              .get();

      for (var doc in financialSnapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('حدث خطأ أثناء إلغاء العقد: $e');
      rethrow;
    }
  }

  Future<void> deleteContract(String docId, BuildContext context) async {
    try {
      // جلب بيانات العقد
      final contractDoc =
          await _firestore.collection('contracts').doc(docId).get();

      if (!contractDoc.exists) {
        throw Exception('العقد غير موجود');
      }

      final contractData = contractDoc.data()!;
      final String? pn = contractData['pn'];

      // حذف ارتباط الوكالات بالعقد
      if (pn != null) {
        // 1. البحث عن جميع الوكالات المرتبطة بالعقد
        final agenciesSnapshot =
            await _firestore
                .collection('agencies')
                .where('usedIn', arrayContains: pn)
                .get();

        // 2. تحديث كل وكالة لإزالة العقد من قائمة usedIn
        for (var agencyDoc in agenciesSnapshot.docs) {
          await _firestore.collection('agencies').doc(agencyDoc.id).update({
            'usedIn': FieldValue.arrayRemove([pn]),
          });
        }

        // 3. حذف سجلات استخدام الوكالات المرتبطة بهذا العقد
        final agencyUsagesSnapshot =
            await _firestore
                .collection('agencyUsages')
                .where('contractId', isEqualTo: pn)
                .get();

        for (var usageDoc in agencyUsagesSnapshot.docs) {
          await usageDoc.reference.delete();
        }
      }

      // متابعة عملية الحذف الأصلية
      final String? identityNumber =
          contractData['clientData']?['identityNumber'];
      final String? projectNumber = contractData['projectNumber'];
      final String? unitNumber = contractData['unitNumber'];

      // التحقق من وجود البيانات المطلوبة لإلغاء العقد
      if (pn == null ||
          identityNumber == null ||
          projectNumber == null ||
          unitNumber == null) {
        throw Exception('بيانات العقد غير مكتملة، لا يمكن إلغاؤه بشكل صحيح');
      }

      // إظهار رسالة تأكيد للمستخدم
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text('تأكيد حذف العقد'),
              content: Text('هل أنت متأكد أنك تريد حذف هذا العقد؟'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('نعم، احذف'),
                ),
              ],
            ),
      );

      if (confirmed != true) {
        return; // المستخدم لغى الحذف
      }

      // استدعاء دالة إلغاء العقد لتحديث الجداول المرتبطة
      await cancelContract({
        'identityNumber': identityNumber,
        'projectNumber': projectNumber,
        'unitNumber': unitNumber,
      });

      // حذف العقد نفسه من جدول العقود
      await _firestore.collection('contracts').doc(docId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حذف العقد وفك ارتباط الوكالات بنجاح ✅')),
      );
    } catch (e) {
      print('خطأ في حذف العقد: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء حذف العقد: $e')));
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getClientInfo(String idNumber) async {
    final snapshot =
        await _firestore
            .collection('customers')
            .where('identityNumber', isEqualTo: idNumber)
            .get();
    return snapshot.docs.isNotEmpty ? snapshot.docs.first.data() : null;
  }

  void dispose() {
    // Clean up if needed
  }
}

class ContractDialog extends StatefulWidget {
  final ContractController controller;
  final Map<String, dynamic>? contract;
  final String? docId;
  final VoidCallback onSave;

  const ContractDialog({
    super.key,
    required this.controller,
    this.contract,
    this.docId,
    required this.onSave,
  });

  @override
  _ContractDialogState createState() => _ContractDialogState();
}

class _ContractDialogState extends State<ContractDialog> {
  final _formKey = GlobalKey<FormState>();
  late String? _selectedProject;
  late String? _selectedUnit;
  final _identityController = TextEditingController();
  final _contractNumberController = TextEditingController();
  final _paidController = TextEditingController();
  final _totalController = TextEditingController();
  final _monthsController = TextEditingController();
  final _daysController = TextEditingController();
  final List<String> contractStatuses = [
    'تحت الإنشاء',
    'تم التسليم',
    'إعادة بيع',
    'تمت إعادة البيع',
    'تم الافراغ',
  ];

  late String selectedStatus = 'تحت الإنشاء';
  String _clientName = '';
  String _direction = '';
  String deedNumber = '';
  String descriptionU = '';
  String district = '';
  String city = '';
  String planNumber = '';
  String regionNumber = '';
  String statusU = '';
  String nameC = '';
  String tybe = '';
  bool _isLoading = false;
  String pn = '';
  DateTime _selectedDate = DateTime.now(); // تاريخ اليوم كقيمة افتراضية

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    if (widget.contract != null) {
      _selectedProject = widget.contract!['projectNumber'];
      _selectedUnit = widget.contract!['unitNumber'];
      _identityController.text = widget.contract!['name'] ?? '';
      _contractNumberController.text = widget.contract!['contractNumber'] ?? '';
      _paidController.text = (widget.contract!['paidAmount'] ?? 0).toString();
      _totalController.text = (widget.contract!['totalAmount'] ?? 0).toString();
      _monthsController.text =
          (widget.contract!['deliveryMonths'] ?? 0).toString();
      _daysController.text = (widget.contract!['deliveryDays'] ?? 0).toString();
      _clientName = widget.contract!['name'] ?? '';
      _direction = widget.contract!['direction'] ?? '';
      nameC = widget.contract!['identityNumber'] ?? '';
      planNumber = widget.contract!['planNumber'] ?? '';
      city = widget.contract!['city'] ?? '';
      regionNumber = widget.contract!['regionNumber'] ?? '';
      district = widget.contract!['district'] ?? '';
      descriptionU = widget.contract!['description'] ?? '';
      deedNumber = widget.contract!['deedNumber'] ?? '';

      // تحديد التاريخ من العقد الموجود أو استخدام تاريخ اليوم
      if (widget.contract!['contractDate'] != null) {
        try {
          _selectedDate = DateTime.parse(widget.contract!['contractDate']);
        } catch (e) {
          _selectedDate = DateTime.now();
        }
      } else {
        _selectedDate = DateTime.now();
      }

      // التحقق من أن حالة العقد موجودة في قائمة الحالات المتاحة قبل تعيينها
      String contractStatus = widget.contract!['status'] ?? 'تحت الإنشاء';
      if (contractStatuses.contains(contractStatus)) {
        selectedStatus = contractStatus;
      } else {
        selectedStatus = 'تحت الإنشاء';
      }
    } else {
      _selectedProject = null;
      _selectedUnit = null;
      _selectedDate = DateTime.now(); // تاريخ اليوم للعقود الجديدة
    }
  }

  Future<void> _loadClientInfo() async {
    if (_identityController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      // البحث عن العميل إما برقم الهوية أو بالاسم
      final searchText = _identityController.text.trim();
      QuerySnapshot clientSnapshot;

      // التحقق ما إذا كان النص المدخل رقمًا (للبحث برقم الهوية) أو نصًا (للبحث بالاسم)
      if (RegExp(r'^\d+$').hasMatch(searchText)) {
        // البحث برقم الهوية
        clientSnapshot =
            await FirebaseFirestore.instance
                .collection('customers')
                .where('identityNumber', isEqualTo: searchText)
                .limit(1)
                .get();
      } else {
        // البحث باسم العميل
        clientSnapshot =
            await FirebaseFirestore.instance
                .collection('customers')
                .where('name', isGreaterThanOrEqualTo: searchText)
                .where('name', isLessThanOrEqualTo: '$searchText\uf8ff')
                .limit(5)
                .get();
      }

      if (clientSnapshot.docs.isNotEmpty) {
        final client = clientSnapshot.docs.first.data() as Map<String, dynamic>;
        setState(() {
          _clientName = client['name'] ?? 'غير معروف';
          // إذا كان البحث بالاسم، قم بتحديث حقل رقم الهوية
          if (!RegExp(r'^\d+$').hasMatch(searchText)) {
            _identityController.text = client['identityNumber'] ?? '';
          }
        });
      } else {
        setState(() => _clientName = '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('لا يوجد عميل بهذا الرقم أو الاسم')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء جلب بيانات العميل: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUnitDetails() async {
    if (_selectedProject == null || _selectedUnit == null) return;

    setState(() => _isLoading = true);
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('apartments')
              .where('projectNumber', isEqualTo: _selectedProject)
              .where('number', isEqualTo: _selectedUnit)
              .get();

      if (snapshot.docs.isNotEmpty) {
        final unitData = snapshot.docs.first.data();
        setState(() {
          _direction = unitData['direction'] ?? '';
          // يمكنك هنا تعيين أي بيانات إضافية تريد عرضها في الواجهة
        });
      }
    } catch (e) {
      print('Error loading unit details: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitForm() async {
    final username =
        Provider.of<AppAuthProvider>(context, listen: false).username;

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // تجهيز بيانات العقد
        final contractData = {
          'projectNumber': _selectedProject,
          'unitNumber': _selectedUnit,
          'direction': _direction,
          'clientName': _clientName,
          'status': selectedStatus,
          'identityNumber': _identityController.text.trim(),
          'contractNumber': _contractNumberController.text.trim(),
          'paidAmount': double.tryParse(_paidController.text.trim()) ?? 0,
          'totalAmount': double.tryParse(_totalController.text.trim()) ?? 0,
          'deliveryMonths': int.tryParse(_monthsController.text.trim()) ?? 0,
          'deliveryDays': int.tryParse(_daysController.text.trim()) ?? 0,
          'contractDate':
              _selectedDate.toIso8601String(), // إضافة التاريخ المحدد
        };

        // التحقق من صلاحية المستخدم للتعديل
        final currentUser = FirebaseAuth.instance.currentUser;
        final userEmail = currentUser?.email ?? '';
        final editDeleteHelper = EditDeleteHelper();
        final canEdit = await editDeleteHelper.canEditItem(userEmail);

        if (canEdit || widget.contract == null) {
          // حفظ بيانات العقد في Firestore مباشرة إذا كان المستخدم مخولاً أو إذا كان عقداً جديداً
          await widget.controller.saveContract(
            contractData,
            docId: widget.docId,
          );

          // تسجيل الحدث في سجل العمليات
          await logAction(
            category: 'عقد تحت الانشاء',
            action: widget.contract == null ? 'إضافة عقد جديد' : 'تعديل العقد',
            itemId: '$_selectedProject-$_selectedUnit',
            userId: username.toString(),
            oldData: {'status': 'متاح'},
            newData: {'status': selectedStatus},
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.contract == null
                    ? 'تم إضافة العقد بنجاح'
                    : 'تم تحديث العقد بنجاح',
              ),
            ),
          );
        } else {
          // إرسال طلب التعديل للموافقة إذا لم يكن المستخدم مخولاً
          await editDeleteHelper.createEditRequest(
            context: context,
            section: 'contracts',
            itemId: widget.docId!,
            requesterName: username ?? 'مستخدم',
            requesterEmail: userEmail,
            details: 'طلب تعديل العقد رقم ${widget.contract!['pn'] ?? ''}',
            newData: contractData,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إرسال طلب التعديل للموافقة')),
          );
        }

        widget.onSave(); // استدعاء الدالة بعد الحفظ
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  @override
  void dispose() {
    _identityController.dispose();
    _contractNumberController.dispose();
    _paidController.dispose();
    _totalController.dispose();
    _monthsController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.contract == null ? 'إضافة عقد جديد' : 'تعديل العقد'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedProject,
                hint: Text('اختر المشروع'),
                items:
                    widget.controller.projects
                        .map(
                          (project) => DropdownMenuItem(
                            value: project,
                            child: Text(project),
                          ),
                        )
                        .toList(),
                onChanged: (value) async {
                  setState(() {
                    _selectedProject = value;
                    _selectedUnit = null;
                    widget.controller.units = []; // تفريغ الوحدات مؤقتًا
                  });

                  await widget.controller.loadUnits(
                    value!,
                  ); // انتظر تحميل الوحدات

                  setState(() {}); // أعد البناء بعد انتهاء التحميل
                },

                validator:
                    (value) => value == null ? 'يجب اختيار المشروع' : null,
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedUnit,
                hint: Text('اختر الوحدة'),
                items:
                    widget.controller.units.map((unit) {
                      final colorsin1 = widget.controller.unitStatuses[unit];
                      Color getCardColor(String colorsin) {
                        switch (colorsin) {
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

                      final isAvailable =
                          widget.controller.unitStatuses[unit] == 'متاح';
                      final isAvailable1 =
                          widget.controller.unitStatuses[unit] == 'مباع';
                      return DropdownMenuItem<String>(
                        value: unit,
                        child: Row(
                          children: [
                            Icon(
                              Icons.circle,
                              color: getCardColor(colorsin1.toString()),
                              size: 12,
                            ),
                            SizedBox(width: 8),
                            Text(unit),
                            SizedBox(width: 8),
                            Text(
                              '(${widget.controller.unitStatuses[unit] ?? 'غير معروف'})',
                              style: TextStyle(
                                color: getCardColor(colorsin1.toString()),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() => _selectedUnit = value);
                  _loadUnitDetails();
                },
                validator:
                    (value) => value == null ? 'يجب اختيار الوحدة' : null,
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: const InputDecoration(labelText: 'حالة العقد'),
                items:
                    contractStatuses.map((status) {
                      return DropdownMenuItem<String>(
                        value: status,
                        child: Text(status),
                      );
                    }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedStatus = value;
                    });
                  }
                },
              ),

              TextFormField(
                controller: _identityController,
                decoration: InputDecoration(
                  labelText: 'رقم الهوية أو اسم العميل',
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search),
                    onPressed: _loadClientInfo,
                  ),
                ),
                onChanged: (value) {
                  setState(() {});
                  if (value.isNotEmpty) {
                    // تشغيل البحث تلقائيًا عند إدخال أي حرف
                    _loadClientInfo();
                  }
                },
                validator:
                    (value) =>
                        value!.isEmpty
                            ? 'يجب إدخال رقم الهوية أو اسم العميل'
                            : null,
              ),
              SizedBox(height: 8),
              if (_clientName.isNotEmpty)
                Text(
                  'اسم العميل: $_clientName',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              SizedBox(height: 16),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _paidController,
                      decoration: InputDecoration(labelText: 'المبلغ المدفوع'),
                      keyboardType: TextInputType.number,
                      validator:
                          (value) => value!.isEmpty ? 'يجب إدخال المبلغ' : null,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _totalController,
                      decoration: InputDecoration(labelText: 'المبلغ الكلي'),
                      keyboardType: TextInputType.number,
                      validator:
                          (value) => value!.isEmpty ? 'يجب إدخال المبلغ' : null,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _monthsController,
                      decoration: InputDecoration(labelText: 'أشهر التسليم'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _daysController,
                      decoration: InputDecoration(
                        labelText: 'أيام استيفاء المبلغ',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              // حقل اختيار التاريخ
              InkWell(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    locale: const Locale('ar', 'SA'),
                  );
                  if (picked != null && picked != _selectedDate) {
                    setState(() {
                      _selectedDate = picked;
                    });
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'تاريخ العقد: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: TextStyle(fontSize: 16),
                      ),
                      Icon(Icons.calendar_today, color: Colors.grey[600]),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              if (_direction.isNotEmpty)
                Text(
                  'اتجاه الوحدة: $_direction',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          child: Text('إلغاء'),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitForm,
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
