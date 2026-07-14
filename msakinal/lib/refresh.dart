import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ApartmentsPage extends StatefulWidget {
  final String projectNumber;

  const ApartmentsPage({super.key, required this.projectNumber});

  @override
  _ApartmentsPageState createState() => _ApartmentsPageState();
}

class _ApartmentsPageState extends State<ApartmentsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('شركة مساكن الرفاهية'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade800,
        elevation: 4,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // معلومات المشروع
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.blue.shade900],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.apartment, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'مشروع رقم ${widget.projectNumber}',
                        style: const TextStyle(
                          fontSize: 20, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.white
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '6 غرف ال033م2 السطح خاص 0كم؟',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // قائمة الشقق
            Expanded(
              child:StreamBuilder<QuerySnapshot>(
                     stream: _firestore.collection('apartments')
                     .where('projectNumber', isEqualTo: widget.projectNumber)
                      .orderBy('number')
                      .snapshots(),
                        builder: (context, snapshot) {
                         if (snapshot.hasError) {
                       return Center(child: Text('حدث خطأ: ${snapshot.error}'));
                   }

    if (snapshot.connectionState == ConnectionState.waiting) {
    return Center(child: CircularProgressIndicator());
    }

    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
    return Center(child: Text('لا توجد شقق متاحة'));
    }

    // باقي الكود...
    
                  // تجميع الشقق حسب الدور
                  Map<String, List<DocumentSnapshot>> floors = {};
                  for (var doc in snapshot.data!.docs) {
                    String floor = doc['floor'].toString() ?? 'غير محدد';
                    if (!floors.containsKey(floor)) {
                      floors[floor] = [];
                    }
                    floors[floor]!.add(doc);
                  }

                  return ListView.builder(
                    itemCount: floors.length,
                    itemBuilder: (context, index) {
                      String floor = floors.keys.elementAt(index);
                      List<DocumentSnapshot> floorApartments = floors[floor]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade800,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.3),
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              'الدور $floor',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: floorApartments.map((doc) {
                              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                              return ApartmentCard(
                                number: data['number'].toString() ?? '',
                                status: data['status'] ?? 'متاح',
                                area: data['area'].toString() ?? '',
                                description: data['description'] ?? '',
                                direction: data['direction'] ?? 'غير محدد',
                                onTap: () {
                                  // يمكنك إضافة تفاصيل إضافية عند النقر
                                  _showApartmentDetails(context, data);
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showApartmentDetails(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getStatusColor(data['status'] ?? 'متاح'),
                shape: BoxShape.circle,
              ),
              child: Text(
                data['number'].toString(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'الشقة رقم ${data['number']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailCard('معلومات الشقة', [
                _buildDetailRow('الحالة', data['status'] ?? 'متاح'),
                _buildDetailRow('المساحة', '${data['area']} م²'),
                _buildDetailRow('الاتجاه', data['direction'] ?? 'غير محدد'),
                _buildDetailRow('الوصف', data['description'] ?? '-'),
              ]),
              const SizedBox(height: 12),
              _buildDetailCard('معلومات المشروع', [
                _buildDetailRow('رقم المشروع', data['projectNumber'] ?? '-'),
                _buildDetailRow('اللهة', data['city'] ?? '-'),
                _buildDetailRow('الحي', data['district'] ?? '-'),
                _buildDetailRow('الدور', data['floor'] ?? '-'),
              ]),
              const SizedBox(height: 12),
              _buildDetailCard('معلومات الصك', [
                _buildDetailRow('رقم الصك', data['deedNumber'] ?? '-'),
                _buildDetailRow('تاريخ الصك', data['deedDate'] ?? '-'),
                _buildDetailRow('رقم المخطط', data['planNumber'] ?? '-'),
                _buildDetailRow('رقم المنطقة', data['regionNumber'] ?? '-'),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
  Color _getStatusColor(String status) {
    switch (status) {
      case 'مباع':
        return Colors.red[700]!;
      case 'محجوز':
        return Colors.amber[800]!;
      case 'معروضة للبيع':
        return Colors.purple[800]!;
      case 'تم الإفراغ':
        return Colors.blue[800]!;
      case 'متاح':
        return Colors.green;
      case 'تحت الاجراء':
        return Colors.grey.shade600;
      default:
        return Colors.green[900]!;
    }
  }

}

class ApartmentCard extends StatelessWidget {
  final String number;
  final String status;
  final String area;
  final String description;
  final String direction;
  final VoidCallback onTap;

  const ApartmentCard({
    super.key,
    required this.number,
    required this.status,
    required this.area,
    required this.description,
    required this.direction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: _getCardColor(status),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // شارة الحالة
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            // محتوى البطاقة
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    number,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    area,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    direction,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCardColor(String status) {
    return _getStatusColor(status);
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'مباع':
        return Colors.red[700]!;
      case 'محجوز':
        return Colors.amber[800]!;
      case 'معروضة للبيع':
        return Colors.purple[800]!;
      case 'تم الإفراغ':
        return Colors.blue[800]!;
      case 'متاح':
        return Colors.green;
      case 'تحت الاجراء':
        return Colors.grey.shade600;
      default:
        return Colors.green[900]!;
    }
  }
}