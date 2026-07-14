import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'الوحدات',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const UnitsScreen1(),
    );
  }
}

class UnitsScreen1 extends StatefulWidget {
  const UnitsScreen1({super.key});

  @override
  State<UnitsScreen1> createState() => _UnitsScreenState();
}


class _UnitsScreenState extends State<UnitsScreen1> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? selectedFilter;
  TextEditingController searchController = TextEditingController();

  Future<List<Map<String, dynamic>>> fetchUnits({String? projectNumber}) async {
    QuerySnapshot projectsSnapshot;

    if (projectNumber != null && projectNumber.isNotEmpty) {
      projectsSnapshot = await _firestore
          .collection('projects')
          .where('projectNumber', isEqualTo: projectNumber)
          .get();
    } else {
      projectsSnapshot = await _firestore.collection('projects').get();
    }

    List<Map<String, dynamic>> allUnits = [];





    for (var project in projectsSnapshot.docs) {
      var unitsSnapshot = await project.reference.collection('units').get();
      for (var unit in unitsSnapshot.docs) {
        final data = unit.data();
        if (selectedFilter == null || data['status'] == selectedFilter) {
          allUnits.add({
            'projectNumber': project['projectNumber'],
            'unitId': unit.id,
            'unitRef': unit.reference,
            ...data,
          });
        }
      }
    }

    return allUnits;
  }
  List<Map<String, dynamic>> searchResults = [];
  Future<void> searchUnitsByProjectNumber() async {
    final query = searchController.text.trim();
    final units = await fetchUnits(projectNumber: query);
    setState(() {
      searchResults = units;
    });
  }


  void updateUnitStatus(Map<String, dynamic> unit, String status) async {
    await unit['unitRef'].update({'status': status});
    setState(() {});
  }

  void updateAdditionalInfo(Map<String, dynamic> unit, Map<String, dynamic> newData) async {
    await unit['unitRef'].update(newData);
    setState(() {});
  }

  void showStatusDialog(BuildContext context, Map<String, dynamic> unit) {
    String selectedStatus = unit['status'] ?? 'متاح';
    final TextEditingController depositController = TextEditingController();
    final TextEditingController customerNameController = TextEditingController();
    final TextEditingController customerIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("تعديل حالة الوحدة"),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: const InputDecoration(labelText: "الحالة"),
                  items: ['متاح', 'محجوز', 'مباعة']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) {
                    setStateDialog(() {
                      selectedStatus = val!;
                    });
                  },
                ),
                if (selectedStatus == 'محجوز') ...[
                  TextField(
                    controller: depositController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'قيمة العربون'),
                  ),
                  TextField(
                    controller: customerNameController,
                    decoration: const InputDecoration(labelText: 'اسم الزبون'),
                  ),
                ],
                if (selectedStatus == 'مباعة') ...[
                  TextField(
                    controller: customerNameController,
                    decoration: const InputDecoration(labelText: 'اسم العميل'),
                  ),
                  TextField(
                    controller: customerIdController,
                    decoration: const InputDecoration(labelText: 'رقم الهوية'),
                  ),
                ]
              ],
            );
          },
        ),
        actions: [
          TextButton(
            child: const Text("إلغاء"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text("حفظ"),
            onPressed: () {
              Map<String, dynamic> updateData = {'status': selectedStatus};
              if (selectedStatus == 'محجوز') {
                updateData['deposit'] = depositController.text;
                updateData['customerName'] = customerNameController.text;
              } else if (selectedStatus == 'مباعة') {
                updateData['customerName'] = customerNameController.text;
                updateData['customerId'] = customerIdController.text;
              }
              updateUnitStatus(unit, selectedStatus);
              updateAdditionalInfo(unit, updateData);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget buildUnitCard(Map<String, dynamic> unit) {
    final specs = unit['specs'] as Map<String, dynamic>? ?? {};
    final String status = unit['status'] ?? 'متاح';

    Color getStatusColor(String status) {
      switch (status) {
        case 'محجوز':
          return Colors.yellow.shade100;
        case 'مباعة':
          return Colors.red.shade100;
        default:
          return Colors.green.shade100;
      }
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UnitDetailsScreen(unit: unit),
          ),
        );
      },
      child: Card(
        color: getStatusColor(status),
        margin: const EdgeInsets.all(10),
        elevation: 5,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("رقم المشروع: ${unit['projectNumber']}",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("رقم الشقة: ${unit['apartmentNumber']}"),
              Text("نوع الشقة: ${unit['type']}"),
              ...specs.entries.map((e) => Text("${e.key}: ${e.value}")),
              const SizedBox(height: 10),
              Text("الحالة الحالية: $status", style: const TextStyle(color: Colors.black87)),
              if (status == 'محجوز') ...[
                Text("العربون: ${unit['deposit'] ?? ''}"),
                Text("الزبون: ${unit['customerName'] ?? ''}"),
              ],
              if (status == 'مباعة') ...[
                Text("اسم العميل: ${unit['customerName'] ?? ''}"),
                Text("رقم الهوية: ${unit['customerId'] ?? ''}"),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.edit, color: Colors.orange),
                    label: const Text("تعديل الحالة"),
                    onPressed: () => showStatusDialog(context, unit),
                  ),
                  const SizedBox(width: 10),
                  TextButton.icon(
                    icon: const Icon(Icons.info_outline, color: Colors.blue),
                    label: const Text("تفاصيل"),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UnitDetailsScreen(unit: unit),
                        ),
                      );
                    },
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar( title: TextField(
        controller: searchController,
        textDirection: TextDirection.rtl, // عشان النص يكتب من اليمين لليسار
        decoration: InputDecoration(
          hintText: 'ابحث برقم المشروع...',
          hintStyle: TextStyle(color: Colors.white70),
          border: InputBorder.none,
        ),
        style: TextStyle(color: Colors.white),
        onSubmitted: (_) => searchUnitsByProjectNumber(), // بحث عند الضغط "Enter"
      ), actions: [
        PopupMenuButton<String>(
          onSelected: (value) {
            setState(() {
              selectedFilter = value == 'الكل' ? null : value;
            });
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'الكل', child: Text('عرض الكل')),
            const PopupMenuItem(value: 'متاح', child: Text('متاحة فقط')),
            const PopupMenuItem(value: 'محجوز', child: Text('محجوزة فقط')),
            const PopupMenuItem(value: 'مباعة', child: Text('مباعة فقط')),
          ],
        ),
        IconButton(
          icon: Icon(Icons.search),
          onPressed: searchUnitsByProjectNumber,
          tooltip: "بحث",
        ),
        IconButton(
          icon: const Icon(Icons.delete_forever),
          tooltip: "حذف الكل",
          onPressed: () async {
            bool confirm = await showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text("تأكيد الحذف"),
                content: const Text("هل أنت متأكد من حذف جميع الوحدات؟"),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("إلغاء")),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("نعم")),
                ],
              ),
            );
            if (confirm) {
              final snapshot = await _firestore.collection('projects').get();
              for (var project in snapshot.docs) {
                final units = await project.reference.collection('units').get();
                for (var unit in units.docs) {
                  await unit.reference.delete();
                }
              }
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("تم حذف جميع الوحدات")),
              );
            }
          },
        ),

      ],),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchUnits(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final units = snapshot.data ?? [];
          if (units.isEmpty) {
            return const Center(child: Text("لا توجد وحدات بعد."));
          }

          return ListView.builder(
            itemCount: units.length,
            itemBuilder: (context, index) =>
                buildUnitCard(units[index]),
          );
        },
      ),
    );
  }
}

class UnitDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> unit;

  const UnitDetailsScreen({super.key, required this.unit});

  @override
  Widget build(BuildContext context) {
    final specs = unit['specs'] as Map<String, dynamic>? ?? {};
    final status = unit['status'] ?? 'متاح';

    return Scaffold(
      appBar: AppBar(
        title: Text("تفاصيل الوحدة ${unit['apartmentNumber']}"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text("رقم المشروع: ${unit['projectNumber']}",
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Text("رقم الشقة: ${unit['apartmentNumber']}"),
            Text("نوع الشقة: ${unit['type']}"),
            const Divider(height: 20),
            const Text("المواصفات", style: TextStyle(fontWeight: FontWeight.bold)),
            ...specs.entries.map((e) => Text("${e.key}: ${e.value}")),
            const Divider(height: 20),
            Text("الحالة: $status"),
            if (status == 'محجوز') ...[
              Text("العربون: ${unit['deposit'] ?? ''}"),
              Text("الزبون: ${unit['customerName'] ?? ''}"),
            ],
            if (status == 'مباعة') ...[
              Text("اسم العميل: ${unit['customerName'] ?? ''}"),
              Text("رقم الهوية: ${unit['customerId'] ?? ''}"),
            ],
          ],
        ),
      ),
    );
  }
}
