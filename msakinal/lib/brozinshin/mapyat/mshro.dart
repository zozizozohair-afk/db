import 'dart:html' as html;
import 'dart:typed_data';
import 'package:msakinal/building_layout_page.dart';
import 'package:universal_html/html.dart' show File;
import 'dart:io';

import 'package:supabase/supabase.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/animation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../priovider/auth_provider.dart';
import '../../massg.dart';
import '../../refresh.dart';

class ProjectsPage11 extends StatefulWidget {
  const ProjectsPage11({super.key});

  @override
  _ProjectsPageState createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage11>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _searchQuery = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _projects = [];
  Future<void> _uploadBrochure(String projectNumber) async {
    try {
      // إنشاء input element للملفات
      final input = html.FileUploadInputElement()..accept = 'application/pdf';
      input.click();

      await input.onChange.first;
      if (input.files?.isEmpty ?? true) return;

      final file = input.files!.first;
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);

      await reader.onLoad.first;
      final bytes = reader.result as List<int>;
      final fileName =
          'brochures/brochure_${projectNumber}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // رفع الملف إلى Supabase Storage
      await _supabase.storage
          .from('brochures')
          .uploadBinary(fileName, Uint8List.fromList(bytes));

      // الحصول على رابط التحميل
      final downloadUrl = _supabase.storage
          .from('brochures')
          .getPublicUrl(fileName);

      // ✅ الحصول على الرابط الصحيح

      // حفظ البيانات في جدول البروشورات
      await _supabase.from('brochures').insert([
        {
          'project_number': projectNumber,
          'file_url': downloadUrl,
          'created_at': DateTime.now().toIso8601String(),
        },
      ]);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تم رفع البروشور بنجاح')));
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء الرفع: $e')));
    }
  }

  Future<String?> _getBrochureUrl(String projectNumber) async {
    try {
      final response =
          await _supabase
              .from('brochures')
              .select('file_url')
              .eq('project_number', projectNumber)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle(); // استخدم maybeSingle بدلاً من single

      // التحقق من وجود البيانات قبل الوصول إليها
      if (response != null && response['file_url'] != null) {
        return response['file_url'] as String;
      }
      return null;
    } catch (e) {
      print('Error fetching brochure URL: $e');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _loadProjects();
    _animationController.forward();
  }

  Future<void> _loadProjects() async {
    try {
      final apartments = await _firestore.collection('apartments').get();

      // تجميع المشاريع وعدد الشقق
      Map<String, Map<String, dynamic>> projectsMap = {};

      for (var doc in apartments.docs) {
        final data = doc.data();
        final projectNumber = data['projectNumber']?.toString() ?? 'غير معروف';

        if (!projectsMap.containsKey(projectNumber)) {
          projectsMap[projectNumber] = {
            'projectNumber': projectNumber,
            'city': data['city'],
            'district': data['district'],
            'planNumber': data['planNumber'],
            'deedDate': data['deedDate'],
            'deedNumber': data['deedNumber'],
            'apartmentsCount': 0,
            'apartments': [],
          };
        }

        projectsMap[projectNumber]!['apartmentsCount'] += 1;
        projectsMap[projectNumber]!['apartments'].add(data);
      }

      setState(() {
        _projects = projectsMap.values.toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ في جلب البيانات: ${e.toString()}')),
      );
    }
  }

  void _filterProjects(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  String? pro;
  List<Map<String, dynamic>> get _filteredProjects {
    if (_searchQuery.isEmpty) return _projects;
    return _projects.where((project) {
      return project['projectNumber'].toString().contains(_searchQuery) ||
          (project['city']?.toString() ?? '').toLowerCase().contains(
            _searchQuery,
          ) ||
          (project['district']?.toString() ?? '').toLowerCase().contains(
            _searchQuery,
          );
    }).toList();
  }

  Future<void> _launchBrochure(String projectNumber) async {
    final url = await _getBrochureUrl(projectNumber);

    if (url == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('لا يوجد بروشور لهذا المشروع')));
      return;
    }

    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'تعذر فتح الرابط: $url';
    }
  }

  void _showApartmentsDialog(List<dynamic> apartments) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('الشقق المتاحة'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: apartments.length,
                itemBuilder: (context, index) {
                  final apt = apartments[index];
                  return ListTile(
                    title: Text(
                      'الشقة ${apt['apartmentNumber'] ?? apt['number'] ?? apt['unitNumber'] ?? 'غير معروف'}',
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الاتجاه: ${apt['direction'] ?? apt['unitDirection'] ?? 'غير محدد'}',
                        ),
                        if (apt['status'] != null)
                          Text(
                            'الحالة: ${apt['status']}',
                            style: TextStyle(
                              color: _getStatusColor(apt['status']),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        if (apt['clientName'] != null ||
                            apt['customerName'] != null)
                          Text(
                            'العميل: ${apt['clientName'] ?? apt['customerName']}',
                          ),
                      ],
                    ),
                    trailing: Icon(Icons.chevron_left, color: Colors.blueGrey),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إغلاق'),
              ),
            ],
          ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'تم الافراغ':
        return Colors.green;
      case 'متاح':
        return Colors.blue;
      case 'مباع':
        return Colors.red;
      case 'معروضة للبيع':
        return Colors.purple;
      case 'تحت الاجراء':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildProjectCard(Map<String, dynamic> project, int index) {
    pro = project['projectNumber'];
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Interval(index * 0.1, 1.0, curve: Curves.easeOut),
          ),
        ),
        child: Card(
          elevation: 6,
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blueGrey[50]!, Colors.blueGrey[100]!],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'المشروع ${project['projectNumber']}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[800],
                      ),
                    ),
                    Chip(
                      label: Text(
                        '${project['apartmentsCount']} شقة',
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.blueGrey[600],
                    ),
                  ],
                ),
                Divider(color: Colors.blueGrey[300]),
                _buildProjectDetail('المدينة', project['city']),
                _buildProjectDetail('الحي', project['district']),
                _buildProjectDetail('رقم المخطط', project['planNumber']),
                _buildProjectDetail('تاريخ الصك', project['deedDate']),
                _buildProjectDetail('رقم الصك', project['deedNumber']),
                SizedBox(height: 16),
                Consumer<AppAuthProvider>(
                  builder: (context, authProvider, child) {
                    final userType = authProvider.userType;
                    final isMaster = userType == 'مستر';

                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceAround,
                      children: [
                        // زر عرض البروشور - يظهر للجميع
                        ElevatedButton.icon(
                          icon: Icon(
                            Icons.picture_as_pdf,
                            color: Colors.orange,
                          ),
                          label: Text(
                            'البروشور',
                            style: TextStyle(color: Colors.orange[500]),
                          ),
                          onPressed:
                              () => _launchBrochure(project['projectNumber']),
                        ),

                        // زر مخطط المبنى - يظهر للجميع
                        ElevatedButton.icon(
                          icon: Icon(Icons.apartment, color: Colors.white),
                          label: Text(
                            'مخطط المبنى',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        BuildingLayoutPage(
                                          preselectedProjectNumber:
                                              project['projectNumber'],
                                        ),
                                transitionsBuilder: (
                                  context,
                                  animation,
                                  secondaryAnimation,
                                  child,
                                ) {
                                  var curve = Curves.easeInOut;
                                  var curveTween = CurveTween(curve: curve);

                                  var fadeAnimation = Tween<double>(
                                    begin: 0.0,
                                    end: 1.0,
                                  ).animate(animation.drive(curveTween));

                                  var slideAnimation = Tween<Offset>(
                                    begin: Offset(0.0, 0.5),
                                    end: Offset.zero,
                                  ).animate(animation.drive(curveTween));

                                  return FadeTransition(
                                    opacity: fadeAnimation,
                                    child: SlideTransition(
                                      position: slideAnimation,
                                      child: child,
                                    ),
                                  );
                                },
                                transitionDuration: Duration(milliseconds: 500),
                              ),
                            );
                          },
                        ),

                        // زر رفع البروشور - يظهر فقط للمستر
                        if (isMaster)
                          ElevatedButton.icon(
                            icon: Icon(Icons.upload, color: Colors.white),
                            label: Text(
                              'رفع',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[700],
                            ),
                            onPressed: () {
                              _uploadBrochure(project['projectNumber']);
                            },
                          ),

                        // زر عرض الشقق - يظهر فقط للمستر
                        if (isMaster)
                          ElevatedButton.icon(
                            icon: Icon(
                              Icons.apartment,
                              size: 20,
                              color: Colors.white,
                            ),
                            label: Text(
                              'عرض الشقق',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal[700],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => ApartmentsListPage(
                                        projectNumber: '$pro',
                                      ),
                                ),
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProjectDetail(String label, dynamic value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey[700],
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? 'غير متوفر',
              style: TextStyle(color: Colors.blueGrey[600]),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('المشاريع'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _animationController.reset();
              _loadProjects();
              _animationController.forward();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'ابحث (برقم المشروع، المدينة، الحي)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.blueGrey[50],
              ),
              onChanged: _filterProjects,
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.blueGrey,
                        ),
                      ),
                    )
                    : _filteredProjects.isEmpty
                    ? Center(
                      child: Text(
                        'لا توجد مشاريع متطابقة مع البحث',
                        style: TextStyle(fontSize: 18, color: Colors.blueGrey),
                      ),
                    )
                    : ListView.builder(
                      itemCount: _filteredProjects.length,
                      itemBuilder: (context, index) {
                        return _buildProjectCard(
                          _filteredProjects[index],
                          index,
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
