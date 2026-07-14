import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> fetchDashboardData({String? projectFilter}) async {
    // جلب البيانات من الجداول الثلاثة
    final apartmentsSnapshot = await _firestore.collection('apartments').get();
    final contractsSnapshot = await _firestore.collection('contracts').get();
    final astlamSnapshot = await _firestore.collection('astlam').get();

    var apartments = apartmentsSnapshot.docs.map((doc) => doc.data()).toList();
    var contracts = contractsSnapshot.docs.map((doc) => doc.data()).toList();
    var astlam = astlamSnapshot.docs.map((doc) => doc.data()).toList();
    
    // تطبيق الفلترة حسب المشروع إذا تم تحديده
    if (projectFilter != null && projectFilter.isNotEmpty) {
      apartments = apartments.where((a) => a['projectNumber'] == projectFilter).toList();
      contracts = contracts.where((c) => c['projectNumber'] == projectFilter).toList();
      astlam = astlam.where((a) => a['projectNumber'] == projectFilter).toList();
    }

    // المؤشرات العامة
    final totalUnits = apartments.length;
    final soldUnits = apartments.where((a) => a['status'] == 'مباع').length;
    final availableUnits = apartments.where((a) => a['status'] == 'متاح').length;
    final reservedUnits = apartments.where((a) => a['status'] == 'محجوز').length;
    final activeContracts = contracts.where((c) => c['status'] == 'نشط').length;
    final deliveredUnits = astlam.length;

    final percentDelivered = soldUnits > 0
        ? (deliveredUnits / soldUnits * 100).toStringAsFixed(1)
        : '0';

    // الإيرادات
    final totalRevenue = contracts.fold<double>(0, (sum, c) => sum + (c['paidAmount'] ?? 0));
    final yearlyRevenue = _sumRevenueByDate(contracts, DateTime.now().year);
    final monthlyRevenue = _sumRevenueByMonth(contracts, DateTime.now().year, DateTime.now().month);

    // تحليل حالات الوحدات
    final statusDistribution = _groupAndCount(apartments, 'status');
    final floorDistribution = _groupAndCount(apartments, 'floor');
    final projectDistribution = _groupAndCount(apartments, 'projectNumber');

    // تحليل العقود حسب الحالة
    final contractStatusDistribution = _groupAndCount(contracts, 'status');

    // تحليل الوحدات المستلمة بالتاريخ
    final astlamTimeline = _groupByDate(astlam, 'dateString');

    return {
      // مؤشرات عامة
      'totalUnits': totalUnits,
      'soldUnits': soldUnits,
      'availableUnits': availableUnits,
      'reservedUnits': reservedUnits,
      'activeContracts': activeContracts,
      'deliveredUnits': deliveredUnits,
      'percentDelivered': percentDelivered,
      'totalRevenue': totalRevenue,
      'monthlyRevenue': monthlyRevenue,
      'yearlyRevenue': yearlyRevenue,

      // تحليل الوحدات
      'statusDistribution': statusDistribution,
      'floorDistribution': floorDistribution,
      'projectDistribution': projectDistribution,

      // تحليل العقود
      'contractStatusDistribution': contractStatusDistribution,

      // بيانات استلام الوحدات
      'astlamTimeline': astlamTimeline,
    };
  }

  Map<String, int> _groupAndCount(List<Map<String, dynamic>> list, String key) {
    final Map<String, int> result = {};
    for (var item in list) {
      final value = item[key]?.toString() ?? 'غير معروف';
      result[value] = (result[value] ?? 0) + 1;
    }
    return result;
  }

  Map<String, int> _groupByDate(List<Map<String, dynamic>> list, String key) {
    final Map<String, int> result = {};
    for (var item in list) {
      final date = item[key]?.toString().split(' ').first ?? 'غير معروف';
      result[date] = (result[date] ?? 0) + 1;
    }
    return result;
  }

  double _sumRevenueByMonth(List<Map<String, dynamic>> contracts, int year, int month) {
    return contracts.fold<double>(0, (sum, c) {
      final date = DateTime.tryParse(c['dateString'] ?? '');
      if (date != null && date.year == year && date.month == month) {
        return sum + (c['paidAmount'] ?? 0);
      }
      return sum;
    });
  }

  double _sumRevenueByDate(List<Map<String, dynamic>> contracts, int year) {
    return contracts.fold<double>(0, (sum, c) {
      final date = DateTime.tryParse(c['dateString'] ?? '');
      if (date != null && date.year == year) {
        return sum + (c['paidAmount'] ?? 0);
      }
      return sum;
    });
  }
}
