import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'class/logger.dart';
import 'massg.dart';

class ApartmentGeneratorPage1 extends StatefulWidget {
  const ApartmentGeneratorPage1({super.key});

  @override
  _ApartmentGeneratorPageState createState() => _ApartmentGeneratorPageState();
}

class _ApartmentGeneratorPageState extends State<ApartmentGeneratorPage1> {
  final SupabaseClient _supabase = Supabase.instance.client;

  final projectNumberController = TextEditingController();
  final floorCountController = TextEditingController();
  final apartmentsPerFloorController = TextEditingController();
  final deedNumberController = TextEditingController();
  final cityController = TextEditingController();
  final districtController = TextEditingController();
  final planNumberController = TextEditingController();
  final regionNumberController = TextEditingController();
  final deedDateController = TextEditingController();

  String selectedProjectDirection = 'شمالي';

  final Map<String, TextEditingController> descriptionControllers = {};
  final Map<String, TextEditingController> areaControllers = {};

  List<Map<String, dynamic>> generatedApartments = [];

  bool showUploadButton = false;
  bool isUploading = false;

  List<String> usedDirections = [];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 1000;
    final isTablet = MediaQuery.of(context).size.width > 600 && MediaQuery.of(context).size.width <= 1000;
    int crossAxisCount = isWide ? 5 : isTablet ? 3 : 1;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ApartmentsListPage()),
          );
        },
        backgroundColor: Colors.blue[800],
        child: Icon(Icons.apartment),
      ),
      appBar: AppBar(
        title: Text('توليد الشقق'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _buildField(projectNumberController, 'رقم المشروع'),
                _buildDropdown(),
                _buildField(floorCountController, 'عدد الطوابق'),
                _buildField(apartmentsPerFloorController, 'عدد الشقق في الطابق'),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _buildField(deedNumberController, 'رقم الصك'),
                _buildField(deedDateController, 'تاريخ الصك (مثال: 2024-12-31)'),
                _buildField(cityController, 'اللهة'),
                _buildField(districtController, 'الحي'),
                _buildField(planNumberController, 'رقم المخطط'),
                _buildField(regionNumberController, 'رقم القطعة'),
              ],
            ),
            const SizedBox(height: 20),
            const Text('الوصف لكل اتجاه شقة أو ملحق:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ...usedDirections.map((direction) {
              if (!descriptionControllers.containsKey(direction)) {
                descriptionControllers[direction] = TextEditingController();
              }
              if (!areaControllers.containsKey(direction)) {
                areaControllers[direction] = TextEditingController();
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: descriptionControllers[direction],
                        decoration: InputDecoration(
                          labelText: 'وصف لـ $direction (عدد الغرف، المطابخ، الصالات...)',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: areaControllers[direction],
                        decoration: InputDecoration(
                          labelText: 'مساحة ($direction)',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _generateApartments,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[900],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('توليد الشقق', style: TextStyle(fontSize: 16)),
            ),
            if (showUploadButton)
              const SizedBox(height: 20),
            if (showUploadButton)
              ElevatedButton(
                onPressed: _confirmUpload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: isUploading
                    ? CircularProgressIndicator(color: Colors.white)
                    : const Text('رفع البيانات', style: TextStyle(fontSize: 16)),
              ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              physics: NeverScrollableScrollPhysics(),
              children: generatedApartments.map((apartment) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 6,
                        offset: Offset(2, 2),
                      )
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'شقة رقم: ${apartment['number']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('الاتجاه: ${apartment['direction']}'),
                      Text('الوصف: ${apartment['description']}'),
                      Text('رقم المشروع: ${apartment['projectnumber']}'),
                      Text('الحالة: ${apartment['status']}'),
                      Text('مساحة الشقة: ${apartment['area']}'),
                      Text('الطابق: ${apartment['floor']}'),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label) {
    return SizedBox(
      width: 300,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.grey[100],
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return SizedBox(
      width: 300,
      child: DropdownButtonFormField<String>(
        value: selectedProjectDirection,
        decoration: InputDecoration(
          labelText: 'اتجاه المشروع',
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        items: ['شمالي', 'جنوبي', 'شرقي', 'غربي'].map((e) {
          return DropdownMenuItem<String>(
            value: e,
            child: Text(e),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            selectedProjectDirection = value!;
          });
        },
      ),
    );
  }

  Future<void> _generateApartments() async {
    final projectnumber = projectNumberController.text;
    final floorCount = int.tryParse(floorCountController.text) ?? 0;
    final apartmentsPerFloor = int.tryParse(apartmentsPerFloorController.text) ?? 0;
    final deedNumber = deedNumberController.text;
    final city = cityController.text;
    final district = districtController.text;
    final planNumber = planNumberController.text;
    final regionNumber = regionNumberController.text;
    final deedDate = deedDateController.text;

    if (projectnumber.isEmpty ||
        floorCountController.text.isEmpty ||
        apartmentsPerFloorController.text.isEmpty ||
        deedNumber.isEmpty ||
        city.isEmpty ||
        district.isEmpty ||
        planNumber.isEmpty ||
        regionNumber.isEmpty ||
        deedDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يرجى تعبئة جميع الحقول أولاً', textAlign: TextAlign.center)),
      );
      return;
    }

    // ✅ تحقق من وجود مشروع بنفس الرقم في Supabase
    final existing = await _supabase
        .from('apartments')
        .select()
        .eq('projectnumber', projectnumber)
        .limit(1);

    if (existing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يوجد مشروع بنفس الرقم مسبقاً. الرجاء اختيار رقم مختلف.', textAlign: TextAlign.center)),
      );
      return;
    }

    List<Map<String, dynamic>> apartments = [];
    List<String> directions = _getDirectionsForProjectDirection(selectedProjectDirection, floorCount);

    usedDirections = directions.toSet().toList();

    int counter = 1;

    for (int floor = 1; floor <= floorCount; floor++) {
      for (int i = 0; i < apartmentsPerFloor; i++) {
        String dir = directions[i % directions.length];
        apartments.add({
          'number': counter.toString(),
          'pn': '$projectnumber-${counter.toString()}',
          'direction': dir,
          'description': descriptionControllers[dir]?.text ?? '',
          'area': areaControllers[dir]?.text ?? '',
          'projectnumber': projectnumber,
          'deednumber': deedNumber,
          'deeddate': deedDate,
          'city': city,
          'district': district,
          'plannumber': planNumber,
          'regionnumber': regionNumber,
          'floor': floor.toString(),
          'status': 'متاح',
          'created_at': DateTime.now().toIso8601String(),
        });
        counter++;
      }

      if (floor == floorCount) {
        List<String> annexes = _getAnnexDirectionsForProjectDirection(selectedProjectDirection);
        for (var annex in annexes) {
          usedDirections.add(annex);
          if (!descriptionControllers.containsKey(annex)) {
            descriptionControllers[annex] = TextEditingController();
          }
          if (!areaControllers.containsKey(annex)) {
            areaControllers[annex] = TextEditingController();
          }

          apartments.add({
            'number': counter.toString(),
            'pn': '$projectnumber-${counter.toString()}',
            'direction': annex,
            'description': descriptionControllers[annex]?.text ?? '',
            'area': areaControllers[annex]?.text ?? '',
            'projectnumber': projectnumber,
            'deednumber': deedNumber,
            'deeddate': deedDate,
            'city': city,
            'floor': 'م',
            'district': district,
            'plannumber': planNumber,
            'regionnumber': regionNumber,
            'status': 'متاح',
            'created_at': DateTime.now().toIso8601String(),
          });
          counter++;
        }
      }
    }

    setState(() {
      generatedApartments = apartments;
      showUploadButton = true;
    });
  }

  List<String> _getDirectionsForProjectDirection(String dir, int floors) {
    switch (dir) {
      case 'شمالي':
        return ['شمالية شرقية أمامية', 'شمالية غربية أمامية', 'جنوبية غربية خلفية', 'جنوبية شرقية خلفية'];
      case 'جنوبي':
        return ['جنوبية غربية أمامية', 'جنوبية شرقية أمامية', 'شمالية شرقية خلفية', 'شمالية غربية خلفية'];
      case 'شرقي':
        return ['شرقية جنوبية أمامية', 'شرقية شمالية أمامية', 'غربية شمالية خلفية', 'غربية جنوبية خلفية'];
      case 'غربي':
      default:
        return ['غربية شمالية أمامية', 'غربية جنوبية أمامية', 'شرقية جنوبية خلفية', 'شرقية شمالية خلفية'];
    }
  }

  List<String> _getAnnexDirectionsForProjectDirection(String dir) {
    if (dir == 'شمالي') {
      return ['ملحق شرقي امامي', ' ملحق غربي امامي'];
    } else if (dir == 'جنوبي') {
      return ['ملحق غربي امامي', ' ملحق شرقي امامي'];
    } else if (dir == 'شرقي') {
      return ['ملحق جنوب امامي', ' ملحق شمالي امامي'];
    } else {
      return ['ملحق شمالي امامي', 'ملحق جنوبي امامي'];
    }
  }

  Future<void> _confirmUpload() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الرفع'),
        content: Text('هل أنت متأكد من رفع البيانات؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('تأكيد')),
        ],
      ),
    );

    if (confirm == true) {
      await _uploadToSupabase();
    }
  }

  Future<void> _uploadToSupabase() async {
    setState(() => isUploading = true);
    try {
      // استخدام insert مع خيار returning: 'minimal' لتحسين الأداء
      _supabase.from('apartments').insert(generatedApartments).select;ReturningOption.minimal;

      // تسجيل العملية في السجل (إذا كان logAction يستخدم Supabase)
      await logAction(
        category: 'شقق',
        action: 'اضافة',
        itemId: 'apt-${projectNumberController.text}',
        userId: _supabase.auth.currentUser?.id ?? 'unknown',
        oldData: {'status': 'غير موجود'},
        newData: {'status': 'تم الإنشاء'},
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم رفع البيانات بنجاح', textAlign: TextAlign.center)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل في رفع البيانات: $e', textAlign: TextAlign.center)),
      );
    } finally {
      setState(() => isUploading = false);
    }
  }
}