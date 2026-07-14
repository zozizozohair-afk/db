import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:msakinal/priovider/auth_provider.dart';
import 'package:provider/provider.dart';

import 'class/logger.dart';
import 'massg.dart';

class ApartmentGeneratorPage extends StatefulWidget {
  const ApartmentGeneratorPage({super.key});

  @override
  _ApartmentGeneratorPageState createState() => _ApartmentGeneratorPageState();
}

class _ApartmentGeneratorPageState extends State<ApartmentGeneratorPage> {
  final projectNumberController = TextEditingController();
  final floorCountController = TextEditingController();
  final apartmentsPerFloorController = TextEditingController();
  final frontApartmentsController = TextEditingController();
  final backApartmentsController = TextEditingController();
  final deedNumberController = TextEditingController();
  final cityController = TextEditingController();
  final districtController = TextEditingController();
  final planNumberController = TextEditingController();
  final regionNumberController = TextEditingController();
  final deedDateController = TextEditingController();

  String selectedProjectDirection = 'شمالي';

  final Map<String, TextEditingController> descriptionControllers = {};
  final Map<String, TextEditingController> areaControllers = {};

  List<Map<String, String>> generatedApartments = [];

  bool showUploadButton = false;
  bool isUploading = false;
  bool showFiveApartmentOptions = false;
  bool showThreeApartmentOptions = false;
  bool showManualDirectionOptions = false;

  // متحكمات الاتجاهات اليدوية للشقق الثلاث
  final apartment1DirectionController = TextEditingController();
  final apartment2DirectionController = TextEditingController();
  final apartment3DirectionController = TextEditingController();

  List<String> usedDirections = [];

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isWide = screenSize.width > 1200;
    final isTablet = screenSize.width > 768 && screenSize.width <= 1200;
    final isMobile = screenSize.width <= 768;

    int crossAxisCount =
        isWide
            ? 4
            : isTablet
            ? 3
            : isMobile
            ? 1
            : 2;
    double horizontalPadding =
        isWide
            ? screenSize.width * 0.15
            : isTablet
            ? screenSize.width * 0.08
            : 16.0;

    return Theme(
      data: Theme.of(context).copyWith(
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 4,
            shadowColor: Colors.black26,
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 32 : 24,
              vertical: isWide ? 16 : 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.blue.shade600, width: 2.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red.shade400, width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: isWide ? 18 : 16,
          ),
          labelStyle: TextStyle(
            fontSize: isWide ? 16 : 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
      ),
      child: Scaffold(
        floatingActionButton: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade800.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ApartmentsListPage()),
              );
            },
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            elevation: 0,
            icon: const Icon(Icons.apartment, size: 24),
            label: Text(
              'قائمة الشقق',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),

        appBar: AppBar(
          title: Text(
            'توليد الشقق',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isWide ? 24 : 20,
              color: Colors.white,
            ),
          ),
          elevation: 0,
          backgroundColor: Colors.blue.shade800,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue.shade800, Colors.blue.shade600],
              ),
            ),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 26),
                tooltip: 'إعادة تعيين',
                onPressed: () {
                  setState(() {
                    generatedApartments.clear();
                    showUploadButton = false;
                  });
                },
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.blue.shade50.withOpacity(0.3),
                Colors.grey.shade50,
                Colors.white,
              ],
              stops: const [0.0, 0.3, 1.0],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: isWide ? 24.0 : 16.0,
            ),
            child: ListView(
              children: [
                // قسم معلومات المشروع الأساسية
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade100.withOpacity(0.5),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.grey.shade200.withOpacity(0.8),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(isWide ? 28 : 20),
                  margin: const EdgeInsets.only(bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.home_work_rounded,
                              color: Colors.blue.shade700,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'معلومات المشروع الأساسية',
                            style: TextStyle(
                              fontSize: isWide ? 20 : 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: isWide ? 20 : 16,
                        runSpacing: isWide ? 16 : 12,
                        children: [
                          _buildField(projectNumberController, 'رقم المشروع'),
                          _buildDropdown(),
                          _buildField(floorCountController, 'عدد الطوابق'),
                          _buildApartmentsPerFloorField(),
                          if (showFiveApartmentOptions) ...[
                            _buildField(
                              frontApartmentsController,
                              'عدد الشقق الخلفية',
                            ),
                            _buildField(
                              backApartmentsController,
                              'عدد الشقق الامامية',
                            ),
                          ],
                          if (showThreeApartmentOptions) ...[
                            _buildField(
                              frontApartmentsController,
                              'عدد الشقق الأمامية (الحد الأقصى 2)',
                            ),
                            _buildField(
                              backApartmentsController,
                              'عدد الشقق الخلفية (الحد الأقصى 2)',
                            ),
                            // زر تفعيل التحديد اليدوي للاتجاهات
                            Container(
                              width: isWide ? 300 : double.infinity,
                              margin: const EdgeInsets.only(top: 10),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    showManualDirectionOptions = !showManualDirectionOptions;
                                    if (!showManualDirectionOptions) {
                                      apartment1DirectionController.clear();
                                      apartment2DirectionController.clear();
                                      apartment3DirectionController.clear();
                                    }
                                  });
                                },
                                icon: Icon(
                                  showManualDirectionOptions 
                                    ? Icons.visibility_off 
                                    : Icons.edit_location_alt,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  showManualDirectionOptions 
                                    ? 'إخفاء التحديد اليدوي' 
                                    : 'تحديد اتجاه كل شقة يدوياً',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: showManualDirectionOptions 
                                    ? Colors.orange 
                                    : Colors.blue,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20, 
                                    vertical: 12
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (showManualDirectionOptions) ...[
                            _buildField(
                              apartment1DirectionController,
                              'اتجاه الشقة رقم 1',
                            ),
                            _buildField(
                              apartment2DirectionController,
                              'اتجاه الشقة رقم 2',
                            ),
                            _buildField(
                              apartment3DirectionController,
                              'اتجاه الشقة رقم 3',
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isWide ? 28 : 20),
                // قسم معلومات الصك والموقع
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.shade100.withOpacity(0.5),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.grey.shade200.withOpacity(0.8),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(isWide ? 28 : 20),
                  margin: const EdgeInsets.only(bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.location_on_rounded,
                              color: Colors.green.shade700,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'معلومات الصك والموقع',
                            style: TextStyle(
                              fontSize: isWide ? 20 : 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: isWide ? 20 : 16,
                        runSpacing: isWide ? 16 : 12,
                        children: [
                          _buildField(deedNumberController, 'رقم الصك'),
                          _buildField(
                            deedDateController,
                            'تاريخ الصك (مثال: 2024-12-31)',
                          ),
                          _buildField(cityController, 'المدينة'),
                          _buildField(districtController, 'الحي'),
                          _buildField(planNumberController, 'رقم المخطط'),
                          _buildField(regionNumberController, 'رقم القطعة'),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isWide ? 28 : 20),
                // قسم الوصف والمساحات
                if (usedDirections.isNotEmpty)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.shade100.withOpacity(0.5),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: Colors.grey.shade200.withOpacity(0.8),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(isWide ? 28 : 20),
                    margin: const EdgeInsets.only(bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.description_rounded,
                                color: Colors.orange.shade700,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'الوصف والمساحات لكل اتجاه',
                              style: TextStyle(
                                fontSize: isWide ? 20 : 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ...usedDirections.map((direction) {
                          if (!descriptionControllers.containsKey(direction)) {
                            descriptionControllers[direction] =
                                TextEditingController();
                          }
                          if (!areaControllers.containsKey(direction)) {
                            areaControllers[direction] =
                                TextEditingController();
                          }
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'اتجاه: $direction',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (isMobile)
                                  Column(
                                    children: [
                                      TextFormField(
                                        controller:
                                            descriptionControllers[direction],
                                        decoration: InputDecoration(
                                          labelText:
                                              'الوصف (عدد الغرف، المطابخ، الصالات...)',
                                          prefixIcon: Icon(
                                            Icons.edit_note_rounded,
                                          ),
                                        ),
                                        maxLines: 2,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: areaControllers[direction],
                                        decoration: InputDecoration(
                                          labelText: 'المساحة (متر مربع)',
                                          prefixIcon: Icon(
                                            Icons.square_foot_rounded,
                                          ),
                                          suffixText: 'م²',
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ],
                                  )
                                else
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: TextFormField(
                                          controller:
                                              descriptionControllers[direction],
                                          decoration: InputDecoration(
                                            labelText:
                                                'الوصف (عدد الغرف، المطابخ، الصالات...)',
                                            prefixIcon: Icon(
                                              Icons.edit_note_rounded,
                                            ),
                                          ),
                                          maxLines: 2,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 1,
                                        child: TextFormField(
                                          controller:
                                              areaControllers[direction],
                                          decoration: InputDecoration(
                                            labelText: 'المساحة (متر مربع)',
                                            prefixIcon: Icon(
                                              Icons.square_foot_rounded,
                                            ),
                                            suffixText: 'م²',
                                          ),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                SizedBox(height: isWide ? 32 : 24),
                // أزرار العمليات
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Container(
                        height: isWide ? 60 : 50,
                        child: ElevatedButton.icon(
                          onPressed: _generateApartments,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            shadowColor: Colors.blue.shade200,
                          ),
                          icon: Icon(
                            Icons.auto_awesome_rounded,
                            size: isWide ? 24 : 20,
                          ),
                          label: Text(
                            'توليد الشقق',
                            style: TextStyle(
                              fontSize: isWide ? 18 : 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (showUploadButton) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          height: isWide ? 60 : 50,
                          child: ElevatedButton.icon(
                            onPressed: isUploading ? null : _confirmUpload,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade400,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                              shadowColor: Colors.green.shade200,
                            ),
                            icon:
                                isUploading
                                    ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : Icon(
                                      Icons.cloud_upload_rounded,
                                      size: isWide ? 24 : 20,
                                    ),
                            label: Text(
                              isUploading ? 'جاري الرفع...' : 'رفع البيانات',
                              style: TextStyle(
                                fontSize: isWide ? 18 : 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: isWide ? 32 : 24),
                // عرض الشقق المولدة
                if (generatedApartments.isNotEmpty) ...[
                  Container(
                    padding: EdgeInsets.all(isWide ? 24 : 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.shade100.withOpacity(0.5),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: Colors.grey.shade200.withOpacity(0.8),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.apartment_rounded,
                                color: Colors.purple.shade700,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'الشقق المولدة (${generatedApartments.length} شقة)',
                              style: TextStyle(
                                fontSize: isWide ? 20 : 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${generatedApartments.length}',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        GridView.count(
                          crossAxisCount: crossAxisCount,
                          shrinkWrap: true,
                          crossAxisSpacing: isWide ? 20 : 16,
                          mainAxisSpacing: isWide ? 20 : 16,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio:
                              isWide
                                  ? 1.2
                                  : isMobile
                                  ? 1.1
                                  : 1.0,
                          children:
                              generatedApartments.map((apartment) {
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white,
                                        Colors.blue.shade50.withOpacity(0.3),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: Colors.blue.shade200,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.shade100.withOpacity(
                                          0.4,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  padding: EdgeInsets.all(isWide ? 16 : 12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // رأس البطاقة
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade700,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'شقة ${apartment['number']}',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: isWide ? 14 : 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // معلومات الشقة
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildApartmentInfo(
                                              Icons.explore_rounded,
                                              'الاتجاه',
                                              apartment['direction'] ?? '',
                                              Colors.orange.shade600,
                                            ),
                                            _buildApartmentInfo(
                                              Icons.layers_rounded,
                                              'الطابق',
                                              apartment['floor'] ?? '',
                                              Colors.green.shade600,
                                            ),
                                            _buildApartmentInfo(
                                              Icons.square_foot_rounded,
                                              'المساحة',
                                              '${apartment['area']} م²',
                                              Colors.purple.shade600,
                                            ),
                                            _buildApartmentInfo(
                                              Icons.check_circle_rounded,
                                              'الحالة',
                                              apartment['status'] ?? '',
                                              Colors.blue.shade600,
                                            ),
                                          ],
                                        ),
                                      ),
                                      // وصف مختصر
                                      if (apartment['description'] != null &&
                                          apartment['description']!.isNotEmpty)
                                        Container(
                                          margin: const EdgeInsets.only(top: 8),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            apartment['description']!.length >
                                                    50
                                                ? '${apartment['description']!.substring(0, 50)}...'
                                                : apartment['description']!,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade700,
                                              height: 1.2,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
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
        items:
            ['شمالي', 'جنوبي', 'شرقي', 'غربي'].map((e) {
              return DropdownMenuItem<String>(value: e, child: Text(e));
            }).toList(),
        onChanged: (value) {
          setState(() {
            selectedProjectDirection = value!;
          });
        },
      ),
    );
  }

  Widget _buildApartmentsPerFloorField() {
    return SizedBox(
      width: 300,
      child: TextFormField(
        controller: apartmentsPerFloorController,
        decoration: InputDecoration(
          labelText: 'عدد الشقق في الطابق',
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        keyboardType: TextInputType.number,
        onChanged: (value) {
          setState(() {
            showFiveApartmentOptions = value == '5';
            showThreeApartmentOptions = value == '3';
            if (!showFiveApartmentOptions && !showThreeApartmentOptions) {
              frontApartmentsController.clear();
              backApartmentsController.clear();
            }
          });
        },
      ),
    );
  }

  void _generateApartments() async {
    final projectNumber = projectNumberController.text.trim();
    final floorCount = int.tryParse(floorCountController.text) ?? 0;
    final apartmentsPerFloor =
        int.tryParse(apartmentsPerFloorController.text) ?? 0;
    final frontApartments = int.tryParse(frontApartmentsController.text) ?? 0;
    final backApartments = int.tryParse(backApartmentsController.text) ?? 0;
    final deedNumber = deedNumberController.text.trim();
    final city = cityController.text.trim();
    final district = districtController.text.trim();
    final planNumber = planNumberController.text.trim();
    final regionNumber = regionNumberController.text.trim();
    final deedDate = deedDateController.text.trim();

    // التحقق من المدخلات
    String? validationError;
    if (projectNumber.isEmpty) {
      validationError = 'يرجى إدخال رقم المشروع';
    } else if (floorCount <= 0) {
      validationError = 'يرجى إدخال عدد طوابق صحيح';
    } else if (apartmentsPerFloor <= 0) {
      validationError = 'يرجى إدخال عدد شقق صحيح لكل طابق';
    } else if (apartmentsPerFloor == 5) {
      if (frontApartments <= 0 || backApartments <= 0) {
        validationError = 'يرجى إدخال عدد الشقق الأمامية والخلفية';
      } else if (frontApartments + backApartments != 5) {
        validationError = 'مجموع الشقق الأمامية والخلفية يجب أن يساوي 5';
      }
    } else if (apartmentsPerFloor == 3) {
      if (showManualDirectionOptions) {
        // التحقق من الاتجاهات اليدوية
        if (apartment1DirectionController.text.trim().isEmpty ||
            apartment2DirectionController.text.trim().isEmpty ||
            apartment3DirectionController.text.trim().isEmpty) {
          validationError = 'يرجى إدخال اتجاه جميع الشقق الثلاث';
        }
      } else {
        // التحقق من الطريقة التقليدية
        if (frontApartments <= 0 || backApartments <= 0) {
          validationError = 'يرجى إدخال عدد الشقق الأمامية والخلفية';
        } else if (frontApartments + backApartments != 3) {
          validationError = 'مجموع الشقق الأمامية والخلفية يجب أن يساوي 3';
        } else if (frontApartments > 2 || backApartments > 2) {
          validationError = 'الحد الأقصى للشقق الأمامية أو الخلفية هو 2';
        }
      }
    } else if (deedNumber.isEmpty) {
      validationError = 'يرجى إدخال رقم الصك';
    } else if (city.isEmpty) {
      validationError = 'يرجى إدخال اسم اللهة';
    } else if (district.isEmpty) {
      validationError = 'يرجى إدخال اسم الحي';
    } else if (planNumber.isEmpty) {
      validationError = 'يرجى إدخال رقم المخطط';
    } else if (regionNumber.isEmpty) {
      validationError = 'يرجى إدخال رقم القطعة';
    } else if (deedDate.isEmpty) {
      validationError = 'يرجى إدخال تاريخ الصك';
    }

    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError, textAlign: TextAlign.center),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // ✅ تحقق من وجود مشروع بنفس الرقم
    final existing =
        await FirebaseFirestore.instance
            .collection('apartments')
            .where('projectNumber', isEqualTo: projectNumber)
            .limit(1)
            .get();

    if (existing.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يوجد مشروع بنفس الرقم مسبقاً. الرجاء اختيار رقم مختلف.',
            textAlign: TextAlign.center,
          ),
        ),
      );
      return;
    }

    List<Map<String, String>> apartments = [];
    List<String> directions;

    if (apartmentsPerFloor == 5) {
      directions = _getFiveApartmentDirections(
        selectedProjectDirection,
        frontApartments,
        backApartments,
      );
    } else if (apartmentsPerFloor == 3) {
      if (showManualDirectionOptions) {
        // استخدام الاتجاهات اليدوية
        directions = [
          apartment1DirectionController.text.trim(),
          apartment2DirectionController.text.trim(),
          apartment3DirectionController.text.trim(),
        ];
      } else {
        // استخدام الطريقة التقليدية
        directions = _getThreeApartmentDirections(
          selectedProjectDirection,
          frontApartments,
          backApartments,
        );
      }
    } else {
      directions = _getDirectionsForProjectDirection(
        selectedProjectDirection,
        floorCount,
      );
    }

    usedDirections = directions.toSet().toList();

    int counter = 1;

    for (int floor = 1; floor <= floorCount; floor++) {
      for (int i = 0; i < apartmentsPerFloor; i++) {
        String dir;
        
        if (apartmentsPerFloor == 3 && showManualDirectionOptions) {
          // تطبيق نمط التكرار للاتجاهات اليدوية
          // الشقة 1 في الدور 1 تأخذ نفس اتجاه الشقة 1 في الدور 4، وهكذا
          dir = directions[i % directions.length];
        } else {
          // الطريقة التقليدية
          dir = directions[i % directions.length];
        }
        
        apartments.add({
          'number': counter.toString(),
          'pn': '$projectNumber-$counter',
          'direction': dir,
          'description': descriptionControllers[dir]?.text ?? '',
          'area': areaControllers[dir]?.text ?? '',
          'projectNumber': projectNumber,
          'deedNumber': deedNumber,
          'deedDate': deedDate,
          'city': city,
          'district': district,
          'planNumber': planNumber,
          'regionNumber': regionNumber,
          'floor': floor.toString(),
          'status': 'متاح',
        });
        counter++;
      }

      if (floor == floorCount) {
        int folorr = floorCount + 1;
        List<String> annexes = _getAnnexDirectionsForProjectDirection(
          selectedProjectDirection,
        );
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
            'pn': '$projectNumber-$counter',
            'direction': annex,
            'description': descriptionControllers[annex]?.text ?? '',
            'area': areaControllers[annex]?.text ?? '',
            'projectNumber': projectNumber,
            'deedNumber': deedNumber,
            'deedDate': deedDate,
            'city': city,
            'floor': '$folorr',
            'district': district,
            'planNumber': planNumber,
            'regionNumber': regionNumber,
            'status': 'متاح',
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

  List<String> _getFiveApartmentDirections(
    String projectDir,
    int frontCount,
    int backCount,
  ) {
    List<String> directions = [];

    switch (projectDir) {
      case 'شمالي':
        if (frontCount == 2 && backCount == 3) {
          directions = [
            'شمالية شرقية أمامية',
            'شمالية وسطى أمامية',
            'شمالية غربية أمامية',
            'جنوبية غربية خلفية',
            'جنوبية شرقية خلفية',
          ];
        } else if (frontCount == 3 && backCount == 2) {
          directions = [
            'شمالية شرقية أمامية',
            'شمالية غربية أمامية',
            'جنوبية غربية خلفية',
            'جنوبية وسطى خلفية',
            'جنوبية شرقية خلفية',
          ];
        } else {
          // توزيع افتراضي
          directions = [
            'شمالية شرقية أمامية',
            'شمالية غربية أمامية',
            'جنوبية غربية خلفية',
            'جنوبية وسطى خلفية',
            'جنوبية شرقية خلفية',
          ];
        }
        break;
      case 'جنوبي':
        if (frontCount == 2 && backCount == 3) {
          directions = [
            'جنوبية غربية أمامية',
            'جنوبية وسطى أمامية',
            'جنوبية شرقية أمامية',
            'شمالية شرقية خلفية',
            'شمالية غربية خلفية',
          ];
        } else if (frontCount == 3 && backCount == 2) {
          directions = [
            'جنوبية غربية أمامية',
            'جنوبية شرقية أمامية',
            'شمالية شرقية خلفية',
            'شمالية وسطى خلفية',
            'شمالية غربية خلفية',
          ];
        } else {
          directions = [
            'جنوبية غربية أمامية',
            'جنوبية شرقية أمامية',
            'شمالية شرقية خلفية',
            'شمالية وسطى خلفية',
            'شمالية غربية خلفية',
          ];
        }
        break;
      case 'شرقي':
        if (frontCount == 2 && backCount == 3) {
          directions = [
            'شرقية جنوبية أمامية',
            'شرقية وسطى أمامية',
            'شرقية شمالية أمامية',
            'غربية شمالية خلفية',
            'غربية جنوبية خلفية',
          ];
        } else if (frontCount == 3 && backCount == 2) {
          directions = [
            'شرقية جنوبية أمامية',
            'شرقية شمالية أمامية',
            'غربية شمالية خلفية',
            'غربية وسطى خلفية',
            'غربية جنوبية خلفية',
          ];
        } else {
          directions = [
            'شرقية جنوبية أمامية',
            'شرقية شمالية أمامية',
            'غربية شمالية خلفية',
            'غربية وسطى خلفية',
            'غربية جنوبية خلفية',
          ];
        }
        break;
      case 'غربي':
      default:
        if (frontCount == 2 && backCount == 3) {
          directions = [
            'غربية شمالية أمامية',
            'غربية وسطى أمامية',
            'غربية جنوبية أمامية',
            'شرقية جنوبية خلفية',
            'شرقية شمالية خلفية',
          ];
        } else if (frontCount == 3 && backCount == 2) {
          directions = [
            'غربية شمالية أمامية',
            'غربية جنوبية أمامية',
            'شرقية جنوبية خلفية',
            'شرقية وسطى خلفية',
            'شرقية شمالية خلفية',
          ];
        } else {
          directions = [
            'غربية شمالية أمامية',
            'غربية جنوبية أمامية',
            'شرقية جنوبية خلفية',
            'شرقية وسطى خلفية',
            'شرقية شمالية خلفية',
          ];
        }
        break;
    }

    return directions;
  }

  List<String> _getThreeApartmentDirections(
    String projectDirection,
    int frontCount,
    int backCount,
  ) {
    List<String> directions = [];

    switch (projectDirection) {
      case 'شمالي':
        if (frontCount == 2 && backCount == 1) {
          directions = [
            'شمالية شرقية أمامية',
            'شمالية غربية أمامية',
            'شرقية غربية خلفية',
          ];
        } else if (frontCount == 1 && backCount == 2) {
          directions = [
            'غربية شرقية أمامية',
            'جنوبية غربية خلفية',
            'جنوبية شرقية خلفية',
          ];
        }
        break;
      case 'جنوبي':
        if (frontCount == 2 && backCount == 1) {
          directions = [
            'جنوبية غربية أمامية',
            'جنوبية شرقية أمامية',
            'غربية شرقية خلفية',
          ];
        } else if (frontCount == 1 && backCount == 2) {
          directions = [
            'شرقية غربية أمامية',
            'شمالية شرقية خلفية',
            'شمالية غربية خلفية',
          ];
        }
        break;
      case 'شرقي':
        if (frontCount == 2 && backCount == 1) {
          directions = [
            'شرقية جنوبية أمامية',
            'شرقية شمالية أمامية',
            'جنوبية شمالية خلفية',
          ];
        } else if (frontCount == 1 && backCount == 2) {
          directions = [
            'شمالية جنوبية أمامية',
            'غربية شمالية خلفية',
            'غربية جنوبية خلفية',
          ];
        }
        break;
      case 'غربي':
      default:
        if (frontCount == 2 && backCount == 1) {
          directions = [
            'غربية شمالية أمامية',
            'غربية جنوبية أمامية',
            'شمالية جنوبية خلفية',
          ];
        } else if (frontCount == 1 && backCount == 2) {
          directions = [
            'جنوبية شمالية أمامية',
            'شرقية جنوبية خلفية',
            'شرقية شمالية خلفية',
          ];
        }
        break;
    }

    return directions;
  }

  List<String> _getDirectionsForProjectDirection(String dir, int floors) {
    switch (dir) {
      case 'شمالي':
        return [
          'شمالية شرقية أمامية',
          'شمالية غربية أمامية',
          'جنوبية غربية خلفية',
          'جنوبية شرقية خلفية',
        ];
      case 'جنوبي':
        return [
          'جنوبية غربية أمامية',
          'جنوبية شرقية أمامية',
          'شمالية شرقية خلفية',
          'شمالية غربية خلفية',
        ];
      case 'شرقي':
        return [
          'شرقية جنوبية أمامية',
          'شرقية شمالية أمامية',
          'غربية شمالية خلفية',
          'غربية جنوبية خلفية',
        ];
      case 'غربي':
      default:
        return [
          'غربية شمالية أمامية',
          'غربية جنوبية أمامية',
          'شرقية جنوبية خلفية',
          'شرقية شمالية خلفية',
        ];
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

  void _confirmUpload() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('تأكيد الرفع'),
            content: Text('هل أنت متأكد من رفع البيانات؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('تأكيد'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      _uploadToFirebase();
    }
  }

  void _uploadToFirebase() async {
    final username =
        Provider.of<AppAuthProvider>(context, listen: false).username;
    setState(() => isUploading = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final collection1 = FirebaseFirestore.instance.collection('apartments');

      for (var apt in generatedApartments) {
        final doc = collection1.doc();
        batch.set(doc, apt);
        final apartmentNumber = apt['pn'] ?? '';

        await logAction(
          category: 'شقق',
          action: 'اضافة',
          itemId: apartmentNumber,
          userId: '$username',
          oldData: {'status': 'متاح'},
          newData: {'status': 'محجوز'},
        );
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم رفع البيانات بنجاح', textAlign: TextAlign.center),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في رفع البيانات: $e', textAlign: TextAlign.center),
        ),
      );
    }

    setState(() => isUploading = false);
  }

  Widget _buildApartmentInfo(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$label: $value',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
