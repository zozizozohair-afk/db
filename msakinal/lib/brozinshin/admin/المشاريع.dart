import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ApartmentsUpdatesPage extends StatelessWidget {
  const ApartmentsUpdatesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('📢 التحديثات على الشقق')),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('apartments')
                .orderBy(
                  'number',
                ) // تقدر تستخدم تاريخ التعديل لو تضيفه مستقبلاً
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final apartments = snapshot.data!.docs;

          return ListView.builder(
            itemCount: apartments.length,
            itemBuilder: (context, index) {
              final data = apartments[index].data() as Map<String, dynamic>;

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text(
                      '${data['number']}',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    'شقة رقم ${data['number']} - ${data['status'] ?? 'بدون حالة'}',
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الاتجاه: ${data['direction'] ?? '-'}'),
                      Text('الوصف: ${data['description'] ?? '-'}'),
                      Text('المساحة: ${data['area'] ?? '-'} م²'),
                      Text('المشروع: ${data['projectNumber'] ?? '-'}'),
                      Text(
                        'الحي: ${data['district'] ?? '-'} - المدينة: ${data['city'] ?? '-'}',
                      ),
                      Text(
                        'رقم الصك: ${data['deedNumber'] ?? '-'} | التاريخ: ${data['deedDate'] ?? '-'}',
                      ),
                    ],
                  ),
                  trailing: Chip(
                    label: Text(data['status'] ?? 'غير معروف'),
                    backgroundColor: _statusColor(data['status']),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'مباع':
        return Colors.red.shade300;
      case 'محجوز':
        return Colors.amber.shade300;
      case 'معروضة للبيع':
        return Colors.purple.shade200;
      case 'تم الإفراغ':
        return Colors.blue.shade300;
      case 'متاح':
      default:
        return Colors.green.shade300;
    }
  }
}
