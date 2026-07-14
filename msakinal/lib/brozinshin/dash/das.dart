import 'package:flutter/material.dart';
import 'dashboard_service.dart'; // تأكد من استيراد ملف العمليات
import 'package:fl_chart/fl_chart.dart';

class DashboardPage11 extends StatefulWidget {
  const DashboardPage11({super.key});

  @override
  State<DashboardPage11> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage11> with SingleTickerProviderStateMixin {
  final DashboardService _service = DashboardService();
  Map<String, dynamic>? data;
  bool loading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      data = await _service.fetchDashboardData();
      setState(() {
        loading = false;
        _animationController.forward();
      });
    } catch (e) {
      setState(() {
        loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تحميل البيانات')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('لوحة التحكم'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSummaryCards(),
            const SizedBox(height: 20),
            _buildProgressAndCharts(),
            const SizedBox(height: 20),
            _buildDistributionGraphs(),
          ],
        ),
              ),
            ),
          ),
    );
  }

  Widget _buildSummaryCards() {
    List<Widget> cards = [
      _summaryCard('إجمالي الوحدات', data!['totalUnits'].toString(), Icons.home, Colors.blue),
      _summaryCard('الوحدات المباعة', data!['soldUnits'].toString(), Icons.sell, Colors.green),
      _summaryCard('الوحدات المتاحة', data!['availableUnits'].toString(), Icons.apartment, Colors.orange),
      _summaryCard('العقود النشطة', data!['activeContracts'].toString(), Icons.assignment_turned_in, Colors.purple),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: cards,
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: MediaQuery.of(context).size.width > 600 ? 200 : 160,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, color.withOpacity(0.1)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildProgressAndCharts() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _percentCard()),
        const SizedBox(width: 16),
        Expanded(child: _barChart()),
      ],
    );
  }

  Widget _percentCard() {
    final percent = double.tryParse(data!['percentDelivered']) ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("نسبة الوحدات المستلمة", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: percent / 100,
                  strokeWidth: 10,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation(Colors.green),
                ),
              ),
              Text('$percent%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _barChart() {
    final monthly = data!['monthlyRevenue'] ?? 0;
    final yearly = data!['yearlyRevenue'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("الإيرادات", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              _incomeBox('شهرياً', monthly),
              const SizedBox(width: 10),
              _incomeBox('سنوياً', yearly),
            ],
          ),
        ],
      ),
    );
  }

  Widget _incomeBox(String title, double amount) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text('SAR ${amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(color: Colors.grey)),
          ],
        ),
              ),
    );
     
  }

  Widget _distributionCard(String title, Map<String, int> map) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...map.entries.map((e) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(e.key),
              Text(e.value.toString()),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildDistributionGraphs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('تحليل البيانات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _barChartWidget('الوحدات حسب الحالة', data!['statusDistribution']),
            _pieChartWidget('حالة العقود', data!['contractStatusDistribution']),
          ],
        ),
      ],
    );
  }
  Widget _barChartWidget(String title, Map<String, int> dataMap) {
    final keys = dataMap.keys.toList();
    final values = dataMap.values.toList();

    return Container(
      width: 350,
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barGroups: List.generate(keys.length, (i) {
                  return BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: values[i].toDouble(),
                      width: 20,
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.blueAccent,
                    )


                  ]);
                }),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) {
                        final index = value.toInt();
                        if (index >= 0 && index < keys.length) {
                          return Text(keys[index], style: const TextStyle(fontSize: 10));
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true),
                  ),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _pieChartWidget(String title, Map<String, int> dataMap) {
    final total = dataMap.values.fold(0, (a, b) => a + b);
    final List<PieChartSectionData> sections = dataMap.entries.map((entry) {
      final value = entry.value;
      final percent = total == 0 ? 0 : (value / total) * 100;
      return PieChartSectionData(
        title: '${percent.toStringAsFixed(1)}%',
        value: value.toDouble(),
        radius: 60,
        color: Colors.primaries[dataMap.keys.toList().indexOf(entry.key) % Colors.primaries.length],
        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      );
    }).toList();

    return Container(
      width: 350,
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Expanded(
            child: PieChart(
              PieChartData(
                sections: sections,
                sectionsSpace: 2,
                centerSpaceRadius: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
    );
  }
}
