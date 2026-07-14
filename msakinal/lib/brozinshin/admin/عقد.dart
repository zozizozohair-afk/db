import 'package:flutter/material.dart';

class ContractManagementPage extends StatefulWidget {
  const ContractManagementPage({super.key});

  @override
  _ContractManagementPageState createState() => _ContractManagementPageState();
}

class _ContractManagementPageState extends State<ContractManagementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('إدارة العقود', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.indigo[700],
        leading: MediaQuery.of(context).size.width < 600
            ? IconButton(
          icon: Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState!.openDrawer(),
        )
            : null,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'إضافة عقد جديد'),
            Tab(text: 'إدارة العقود'),
          ],
        ),
      ),
      drawer: _buildDrawer(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAddContractSection(),
          _buildManageContractsSection(),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.indigo[700]),
            child: Center(
              child: Text(
                'القائمة',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.add_box),
            title: Text('إضافة عقد جديد'),
            onTap: () {
              _tabController.index = 0;
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.list_alt),
            title: Text('إدارة العقود'),
            onTap: () {
              _tabController.index = 1;
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAddContractSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          crossAxisCount: constraints.maxWidth > 1000 ? 3 : constraints.maxWidth > 600 ? 2 : 1,
          padding: const EdgeInsets.all(16),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildAddContractCard('عقد تحت الإنشاء', Icons.build, Colors.blue),
            _buildAddContractCard('عقد إعادة بيع', Icons.repeat, Colors.green),
            _buildAddContractCard('ورقة استلام', Icons.receipt_long, Colors.orange),
          ],
        );
      },
    );
  }

  Widget _buildAddContractCard(String title, IconData icon, Color color) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          // هنا تروح لصفحة إضافة عقد جديد
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 60, color: color),
              SizedBox(height: 20),
              Text(
                title,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManageContractsSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSearchBar(),
          SizedBox(height: 20),
          Expanded(
            child: _buildContractsGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: 'ابحث برقم العقد أو الهوية...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: EdgeInsets.symmetric(horizontal: 20),
            ),
            onChanged: (value) {
              // هنا البحث عن العقود
            },
          ),
        ),
        SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () {
            // زر البحث
          },
          icon: Icon(Icons.search),
          label: Text('بحث'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo[700],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildContractsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: constraints.maxWidth > 1000 ? 3 : constraints.maxWidth > 600 ? 2 : 1,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.5,
          ),
          itemCount: 10, // عدد العقود التجريبي حالياً
          itemBuilder: (context, index) {
            return _buildContractCard(index);
          },
        );
      },
    );
  }

  Widget _buildContractCard(int index) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.description, size: 40, color: Colors.indigo[700]),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('عقد رقم: #$index', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('اسم العميل: عميل تجريبي'),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                // خيارات الحذف والتعديل
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'edit', child: Text('تعديل')),
                PopupMenuItem(value: 'delete', child: Text('حذف')),
                PopupMenuItem(value: 'print', child: Text('طباعة')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
