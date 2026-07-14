import 'package:flutter/material.dart';

class ContractsPage1 extends StatelessWidget {
  // عدادات (تفترض أنها قادمة من Firebase لاحقًا)
  final int newContracts = 120;
  final int completedContracts = 87;
  final int repeatedContracts = 11;
  final int pendingContracts = 22;

  final List<_ContractOption> options = [
    _ContractOption("إضافة عقد جديد", Icons.add_circle_outline, Colors.green),
    _ContractOption("البحث عن عقد", Icons.search, Colors.blue),
    _ContractOption("عرض كل العقود", Icons.list_alt, Colors.orange),
    _ContractOption("عقد بيع مجددًا", Icons.refresh, Colors.teal),
    _ContractOption("عقود غير مكتملة", Icons.warning_amber, Colors.redAccent),
  ];

  ContractsPage1({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(title: Text("📄 العقود"), backgroundColor: Colors.indigo),
      body: Column(
        children: [
          _buildCountersSection(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                itemCount: options.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isMobile ? 2 : 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  final item = options[index];
                  return _OptionTile(option: item);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountersSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          _CounterCard(
            title: "العقود الجديدة",
            count: newContracts,
            color: Colors.green,
          ),
          _CounterCard(
            title: "عقود مكتملة",
            count: completedContracts,
            color: Colors.blue,
          ),
          _CounterCard(
            title: "بيع مجددًا",
            count: repeatedContracts,
            color: Colors.orange,
          ),
          _CounterCard(
            title: "غير مكتملة",
            count: pendingContracts,
            color: Colors.red,
          ),
        ],
      ),
    );
  }
}

class _ContractOption {
  final String title;
  final IconData icon;
  final Color color;

  _ContractOption(this.title, this.icon, this.color);
}

class _OptionTile extends StatelessWidget {
  final _ContractOption option;

  const _OptionTile({required this.option});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: option.color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          // للربط مستقبلاً
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('قريبًا: ${option.title}')));
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: option.color, width: 1.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(option.icon, size: 40, color: option.color),
              const SizedBox(height: 12),
              Text(
                option.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: option.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CounterCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;

  const _CounterCard({
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "$count",
            style: TextStyle(
              fontSize: 24,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
