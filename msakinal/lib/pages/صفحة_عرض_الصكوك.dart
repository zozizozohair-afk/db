import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

class DeedsDisplayPage extends StatefulWidget {
  const DeedsDisplayPage({super.key});

  @override
  _DeedsDisplayPageState createState() => _DeedsDisplayPageState();
}

class _DeedsDisplayPageState extends State<DeedsDisplayPage> {
  final TextEditingController searchController = TextEditingController();
  final TextEditingController projectFilterController = TextEditingController();

  List<Map<String, dynamic>> allDeeds = [];
  List<Map<String, dynamic>> filteredDeeds = [];
  List<String> availableProjects = [];
  String? selectedProject;
  bool loading = false;
  bool showOnlyWithDeeds = false;

  @override
  void initState() {
    super.initState();
    _loadAllDeeds();
  }

  @override
  void dispose() {
    searchController.dispose();
    projectFilterController.dispose();
    super.dispose();
  }

  // تحميل جميع الصكوك من Firebase و Supabase
  Future<void> _loadAllDeeds() async {
    setState(() => loading = true);

    try {
      // جلب بيانات الشقق من Firebase
      final apartmentsSnapshot =
          await FirebaseFirestore.instance.collection('apartments').get();

      List<Map<String, dynamic>> tempDeeds = [];
      Set<String> projects = {};

      for (var doc in apartmentsSnapshot.docs) {
        final data = doc.data();
        final projectNumber = data['projectNumber']?.toString() ?? '';
        final apartmentNumber = data['number']?.toString() ?? '';

        if (projectNumber.isNotEmpty) {
          projects.add(projectNumber);
        }

        // إنشاء بيانات الصك الأساسية
        Map<String, dynamic> deedData = {
          'id': doc.id,
          'apartmentNumber': apartmentNumber,
          'projectNumber': projectNumber,
          'direction': data['direction'] ?? '',
          'deedNumber': data['deedNumber'] ?? '',
          'deedDate': data['deedDate'] ?? '',
          'code': data['code'] ?? '',
          'deedPdfUploaded': data['deedPdfUploaded'] ?? false,
          'deedUploadDate': data['deedUploadDate'],
          'customerName': data['customerName'] ?? '',
          'hasFile': false,
          'fileUrl': null,
          'fileName': null,
          'fileSize': null,
          'uploadDate': null,
        };

        // فحص وجود ملف الصك في Supabase
        try {
          // إنشاء apartment_id بصيغة "رقم الشقة-رقم المشروع"
          final apartmentId = '$apartmentNumber-$projectNumber';

          final supabaseFiles = await Supabase.instance.client
              .from('deed_files')
              .select('*')
              .eq('apartment_id', apartmentId);

          if (supabaseFiles.isNotEmpty) {
            final fileData = supabaseFiles.first;
            deedData['hasFile'] = true;
            deedData['fileUrl'] = fileData['file_url'];
            deedData['fileName'] = fileData['file_name'];
            deedData['fileSize'] = fileData['file_size'];
            deedData['uploadDate'] = fileData['upload_date'];
          }
        } catch (e) {
          print('خطأ في جلب ملف الصك للشقة $apartmentNumber: $e');
        }

        tempDeeds.add(deedData);
      }

      // ترتيب البيانات حسب رقم المشروع ثم رقم الشقة
      tempDeeds.sort((a, b) {
        final projectA = int.tryParse(a['projectNumber'].toString()) ?? 0;
        final projectB = int.tryParse(b['projectNumber'].toString()) ?? 0;
        if (projectA != projectB) {
          return projectA.compareTo(projectB);
        }
        final numberA = int.tryParse(a['apartmentNumber'].toString()) ?? 0;
        final numberB = int.tryParse(b['apartmentNumber'].toString()) ?? 0;
        return numberA.compareTo(numberB);
      });

      setState(() {
        allDeeds = tempDeeds;
        filteredDeeds = List.from(allDeeds);
        availableProjects = projects.toList()..sort();
      });
    } catch (e) {
      print('خطأ في تحميل الصكوك: $e');
      _showMessage('حدث خطأ في تحميل البيانات', isError: true);
    } finally {
      setState(() => loading = false);
    }
  }

  // تطبيق الفلاتر
  void _applyFilters() {
    setState(() {
      filteredDeeds =
          allDeeds.where((deed) {
            // فلتر النص
            final searchText = searchController.text.toLowerCase();
            final matchesSearch =
                searchText.isEmpty ||
                deed['apartmentNumber'].toString().contains(searchText) ||
                deed['deedNumber'].toString().toLowerCase().contains(
                  searchText,
                ) ||
                deed['customerName'].toString().toLowerCase().contains(
                  searchText,
                );

            // فلتر المشروع
            final matchesProject =
                selectedProject == null ||
                deed['projectNumber'] == selectedProject;

            // فلتر الصكوك المرفوعة فقط
            final matchesFileFilter = !showOnlyWithDeeds || deed['hasFile'];

            return matchesSearch && matchesProject && matchesFileFilter;
          }).toList();
    });
  }

  // عرض رسالة
  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // فتح ملف الصك
  Future<void> _openDeedFile(String? fileUrl) async {
    if (fileUrl == null || fileUrl.isEmpty) {
      _showMessage('رابط الملف غير متوفر', isError: true);
      return;
    }

    try {
      final uri = Uri.parse(fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showMessage('لا يمكن فتح الملف', isError: true);
      }
    } catch (e) {
      _showMessage('خطأ في فتح الملف: $e', isError: true);
    }
  }

  // حذف ملف الصك
  Future<void> _deleteDeedFile(Map<String, dynamic> deed) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('تأكيد الحذف'),
            content: Text(
              'هل أنت متأكد من حذف ملف الصك للشقة رقم ${deed['apartmentNumber']}؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text('حذف'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      // حذف من Supabase Storage
      if (deed['fileName'] != null) {
        final storagePath = 'deeds/${deed['fileName']}';
        await Supabase.instance.client.storage.from('deeds').remove([
          storagePath,
        ]);
      }

      // حذف من جدول deed_files
      // إنشاء apartment_id بصيغة "رقم الشقة-رقم المشروع"
      final apartmentId = '${deed['apartmentNumber']}-${deed['projectNumber']}';

      await Supabase.instance.client
          .from('deed_files')
          .delete()
          .eq('apartment_id', apartmentId);

      // تحديث Firebase
      await FirebaseFirestore.instance
          .collection('apartments')
          .doc(deed['id'])
          .update({
            'deedPdfUploaded': false,
            'deedUploadDate': FieldValue.delete(),
          });

      _showMessage('تم حذف ملف الصك بنجاح');
      _loadAllDeeds(); // إعادة تحميل البيانات
    } catch (e) {
      _showMessage('خطأ في حذف الملف: $e', isError: true);
    }
  }

  // بناء بطاقة الصك
  Widget _buildDeedCard(Map<String, dynamic> deed) {
    final hasFile = deed['hasFile'] as bool;
    final fileSize = deed['fileSize'];
    final fileSizeText =
        fileSize != null
            ? '${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB'
            : '';

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // رأس البطاقة
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'شقة رقم ${deed['apartmentNumber']}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      Text(
                        'مشروع: ${deed['projectNumber']}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                // حالة الصك
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: hasFile ? Colors.green[100] : Colors.orange[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasFile ? Icons.check_circle : Icons.pending,
                        size: 16,
                        color: hasFile ? Colors.green : Colors.orange,
                      ),
                      SizedBox(width: 4),
                      Text(
                        hasFile ? 'مرفوع' : 'غير مرفوع',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              hasFile ? Colors.green[800] : Colors.orange[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // معلومات الصك
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildInfoRow('الاتجاه', deed['direction']),
                  _buildInfoRow('رقم الصك', deed['deedNumber']),
                  _buildInfoRow('تاريخ الصك', deed['deedDate']),
                  _buildInfoRow('الترقيم', deed['code']),
                  if (deed['customerName'].isNotEmpty)
                    _buildInfoRow('اسم العميل', deed['customerName']),
                ],
              ),
            ),

            // معلومات الملف
            if (hasFile) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('اسم الملف', deed['fileName']),
                    if (fileSizeText.isNotEmpty)
                      _buildInfoRow('حجم الملف', fileSizeText),
                    if (deed['uploadDate'] != null)
                      _buildInfoRow(
                        'تاريخ الرفع',
                        DateTime.parse(
                          deed['uploadDate'],
                        ).toString().split(' ')[0],
                      ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 12),

            // أزرار العمليات
            Row(
              children: [
                if (hasFile) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openDeedFile(deed['fileUrl']),
                      icon: Icon(Icons.open_in_new, size: 18),
                      label: Text('فتح الملف'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _deleteDeedFile(deed),
                      icon: Icon(Icons.delete, size: 18),
                      label: Text('حذف'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Center(
                        child: Text(
                          'لم يتم رفع ملف الصك بعد',
                          style: TextStyle(
                            color: Colors.orange[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // بناء صف المعلومات
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'غير محدد' : value,
              style: TextStyle(
                color: value.isEmpty ? Colors.grey[500] : Colors.black87,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // بناء شريط البحث والفلاتر
  Widget _buildSearchAndFilters() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // شريط البحث
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'البحث برقم الشقة، رقم الصك، أو اسم العميل...',
              prefixIcon: Icon(Icons.search),
              suffixIcon:
                  searchController.text.isNotEmpty
                      ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          searchController.clear();
                          _applyFilters();
                        },
                      )
                      : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            onChanged: (value) => _applyFilters(),
          ),

          SizedBox(height: 12),

          // فلاتر
          Row(
            children: [
              // فلتر المشروع
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: selectedProject,
                  decoration: InputDecoration(
                    labelText: 'فلتر المشروع',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text('جميع المشاريع'),
                    ),
                    ...availableProjects.map(
                      (project) => DropdownMenuItem<String>(
                        value: project,
                        child: Text('مشروع $project'),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedProject = value;
                    });
                    _applyFilters();
                  },
                ),
              ),

              SizedBox(width: 12),

              // فلتر الصكوك المرفوعة
              Expanded(
                flex: 1,
                child: CheckboxListTile(
                  title: Text('المرفوعة فقط', style: TextStyle(fontSize: 12)),
                  value: showOnlyWithDeeds,
                  onChanged: (value) {
                    setState(() {
                      showOnlyWithDeeds = value ?? false;
                    });
                    _applyFilters();
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // بناء إحصائيات
  Widget _buildStatistics() {
    final totalDeeds = filteredDeeds.length;
    final uploadedDeeds = filteredDeeds.where((deed) => deed['hasFile']).length;
    final pendingDeeds = totalDeeds - uploadedDeeds;
    final uploadPercentage =
        totalDeeds > 0 ? (uploadedDeeds / totalDeeds * 100) : 0;

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[600]!, Colors.blue[800]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'إحصائيات الصكوك',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'المجموع',
                  totalDeeds.toString(),
                  Icons.description,
                  Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'مرفوعة',
                  uploadedDeeds.toString(),
                  Icons.cloud_done,
                  Colors.green[100]!,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'معلقة',
                  pendingDeeds.toString(),
                  Icons.pending,
                  Colors.orange[100]!,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'النسبة',
                  '${uploadPercentage.toStringAsFixed(1)}%',
                  Icons.analytics,
                  Colors.purple[100]!,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // بناء بطاقة إحصائية
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 24,
            color: color == Colors.white ? Colors.blue[800] : Colors.grey[700],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color:
                  color == Colors.white ? Colors.blue[800] : Colors.grey[800],
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color:
                  color == Colors.white ? Colors.blue[600] : Colors.grey[600],
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
        title: Text('عرض الصكوك'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAllDeeds,
            tooltip: 'تحديث البيانات',
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث والفلاتر
          _buildSearchAndFilters(),

          // الإحصائيات
          _buildStatistics(),

          // قائمة الصكوك
          Expanded(
            child:
                loading
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('جاري تحميل البيانات...'),
                        ],
                      ),
                    )
                    : filteredDeeds.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'لا توجد نتائج',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'جرب تغيير معايير البحث أو الفلاتر',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: filteredDeeds.length,
                      itemBuilder: (context, index) {
                        return _buildDeedCard(filteredDeeds[index]);
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
