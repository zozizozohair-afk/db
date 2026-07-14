import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';

class BuildingLayoutPage extends StatefulWidget {
  final String? preselectedProjectNumber;

  const BuildingLayoutPage({Key? key, this.preselectedProjectNumber})
    : super(key: key);

  @override
  State<BuildingLayoutPage> createState() => _BuildingLayoutPageState();
}

class _BuildingLayoutPageState extends State<BuildingLayoutPage> {
  String? selectedProjectNumber;
  List<Map<String, dynamic>> projects = [];
  List<Map<String, dynamic>> apartments = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();

    // إذا تم تمرير معرف المشروع، حدده تلقائياً
    if (widget.preselectedProjectNumber != null) {
      selectedProjectNumber = widget.preselectedProjectNumber;
      _loadApartments(widget.preselectedProjectNumber!);
    }
  }

  Future<void> _loadProjects() async {
    try {
      setState(() {
        isLoading = true;
      });

      final apartments =
          await FirebaseFirestore.instance.collection('apartments').get();

      // تجميع المشاريع من مجموعة الشقق
      Map<String, Map<String, dynamic>> projectsMap = {};

      for (var doc in apartments.docs) {
        final data = doc.data();
        final projectNumber = data['projectNumber']?.toString() ?? 'غير معروف';

        if (!projectsMap.containsKey(projectNumber)) {
          projectsMap[projectNumber] = {
            'projectNumber': projectNumber,
            'description': 'مشروع $projectNumber',
            'city': data['city'],
            'district': data['district'],
            'planNumber': data['planNumber'],
            'deedDate': data['deedDate'],
            'deedNumber': data['deedNumber'],
            'apartmentsCount': 0,
          };
        }

        projectsMap[projectNumber]!['apartmentsCount'] += 1;
      }

      setState(() {
        projects = projectsMap.values.toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        projects = [
          {'projectNumber': '119', 'description': 'مشروع تجريبي'},
        ];
      });
      print('Error loading projects: $e');
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تحميل المشاريع. سيتم استخدام بيانات تجريبية.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _loadApartments(String projectNumber) async {
    try {
      setState(() {
        isLoading = true;
      });

      final QuerySnapshot apartmentSnapshot =
          await FirebaseFirestore.instance
              .collection('apartments')
              .where('projectNumber', isEqualTo: projectNumber)
              .get();

      List<Map<String, dynamic>> apartmentsList = [];
      for (var doc in apartmentSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        apartmentsList.add({
          'id': doc.id,
          'number': data['number'] ?? '',
          'floor': data['floor'] ?? '',
          'direction': data['direction'] ?? '',
          'status': data['status'] ?? '',
          'area': data['area'] ?? '',
          'details': data['details'] ?? data['description'] ?? '',
        });
      }

      setState(() {
        apartments = apartmentsList;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading apartments: $e');
      setState(() {
        isLoading = false;
        // Use sample data if database fails
        apartments = _getSampleApartments();
      });
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تحميل الشقق. سيتم استخدام بيانات تجريبية.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  List<Map<String, dynamic>> _getSampleApartments() {
    List<Map<String, dynamic>> sampleApartments = [];

    // Create sample data for 5 floors
    for (int floor = 1; floor <= 5; floor++) {
      for (int apt = 1; apt <= 4; apt++) {
        String aptNumber = '${floor}0$apt';
        // الشقق الأمامية في الأطراف (1 و 4) والخلفية في الوسط (2 و 3)
        String direction =
            (apt == 1 || apt == 4) ? 'شمالية أمامية' : 'جنوبية خلفية';
        String status =
            apt == 1
                ? 'متاحة'
                : apt == 2
                ? 'محجوزة'
                : apt == 3
                ? 'مباعة'
                : 'متاحة';

        sampleApartments.add({
          'id': aptNumber,
          'number': aptNumber,
          'floor': floor.toString(),
          'direction': direction,
          'status': status,
          'area': (apt == 1 || apt == 4) ? '160' : '140',
          'details': (apt == 1 || apt == 4) ? 'شقة 5 غرف' : 'شقة 4 غرف',
        });
      }
    }

    // Add roof units
    sampleApartments.addAll([
      {
        'id': 'roof1',
        'number': '21',
        'floor': '6',
        'direction': 'ملحق شمالي',
        'status': 'متاحة',
        'area': '310',
        'details': 'ملحق 6 غرف',
      },
      {
        'id': 'roof2',
        'number': '22',
        'floor': '6',
        'direction': 'ملحق جنوبي',
        'status': 'محجوزة',
        'area': '280',
        'details': 'ملحق 5 غرف',
      },
    ]);

    return sampleApartments;
  }

  Color _getApartmentColor(String? status) {
    String statusLower = status?.toString().toLowerCase() ?? 'متاحة';

    switch (statusLower) {
      case 'متاح':
      case 'متاحة':
      case 'available':
        return Colors.blue[600]!;
      case 'محجوز':
      case 'محجوزة':
      case 'reserved':
        return const Color.fromARGB(255, 238, 255, 0)!;
      case 'مباع':
      case 'مباعة':
      case 'sold':
      case 'تم الإفراغ':
      case 'تحت الاجراء':
      case 'معروضة للبيع':
        return Colors.red[600]!;
      default:
        return Colors.blue[600]!;
    }
  }

  Map<String, dynamic> _generateFloorsData() {
    if (apartments.isEmpty) {
      return {'floors': [], 'roofUnits': []};
    }

    // Group apartments by floor
    Map<String, List<Map<String, dynamic>>> floorGroups = {};
    List<Map<String, dynamic>> roofUnits = [];

    for (var apartment in apartments) {
      String floor = apartment['floor']?.toString() ?? '1';
      String direction = apartment['direction']?.toString() ?? '';

      // Check if it's a roof unit (ملحق)
      if (direction.contains('ملحق')) {
        roofUnits.add({
          'name': apartment['number']?.toString() ?? '',
          'color': _getApartmentColor(apartment['status']),
          'area': apartment['area']?.toString() ?? '',
          'direction': direction,
          'details': apartment['details']?.toString() ?? '',
        });
      } else {
        if (!floorGroups.containsKey(floor)) {
          floorGroups[floor] = [];
        }
        floorGroups[floor]!.add({
          'name': apartment['number']?.toString() ?? '',
          'color': _getApartmentColor(apartment['status']),
          'isLarge': !direction.contains('خلفية'), // Small if contains 'خلفية'
          'area': apartment['area']?.toString() ?? '',
          'direction': direction,
          'details': apartment['details']?.toString() ?? '',
        });
      }
    }

    // Convert to floors list
    List<Map<String, dynamic>> floors = [];
    List<String> sortedFloors =
        floorGroups.keys.toList()..sort(
          (a, b) => int.parse(b).compareTo(int.parse(a)),
        ); // Descending order

    for (String floorNumber in sortedFloors) {
      floors.add({
        'title': _getFloorTitle(floorNumber),
        'units': floorGroups[floorNumber]!,
      });
    }

    return {'floors': floors, 'roofUnits': roofUnits};
  }

  String _getFloorTitle(String floorNumber) {
    return 'الطابق $floorNumber';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    // A4 dimensions in pixels (at 96 DPI): 794 x 1123
    final double a4Width = 794.0;
    final double a4Height = 1123.0;

    // Calculate container width for A4 format on desktop
    double containerWidth = screenWidth;
    if (isDesktop) {
      // Use A4 width but ensure it doesn't exceed 90% of screen width
      containerWidth = math.min(a4Width, screenWidth * 0.9);
    }

    // Generate floors data from database
    final Map<String, dynamic> floorsDataMap = _generateFloorsData();
    final List<Map<String, dynamic>> floorsData =
        (floorsDataMap['floors'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
    final List<Map<String, dynamic>> roofUnits =
        (floorsDataMap['roofUnits'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();

    Widget buildContent() {
      return Column(
        children: [
          // Project selection dropdown
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'اختر المشروع:',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: isMobile ? 8 : 12),
                isLoading
                    ? Center(
                      child: CircularProgressIndicator(color: Colors.blue[700]),
                    )
                    : DropdownButtonFormField<String>(
                      value: selectedProjectNumber,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.blue[700]!),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: isMobile ? 8 : 12,
                        ),
                        hintText: 'اختر رقم المشروع',
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: isMobile ? 12 : 14,
                        ),
                      ),
                      items:
                          projects.map((project) {
                            return DropdownMenuItem<String>(
                              value: project['projectNumber'],
                              child: Text(
                                'مشروع ${project['projectNumber']} - ${project['description']}',
                                style: TextStyle(fontSize: isMobile ? 12 : 14),
                              ),
                            );
                          }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedProjectNumber = newValue;
                          });
                          _loadApartments(newValue);
                        }
                      },
                    ),
              ],
            ),
          ),
          SizedBox(height: isMobile ? 12 : 20),

          // Header with company logo and info
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[700]!, Colors.blue[500]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(isMobile ? 10 : 15),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'شركة مساكن الرفاهية',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 18 : 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'للتطوير والاستثمار العقاري',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 12 : 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: isMobile ? 50 : 80,
                      height: isMobile ? 50 : 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(isMobile ? 25 : 40),
                      ),
                      child: Icon(
                        Icons.business,
                        size: isMobile ? 25 : 40,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: isMobile ? 12 : 20),

          // Building layout
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isMobile ? 10 : 15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                // Roof units info headers
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        roofUnits.isNotEmpty && roofUnits.length > 0
                            ? '${roofUnits[0]['details'] ?? 'ملحق'} | ${roofUnits[0]['area'] ?? '0'}م² | ${roofUnits[0]['direction'] ?? 'غير محدد'}'
                            : 'ملحق | 310م² | شمالية أمامية',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isMobile ? 10 : 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    SizedBox(width: isMobile ? 10 : 20),
                    Expanded(
                      child: Text(
                        roofUnits.isNotEmpty && roofUnits.length > 1
                            ? '${roofUnits[1]['details'] ?? 'ملحق'} | ${roofUnits[1]['area'] ?? '0'}م² | ${roofUnits[1]['direction'] ?? 'غير محدد'}'
                            : 'ملحق | 310م² | شمالية أمامية',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isMobile ? 10 : 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 6 : 10),

                // Roof units
                if (roofUnits.isNotEmpty)
                  Row(
                    children: [
                      if (roofUnits.length > 0)
                        Expanded(
                          child: _buildUnit(
                            roofUnits[0]['name'].isEmpty
                                ? 'روف'
                                : 'روف رقم ${roofUnits[0]['name']}',
                            roofUnits[0]['color'],
                            isMobile,
                            area: roofUnits[0]['area'] ?? '',
                            direction: roofUnits[0]['direction'] ?? '',
                            details: roofUnits[0]['details'] ?? '',
                          ),
                        ),
                      if (roofUnits.length > 1) ...[
                        SizedBox(width: isMobile ? 8 : 20),
                        Expanded(
                          child: _buildUnit(
                            roofUnits[1]['name'].isEmpty
                                ? 'روف'
                                : 'روف رقم ${roofUnits[1]['name']}',
                            roofUnits[1]['color'],
                            isMobile,
                            area: roofUnits[1]['area'] ?? '',
                            direction: roofUnits[1]['direction'] ?? '',
                            details: roofUnits[1]['details'] ?? '',
                          ),
                        ),
                      ],
                    ],
                  ),
                if (roofUnits.isEmpty)
                  Row(
                    children: [
                      Expanded(
                        child: _buildUnit(
                          'روف رقم 21',
                          Colors.grey[300]!,
                          isMobile,
                        ),
                      ),
                      SizedBox(width: isMobile ? 8 : 20),
                      Expanded(
                        child: _buildUnit(
                          'روف رقم 22',
                          Colors.grey[300]!,
                          isMobile,
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: isMobile ? 8 : 15),

                // Generate floors using list
                ...List.generate(floorsData.length, (index) {
                  final floor = floorsData[index];
                  final units =
                      (floor['units'] as List<dynamic>? ?? [])
                          .cast<Map<String, dynamic>>();

                  // Ensure we have 4 units per floor, pad with empty if needed
                  while (units.length < 4) {
                    units.add({
                      'name': '',
                      'color': Colors.grey[300]!,
                      'isLarge': true,
                      'area': '',
                      'direction': '',
                      'details': '',
                    });
                  }

                  // Sort units by apartment number to ensure consistent ordering
                  units.sort((a, b) {
                    String nameA = a['name']?.toString() ?? '';
                    String nameB = b['name']?.toString() ?? '';

                    // Extract numbers from apartment names for proper sorting
                    RegExp numberRegex = RegExp(r'\d+');
                    Match? matchA = numberRegex.firstMatch(nameA);
                    Match? matchB = numberRegex.firstMatch(nameB);

                    if (matchA != null && matchB != null) {
                      int numA = int.tryParse(matchA.group(0)!) ?? 0;
                      int numB = int.tryParse(matchB.group(0)!) ?? 0;
                      return numA.compareTo(numB);
                    }

                    return nameA.compareTo(nameB);
                  });

                  return Column(
                    children: [
                      _buildFloorContainer(floor['title'], [
                        _buildUnit(
                          units[1]['name'],
                          units[1]['color'],
                          isMobile,
                          isLarge: units[1]['isLarge'],
                        ),
                        _buildUnit(
                          units[2]['name'],
                          units[2]['color'],
                          isMobile,
                          isLarge: units[2]['isLarge'],
                        ),
                        _buildUnit(
                          units[3]['name'],
                          units[3]['color'],
                          isMobile,
                          isLarge: units[3]['isLarge'],
                        ),
                        _buildUnit(
                          units[0]['name'],
                          units[0]['color'],
                          isMobile,
                          isLarge: units[0]['isLarge'],
                        ),
                      ], isMobile),
                      if (index < floorsData.length - 1)
                        SizedBox(height: isMobile ? 8 : 15),
                    ],
                  );
                }),
              ],
            ),
          ),
          SizedBox(height: isMobile ? 12 : 20),

          // First floor apartment details
          _buildApartmentDescriptions(floorsData, isMobile),
          SizedBox(height: isMobile ? 12 : 20),

          // Status legend
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    vertical: isMobile ? 6 : (isDesktop ? 6 : 8),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red[600],
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    'مباعة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 12 : (isDesktop ? 12 : 14),
                    ),
                  ),
                ),
              ),
              SizedBox(width: isMobile ? 5 : (isDesktop ? 5 : 10)),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    vertical: isMobile ? 6 : (isDesktop ? 6 : 8),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.yellow[600],
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    'محجوزة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 12 : (isDesktop ? 12 : 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 20 : (isDesktop ? 15 : 30)),

          // Project info
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isMobile ? 12 : (isDesktop ? 12 : 20)),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[700]!, Colors.blue[500]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(
                isMobile ? 10 : (isDesktop ? 10 : 15),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'مشروع رقم ${selectedProjectNumber ?? ""}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 20 : (isDesktop ? 20 : 28),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: isMobile ? 8 : (isDesktop ? 8 : 15)),
                Text(
                  isDesktop
                      ? 'تحديثات الشقق - حي النزهة'
                      : 'تحديثات الشقق تحت الإنشاء\nحي النزهة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 12 : (isDesktop ? 12 : 16),
                  ),
                ),
                SizedBox(height: isMobile ? 12 : (isDesktop ? 10 : 20)),
                Text(
                  'WWW.MASAKEN-RC.COM.SA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 11 : (isDesktop ? 11 : 14),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.blue[700],
        title: Text(
          'مخطط المبنى',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isMobile ? 18 : 20,
          ),
        ),
        centerTitle: true,
        actions: [
          if (selectedProjectNumber != null && apartments.isNotEmpty)
            IconButton(
              icon: Icon(Icons.print, color: Colors.white),
              onPressed: () => _printBuildingLayout(),
              tooltip: 'طباعة مخطط المبنى',
            ),
        ],
      ),
      body:
          isDesktop
              ? Center(
                child: Container(
                  width: containerWidth,
                  constraints: BoxConstraints(
                    maxWidth: a4Width,
                    minHeight: a4Height,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 0,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: buildContent(),
                  ),
                ),
              )
              : SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 8 : 16),
                child: buildContent(),
              ),
    );
  }

  Widget _buildUnit(
    String title,
    Color color,
    bool isMobile, {
    bool isLarge = false,
    String area = '',
    String direction = '',
    String details = '',
  }) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    // Compress content for desktop A4 format
    String compressedDetails = details;
    if (isDesktop && details.isNotEmpty) {
      List<String> words = details.split(' ');
      compressedDetails = words.take(3).join(' ');
      if (words.length > 3) compressedDetails += '...';
    }

    double height =
        isLarge
            ? (isMobile ? 45 : (isDesktop ? 50 : 70))
            : (isMobile ? 35 : (isDesktop ? 35 : 50));

    return Container(
      height: height,
      margin: EdgeInsets.symmetric(
        vertical: isLarge ? 0 : (isMobile ? 5 : (isDesktop ? 4 : 8)),
        horizontal: isMobile ? 2 : (isDesktop ? 2 : 4),
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isLarge ? 0.3 : 0.15),
            spreadRadius: isLarge ? 2 : 1,
            blurRadius: isLarge ? 5 : 3,
            offset: Offset(0, isLarge ? 3 : 1),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Direction indicator line (simplified for desktop)
          if (direction.isNotEmpty && !isDesktop)
            Positioned(
              top: 2,
              right:
                  direction.contains('شمالي') || direction.contains('أمامي')
                      ? 2
                      : null,
              left:
                  direction.contains('جنوبي') || direction.contains('خلفي')
                      ? 2
                      : null,
              child: Container(
                width: isMobile ? 15 : 20,
                height: 2,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'tg',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize:
                        isLarge
                            ? (isMobile ? 18 : (isDesktop ? 20 : 22))
                            : (isMobile ? 16 : (isDesktop ? 20 : 20)),
                  ),
                  textAlign: TextAlign.center,
                ),
                if (area.isNotEmpty && isLarge)
                  Text(
                    '${area}م²',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: isMobile ? 10 : (isDesktop ? 8 : 12),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (compressedDetails.isNotEmpty && isLarge)
                  Text(
                    compressedDetails,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: isMobile ? 8 : (isDesktop ? 6 : 10),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloorContainer(
    String floorTitle,
    List<Widget> units,
    bool isMobile,
  ) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    // Simplify floor title for desktop
    String simplifiedTitle = floorTitle;
    if (isDesktop) {
      simplifiedTitle = floorTitle
          .replaceAll('الطابق ', 'ط')
          .replaceAll('الدور ', 'د');
    }

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : (isDesktop ? 8 : 16)),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[400]!, width: isDesktop ? 1 : 2),
        borderRadius: BorderRadius.circular(
          isMobile ? 10 : (isDesktop ? 8 : 12),
        ),
      ),
      child: Column(
        children: [
          Text(
            simplifiedTitle,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: isMobile ? 16 : (isDesktop ? 14 : 20),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isMobile ? 12 : (isDesktop ? 8 : 16)),
          Row(
            children: [
              Expanded(flex: 3, child: units[0]),
              SizedBox(width: isMobile ? 6 : (isDesktop ? 4 : 10)),
              Expanded(flex: 2, child: units[1]),
              SizedBox(width: isMobile ? 4 : (isDesktop ? 2 : 6)),
              Expanded(flex: 2, child: units[2]),
              SizedBox(width: isMobile ? 6 : (isDesktop ? 4 : 10)),
              Expanded(flex: 3, child: units[3]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommercialUnit(String text, Color color, bool isMobile) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    // Compress text for desktop
    String compressedText = text;
    if (isDesktop && text.isNotEmpty) {
      List<String> lines = text.split('\n');
      compressedText = lines.take(2).join('\n');
      if (lines.length > 2) compressedText += '...';
    }

    return Container(
      height: isMobile ? 50 : (isDesktop ? 50 : 80),
      padding: EdgeInsets.all(isMobile ? 4 : (isDesktop ? 4 : 8)),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(isMobile ? 6 : (isDesktop ? 6 : 8)),
        border: Border.all(color: Colors.grey[400]!, width: 1),
      ),
      child: Center(
        child: Text(
          compressedText,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: isMobile ? 9 : (isDesktop ? 8 : 11),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildApartmentDescriptions(
    List<Map<String, dynamic>> floorsData,
    bool isMobile,
  ) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    // Compress apartment descriptions for desktop
    String getCompressedDescription(String fullDescription) {
      if (!isDesktop) return fullDescription;

      List<String> lines = fullDescription.split('\n');
      List<String> words = lines.join(' ').split(' ');
      String compressed = words.take(5).join(' ');
      if (words.length > 5) compressed += '...';
      return compressed;
    }

    // Find first floor data
    Map<String, dynamic>? firstFloor;
    for (var floor in floorsData) {
      if (floor['title'].toString().contains('1')) {
        firstFloor = floor;
        break;
      }
    }

    // If no first floor found, use sample data
    List<Map<String, dynamic>> firstFloorUnits = [];
    if (firstFloor != null) {
      firstFloorUnits =
          (firstFloor['units'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();
    }

    // Ensure we have 4 units, pad with sample data if needed
    while (firstFloorUnits.length < 4) {
      int index = firstFloorUnits.length + 1; // 1-based indexing
      firstFloorUnits.add({
        'name': '10$index',
        'direction':
            (index == 1 || index == 4) ? 'شمالية أمامية' : 'جنوبية خلفية',
        'area': (index == 1 || index == 4) ? '160' : '140',
        'details': (index == 1 || index == 4) ? 'شقة 5 غرف' : 'شقة 4 غرف',
      });
    }

    // Reorder units to match apartment layout: 1، 2، 3، 4
    List<Map<String, dynamic>> reorderedUnits = [];

    if (firstFloorUnits.length >= 4) {
      reorderedUnits = [
        firstFloorUnits[1],
        firstFloorUnits[2],

        // Unit 1
        // Unit 2
        // Unit 3
        firstFloorUnits[3],
        firstFloorUnits[0],
        // Unit 4
      ];
    } else {
      reorderedUnits = firstFloorUnits;
      while (reorderedUnits.length < 4) {
        reorderedUnits.add({
          'direction': 'غير محدد',
          'area': '0',
          'details': 'غير متاح',
        });
      }
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _buildCommercialUnit(
            getCompressedDescription(
              '${reorderedUnits[0]['direction']}\nبمساحة ${reorderedUnits[0]['area']}م²\n${reorderedUnits[0]['details']}',
            ),
            Colors.grey[300]!,
            isMobile,
          ),
        ),
        SizedBox(width: isMobile ? 6 : (isDesktop ? 4 : 10)),
        Expanded(
          flex: 2,
          child: _buildCommercialUnit(
            getCompressedDescription(
              '${reorderedUnits[1]['direction']}\nبمساحة ${reorderedUnits[1]['area']}م²\n${reorderedUnits[1]['details']}',
            ),
            Colors.grey[300]!,
            isMobile,
          ),
        ),
        SizedBox(width: isMobile ? 4 : (isDesktop ? 2 : 6)),
        Expanded(
          flex: 2,
          child: _buildCommercialUnit(
            getCompressedDescription(
              '${reorderedUnits[2]['direction']}\nبمساحة ${reorderedUnits[2]['area']}م²\n${reorderedUnits[2]['details']}',
            ),
            Colors.grey[300]!,
            isMobile,
          ),
        ),
        SizedBox(width: isMobile ? 6 : (isDesktop ? 4 : 10)),
        Expanded(
          flex: 3,
          child: _buildCommercialUnit(
            getCompressedDescription(
              '${reorderedUnits[3]['direction']}\nبمساحة ${reorderedUnits[3]['area']}م²\n${reorderedUnits[3]['details']}',
            ),
            Colors.grey[300]!,
            isMobile,
          ),
        ),
      ],
    );
  }

  Future<void> _printBuildingLayout() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('جاري إنشاء ملف PDF...'),
                ],
              ),
            ),
      );

      final pdf = pw.Document();

      // Load Arabic font
      final arabicFont = await PdfGoogleFonts.tajawalRegular();
      final arabicBoldFont = await PdfGoogleFonts.tajawalBold();

      // Generate floors data
      final Map<String, dynamic> floorsDataMap = _generateFloorsData();
      final List<Map<String, dynamic>> floorsData =
          (floorsDataMap['floors'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();
      final List<Map<String, dynamic>> roofUnits =
          (floorsDataMap['roofUnits'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();

      // Get project info
      final selectedProject = projects.firstWhere(
        (project) => project['projectNumber'] == selectedProjectNumber,
        orElse:
            () => {
              'projectNumber': selectedProjectNumber,
              'description': 'مشروع غير معروف',
            },
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Compressed Header
                pw.Container(
                  width: double.infinity,
                  padding: pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#1976D2'),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'مخطط المبنى',
                        style: pw.TextStyle(
                          font: arabicBoldFont,
                          fontSize: 18,
                          color: PdfColors.white,
                        ),
                        textDirection: pw.TextDirection.rtl,
                      ),
                      pw.Text(
                        'مشروع: $selectedProjectNumber',
                        style: pw.TextStyle(
                          font: arabicFont,
                          fontSize: 14,
                          color: PdfColors.white,
                        ),
                        textDirection: pw.TextDirection.rtl,
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),

                // Compressed Project Information
                pw.Container(
                  width: double.infinity,
                  padding: pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'طوابق: ${floorsData.length}',
                        style: pw.TextStyle(font: arabicFont, fontSize: 10),
                        textDirection: pw.TextDirection.rtl,
                      ),
                      pw.Text(
                        'وحدات: ${apartments.length}',
                        style: pw.TextStyle(font: arabicFont, fontSize: 10),
                        textDirection: pw.TextDirection.rtl,
                      ),
                      pw.Text(
                        'ملاحق: ${roofUnits.length}',
                        style: pw.TextStyle(font: arabicFont, fontSize: 10),
                        textDirection: pw.TextDirection.rtl,
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),

                // Compressed Status Legend
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPdfLegendItem('متاحة', '#1976D2', arabicFont),
                    _buildPdfLegendItem('محجوزة', '#EEFF00', arabicFont),
                    _buildPdfLegendItem('مباعة', '#D32F2F', arabicFont),
                  ],
                ),
                pw.SizedBox(height: 10),

                // Building Layout
                pw.Expanded(
                  child: pw.Column(
                    children: [
                      // Roof units
                      if (roofUnits.isNotEmpty) ...[
                        pw.Container(
                          width: double.infinity,
                          padding: pw.EdgeInsets.all(10),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey400),
                            borderRadius: pw.BorderRadius.circular(8),
                          ),
                          child: pw.Column(
                            children: [
                              pw.Text(
                                'الملاحق (السطح)',
                                style: pw.TextStyle(
                                  font: arabicBoldFont,
                                  fontSize: 14,
                                ),
                                textDirection: pw.TextDirection.rtl,
                              ),
                              pw.SizedBox(height: 10),
                              pw.Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children:
                                    roofUnits.map((unit) {
                                      return pw.Container(
                                        width: 75,
                                        child: _buildCompressedPdfUnit(
                                          unit,
                                          arabicBoldFont,
                                          false,
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 15),
                      ],

                      // Floors
                      ...floorsData.map((floor) {
                        final units =
                            (floor['units'] as List<dynamic>? ?? [])
                                .cast<Map<String, dynamic>>();

                        // Reorder units: 1، 3، 4، 2
                        List<Map<String, dynamic>> reorderedUnits = [];
                        if (units.length >= 4) {
                          reorderedUnits = [
                            units[0],
                            units[2],
                            units[3],
                            units[1],
                          ];
                        } else {
                          reorderedUnits = units;
                        }

                        return pw.Container(
                          width: double.infinity,
                          margin: pw.EdgeInsets.only(bottom: 15),
                          padding: pw.EdgeInsets.all(10),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey400),
                            borderRadius: pw.BorderRadius.circular(8),
                          ),
                          child: pw.Column(
                            children: [
                              pw.Text(
                                floor['title'],
                                style: pw.TextStyle(
                                  font: arabicBoldFont,
                                  fontSize: 14,
                                ),
                                textDirection: pw.TextDirection.rtl,
                              ),
                              pw.SizedBox(height: 10),
                              pw.Row(
                                children: [
                                  pw.Expanded(
                                    flex: 3,
                                    child: _buildCompressedPdfUnit(
                                      reorderedUnits.isNotEmpty
                                          ? reorderedUnits[0]
                                          : {},
                                      arabicBoldFont,
                                      true,
                                    ),
                                  ),
                                  pw.SizedBox(width: 3),
                                  pw.Expanded(
                                    flex: 2,
                                    child: _buildCompressedPdfUnit(
                                      reorderedUnits.length > 1
                                          ? reorderedUnits[1]
                                          : {},
                                      arabicBoldFont,
                                      false,
                                    ),
                                  ),
                                  pw.SizedBox(width: 2),
                                  pw.Expanded(
                                    flex: 2,
                                    child: _buildCompressedPdfUnit(
                                      reorderedUnits.length > 2
                                          ? reorderedUnits[2]
                                          : {},
                                      arabicBoldFont,
                                      false,
                                    ),
                                  ),
                                  pw.SizedBox(width: 3),
                                  pw.Expanded(
                                    flex: 3,
                                    child: _buildCompressedPdfUnit(
                                      reorderedUnits.length > 3
                                          ? reorderedUnits[3]
                                          : {},
                                      arabicBoldFont,
                                      true,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Close loading dialog
      Navigator.of(context).pop();

      // Print the PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في الطباعة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  pw.Widget _buildPdfUnit(
    Map<String, dynamic> unit,
    pw.Font font,
    bool isLarge,
  ) {
    if (unit.isEmpty) {
      return pw.Container(
        height: isLarge ? 50 : 35,
        decoration: pw.BoxDecoration(
          color: PdfColors.grey300,
          borderRadius: pw.BorderRadius.circular(6),
        ),
      );
    }

    return pw.Container(
      height: isLarge ? 50 : 35,
      decoration: pw.BoxDecoration(
        color: _getPdfColor(unit['color']),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Center(
        child: pw.Text(
          unit['name'] ?? '',
          style: pw.TextStyle(
            font: font,
            fontSize: isLarge ? 16 : 14,
            color: PdfColors.white,
          ),
          textDirection: pw.TextDirection.rtl,
        ),
      ),
    );
  }

  pw.Widget _buildPdfLegendItem(String text, String colorHex, pw.Font font) {
    return pw.Row(
      children: [
        pw.Container(width: 12, height: 12, color: PdfColor.fromHex(colorHex)),
        pw.SizedBox(width: 3),
        pw.Text(
          text,
          style: pw.TextStyle(font: font, fontSize: 8),
          textDirection: pw.TextDirection.rtl,
        ),
      ],
    );
  }

  pw.Widget _buildCompressedPdfUnit(
    Map<String, dynamic> unit,
    pw.Font font,
    bool isLarge,
  ) {
    if (unit.isEmpty) {
      return pw.Container(
        height: isLarge ? 40 : 30,
        decoration: pw.BoxDecoration(
          color: PdfColors.grey300,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        ),
      );
    }

    return pw.Container(
      height: isLarge ? 40 : 30,
      decoration: pw.BoxDecoration(
        color: _getPdfColor(unit['color']),
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfColors.black, width: 0.5),
      ),
      child: pw.Padding(
        padding: pw.EdgeInsets.all(2),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              unit['name'] ?? '',
              style: pw.TextStyle(
                font: font,
                fontSize: isLarge ? 11 : 9,
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
              ),
              textDirection: pw.TextDirection.rtl,
            ),
            if (unit['details'] != null &&
                unit['details'].toString().isNotEmpty)
              pw.Text(
                _getCompressedDescription(unit['details']),
                style: pw.TextStyle(
                  font: font,
                  fontSize: isLarge ? 7 : 6,
                  color: PdfColors.white,
                ),
                textDirection: pw.TextDirection.rtl,
                maxLines: 1,
              ),
            if (unit['area'] != null)
              pw.Text(
                '${unit['area']}م²',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 5,
                  color: PdfColors.white,
                ),
                textDirection: pw.TextDirection.rtl,
              ),
          ],
        ),
      ),
    );
  }

  String _getCompressedDescription(String description) {
    if (description.isEmpty) return '';
    List<String> words = description.split(' ');
    return words.take(3).join(' ');
  }

  String _getCompressedFloorTitle(String title) {
    return title.replaceAll('الطابق', 'ط').replaceAll('الأرضي', 'أرضي');
  }

  PdfColor _getPdfColor(dynamic color) {
    if (color == null) return PdfColors.grey;

    // Convert Flutter Color to PdfColor
    if (color.toString().contains('0xff1976d2') ||
        color.toString().contains('blue')) {
      return PdfColor.fromHex('#1976D2');
    } else if (color.toString().contains('0xffeeff00') ||
        color.toString().contains('yellow')) {
      return PdfColor.fromHex('#EEFF00');
    } else if (color.toString().contains('0xffd32f2f') ||
        color.toString().contains('red')) {
      return PdfColor.fromHex('#D32F2F');
    }

    return PdfColors.grey;
  }
}
