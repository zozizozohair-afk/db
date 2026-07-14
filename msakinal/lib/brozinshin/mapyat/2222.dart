import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ContractsPage extends StatefulWidget {
  const ContractsPage({super.key});

  @override
  _ContractsPageState createState() => _ContractsPageState();
}

class _ContractsPageState extends State<ContractsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _allContracts = [];
  List<Map<String, dynamic>> _filteredContracts = [];

  @override
  void initState() {
    super.initState();
    _loadContracts();
  }

  Future<void> _loadContracts() async {
    try {
      // جلب جميع العقود من الجداول المختلفة
      final contracts = await _getMergedContracts();
      setState(() {
        _allContracts = contracts;
        _filteredContracts = contracts;
        _isLoading = false;
      });
    } catch (e) {
      print(e);
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ في جلب البيانات: ${e.toString()}')),

      );
    }
  }

  Future<List<Map<String, dynamic>>> _getMergedContracts() async {
    List<Map<String, dynamic>> allContracts = [];

    // جلب عقود تحت الإنشاء
    final contractsSnapshot = await _firestore.collection('contracts').get();
    for (var doc in contractsSnapshot.docs) {
      allContracts.add({
        'type': 'عقد تحت الإنشاء',
        'data': doc.data(),
        'timestamp':  Timestamp.now(),
      });
    }

    // جبل عقود إعادة البيع
    final resaleSnapshot = await _firestore.collection('resale_contracts').get();
    for (var doc in resaleSnapshot.docs) {
      allContracts.add({
        'type': 'عقد إعادة بيع',
        'data': doc.data(),
        'timestamp': Timestamp.now(),
      });
    }

    // جلب تسويات مالية
    final financialSnapshot = await _firestore.collection('financialSettlements').get();
    for (var doc in financialSnapshot.docs) {
      allContracts.add({
        'type': 'تسوية مالية',
        'data': doc.data(),
        'timestamp':  Timestamp.now(),
      });
    }

    // جبل عقود الاستلام
    final astlamSnapshot = await _firestore.collection('astlam').get();
    for (var doc in astlamSnapshot.docs) {
      allContracts.add({
        'type': 'عقد استلام',
        'data': doc.data(),
        'timestamp': Timestamp.now(),
      });
    }

    // ترتيب العقود حسب رقم المشروع ثم رقم الوحدة
    allContracts.sort((a, b) {
      final aProject = a['data']['projectNumber']?.toString() ?? '';
      final bProject = b['data']['projectNumber']?.toString() ?? '';
      final aUnit = a['data']['unitNumber']?.toString() ?? a['data']['apartmentNumber']?.toString() ?? '';
      final bUnit = b['data']['unitNumber']?.toString() ?? b['data']['apartmentNumber']?.toString() ?? '';

      if (aProject == bProject) {
        return aUnit.compareTo(bUnit);
      }
      return aProject.compareTo(bProject);
    });

    return allContracts;
  }

  void _filterContracts(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredContracts = _allContracts;
      } else {
        _filteredContracts = _allContracts.where((contract) {
          final data = contract['data'];
          return (data['projectNumber']?.toString() ?? '').contains(query) ||
              (data['unitNumber']?.toString() ?? data['apartmentNumber']?.toString() ?? '').contains(query) ||
              (data['clientName']?.toString() ?? data['customerName']?.toString() ?? '').toLowerCase().contains(query.toLowerCase()) ||
              ('${data['projectNumber']}-${data['unitNumber'] ?? data['apartmentNumber']}').contains(query);
        }).toList();
      }
    });
  }

  Widget _buildContractCard(Map<String, dynamic> contract) {
    final data = contract['data'];
    final type = contract['type'];
    Color cardColor;

    switch (type) {
      case 'عقد تحت الإنشاء':
        cardColor = Colors.blue[100]!;
        break;
      case 'عقد إعادة بيع':
        cardColor = Colors.green[100]!;
        break;
      case 'تسوية مالية':
        cardColor = Colors.orange[100]!;
        break;
      case 'عقد استلام':
        cardColor = Colors.purple[100]!;
        break;
      default:
        cardColor = Colors.grey[100]!;
    }

    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  type,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[800],
                  ),
                ),
                if (data['status'] != null)
                  Chip(
                    label: Text(
                      data['status'],
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: _getStatusColor(data['status']),
                  ),
              ],
            ),
            Divider(),
            _buildDetailRow('رقم المشروع', data['projectNumber']?.toString() ?? 'غير محدد'),
            _buildDetailRow('رقم الوحدة', data['unitNumber']?.toString() ?? data['apartmentNumber']?.toString() ?? 'غير محدد'),
            _buildDetailRow('اسم العميل', data['clientName']?.toString() ?? data['customerName']?.toString() ?? 'غير محدد'),
            if (data['direction'] != null || data['unitDirection'] != null)
              _buildDetailRow('الاتجاه', data['direction']?.toString() ?? data['unitDirection']?.toString() ?? 'غير محدد'),
            if (type == 'عقد استلام' && data['clientIdentityNumber'] != null)
              _buildDetailRow('رقم الهوية', data['clientIdentityNumber']?.toString() ?? 'غير محدد'),
            if (type == 'تسوية مالية' && data['nameNow'] != null)
              _buildDetailRow('اسم المشتري', data['nameNow']?.toString() ?? 'غير محدد'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'مكتمل':
        return Colors.green;
      case 'قيد التنفيذ':
        return Colors.orange;
      case 'ملغى':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 600;

    // تجميع العقود حسب العميل
    final Map<String, List<Map<String, dynamic>>> groupedContracts = {};
    for (var contract in _filteredContracts) {
      final data = contract['data'];
      final clientName = data['clientName']?.toString() ?? data['customerName']?.toString() ?? 'غير معروف';
      if (!groupedContracts.containsKey(clientName)) {
        groupedContracts[clientName] = [];
      }
      groupedContracts[clientName]!.add(contract);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('العقود'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadContracts,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'ابحث (بالاسم، رقم المشروع، رقم الوحدة)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _filterContracts,
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : groupedContracts.isEmpty
                ? Center(child: Text('لا توجد عقود متاحة'))
                : isWideScreen
                ? GridView.count(
              crossAxisCount: 2,
              padding: EdgeInsets.all(16),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: groupedContracts.entries.map((entry) => _buildClientCard(entry.key, entry.value)).toList(),
            )
                : ListView(
              padding: EdgeInsets.all(16),
              children: groupedContracts.entries.map((entry) => _buildClientCard(entry.key, entry.value)).toList(),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildClientCard(String clientName, List<Map<String, dynamic>> contracts) {
    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              clientName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            SizedBox(height: 12),
            ...contracts.map((contract) => _buildMiniContractCard(contract)),
          ],
        ),
      ),
    );
  }
  Widget _buildMiniContractCard(Map<String, dynamic> contract) {
    final data = contract['data'];
    final type = contract['type'];

    return Container(
      margin: EdgeInsets.symmetric(vertical: 6),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            type,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          SizedBox(height: 6),
          _buildDetailRow('رقم المشروع', data['projectNumber']?.toString() ?? 'غير محدد'),
          _buildDetailRow('رقم الوحدة', data['unitNumber']?.toString() ?? data['apartmentNumber']?.toString() ?? 'غير محدد'),
          if (data['direction'] != null || data['unitDirection'] != null)
            _buildDetailRow('الاتجاه', data['direction']?.toString() ?? data['unitDirection']?.toString() ?? 'غير محدد'),
          if (type == 'عقد استلام' && data['clientIdentityNumber'] != null)
            _buildDetailRow('رقم الهوية', data['clientIdentityNumber']?.toString() ?? 'غير محدد'),
          if (type == 'تسوية مالية' && data['nameNow'] != null)
            _buildDetailRow('اسم المشتري', data['nameNow']?.toString() ?? 'غير محدد'),
        ],
      ),
    );
  }

}