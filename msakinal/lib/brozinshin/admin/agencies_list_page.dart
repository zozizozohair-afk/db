import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AgenciesListPage extends StatefulWidget {
  const AgenciesListPage({super.key});

  @override
  State<AgenciesListPage> createState() => _AgenciesListPageState();
}

class _AgenciesListPageState extends State<AgenciesListPage> {
  final searchController = TextEditingController();
  bool isSelected = false;
  Set<String> selectedItems = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'البحث في الوكالات',
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search, color: Colors.grey),
          ),
          onChanged: (value) => setState(() {}),
        ),
        actions: [
          if (selectedItems.isNotEmpty) ...[
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteSelected(),
            ),
            IconButton(
              icon: Icon(Icons.print, color: Colors.blue),
              onPressed: () => _printSelected(),
            ),
          ],
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('agencies').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          var agencies = snapshot.data!.docs;

          // تطبيق البحث
          if (searchController.text.isNotEmpty) {
            agencies =
                agencies.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['principalName']?.toString().contains(
                        searchController.text,
                      ) ??
                      false ||
                          data['agentName']!.toString().contains(
                            searchController.text,
                          ) ??
                      false ||
                          data['agencyNumber']!.toString().contains(
                            searchController.text,
                          ) ??
                      false;
                }).toList();
          }

          return ListView.builder(
            itemCount: agencies.length,
            itemBuilder: (context, index) {
              final agency = agencies[index].data() as Map<String, dynamic>;
              final docId = agencies[index].id;
              final isItemSelected = selectedItems.contains(docId);

              return Card(
                elevation: 1,
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  children: [
                    ListTile(
                      leading: Checkbox(
                        value: isItemSelected,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              selectedItems.add(docId);
                            } else {
                              selectedItems.remove(docId);
                            }
                          });
                        },
                      ),
                      title: Text(
                        'الموكل: ${agency['principalName']} - الوكيل: ${agency['agentName']}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('رقم الوكالة: ${agency['agencyNumber']}'),
                          Text(
                            'تاريخ الوكالة: ${_formatDate(agency['agencyDate'])}',
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton(
                        itemBuilder:
                            (context) => [
                              PopupMenuItem(
                                child: ListTile(
                                  leading: Icon(Icons.edit, color: Colors.blue),
                                  title: Text('تعديل'),
                                  onTap: () => _editAgency(docId, agency),
                                ),
                              ),
                              PopupMenuItem(
                                child: ListTile(
                                  leading: Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  title: Text('حذف'),
                                  onTap: () => _deleteAgency(docId),
                                ),
                              ),
                              PopupMenuItem(
                                child: ListTile(
                                  leading: Icon(
                                    Icons.print,
                                    color: Colors.green,
                                  ),
                                  title: Text('طباعة'),
                                  onTap: () => _printAgency(agency),
                                ),
                              ),
                              PopupMenuItem(
                                child: ListTile(
                                  leading: Icon(
                                    Icons.history,
                                    color: Colors.purple,
                                  ),
                                  title: Text('استخدامات الوكالة'),
                                  onTap: () => _showAgencyUsages(docId),
                                ),
                              ),
                            ],
                      ),
                    ),
                    // إضافة عرض الاستخدامات
                    StreamBuilder<QuerySnapshot>(
                      stream:
                          FirebaseFirestore.instance
                              .collection('agencyUsages')
                              .where('agencyId', isEqualTo: docId)
                              .snapshots(),
                      builder: (context, usageSnapshot) {
                        if (!usageSnapshot.hasData ||
                            usageSnapshot.data!.docs.isEmpty) {
                          return SizedBox.shrink();
                        }

                        return Container(
                          padding: EdgeInsets.all(8),
                          color: Colors.grey[100],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'استخدامات الوكالة:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple[700],
                                ),
                              ),
                              ...usageSnapshot.data!.docs.map((usage) {
                                final usageData =
                                    usage.data() as Map<String, dynamic>;
                                return Padding(
                                  padding: EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.arrow_right,
                                        color: Colors.grey,
                                      ),
                                      Text(
                                        '${usageData['contractType']} - ${usageData['contractId']}',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addNewAgency(),
        backgroundColor: Colors.blue,
        child: Icon(Icons.add),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'غير محدد';
    if (date is Timestamp) {
      return DateFormat('yyyy/MM/dd').format(date.toDate());
    }
    return date.toString();
  }

  void _deleteSelected() async {
    if (selectedItems.isEmpty) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('تأكيد الحذف'),
            content: Text('هل أنت متأكد من حذف ${selectedItems.length} وكالة؟'),
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

    if (shouldDelete == true) {
      try {
        // التحقق من عدم استخدام أي من الوكالات
        for (String docId in selectedItems) {
          final usagesSnapshot =
              await FirebaseFirestore.instance
                  .collection('agencyUsages')
                  .where('agencyId', isEqualTo: docId)
                  .get();

          if (usagesSnapshot.docs.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('بعض الوكالات مستخدمة ولا يمكن حذفها'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }

        // حذف الوكالات غير المستخدمة
        await Future.wait(
          selectedItems.map(
            (docId) =>
                FirebaseFirestore.instance
                    .collection('agencies')
                    .doc(docId)
                    .delete(),
          ),
        );

        setState(() {
          selectedItems.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حذف الوكالات المحددة بنجاح')),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء الحذف: $e')));
      }
    }
  }

  void _printSelected() async {
    if (selectedItems.isEmpty) return;

    try {
      final selectedAgencies = await Future.wait(
        selectedItems.map(
          (docId) =>
              FirebaseFirestore.instance
                  .collection('agencies')
                  .doc(docId)
                  .get(),
        ),
      );

      final agenciesData =
          selectedAgencies
              .where((doc) => doc.exists)
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();

      // هنا يمكنك إضافة كود الطباعة للوكالات المحددة
      // مثال بسيط للعرض:
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text('الوكالات المحددة للطباعة'),
              content: SingleChildScrollView(
                child: Column(
                  children:
                      agenciesData.map((agency) {
                        return ListTile(
                          title: Text('${agency['agentName']}'),
                          subtitle: Text(
                            'رقم الوكالة: ${agency['agencyNumber']}',
                          ),
                        );
                      }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('إغلاق'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // هنا يمكنك إضافة كود الطباعة الفعلي
                    Navigator.pop(context);
                  },
                  child: Text('طباعة'),
                ),
              ],
            ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    }
  }

  void _editAgency(String docId, Map<String, dynamic> agency) {
    final agentNameController = TextEditingController(
      text: agency['agentName'],
    );
    final agencyNumberController = TextEditingController(
      text: agency['agencyNumber'],
    );
    final agencyDateController = TextEditingController(
      text: agency['agencyDate'],
    );
    final agentIdController = TextEditingController(text: agency['agentId']);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('تعديل الوكالة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: agentNameController,
                    decoration: InputDecoration(labelText: 'اسم الوكيل'),
                  ),
                  TextField(
                    controller: agencyNumberController,
                    decoration: InputDecoration(labelText: 'رقم الوكالة'),
                  ),
                  TextField(
                    controller: agencyDateController,
                    decoration: InputDecoration(labelText: 'تاريخ الوكالة'),
                  ),
                  TextField(
                    controller: agentIdController,
                    decoration: InputDecoration(labelText: 'رقم هوية الوكيل'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await FirebaseFirestore.instance
                        .collection('agencies')
                        .doc(docId)
                        .update({
                          'agentName': agentNameController.text,
                          'agencyNumber': agencyNumberController.text,
                          'agencyDate': agencyDateController.text,
                          'agentId': agentIdController.text,
                        });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تم تحديث الوكالة بنجاح')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('حدث خطأ أثناء التحديث: $e')),
                    );
                  }
                },
                child: Text('حفظ'),
              ),
            ],
          ),
    );
  }

  void _showAgencyUsages(String agencyId) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('استخدامات الوكالة'),
            content: SizedBox(
              width: double.maxFinite,
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('agencyUsages')
                        .where('agencyId', isEqualTo: agencyId)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('حدث خطأ في جلب البيانات');
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Text('لم يتم استخدام هذه الوكالة بعد');
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final usage =
                          snapshot.data!.docs[index].data()
                              as Map<String, dynamic>;
                      return ListTile(
                        title: Text('نوع العقد: ${usage['contractType']}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('رقم العقد: ${usage['contractId']}'),
                            Text('تاريخ الاستخدام: ${usage['usageDate']}'),
                            Text('تفاصيل: ${usage['usageDetails']}'),
                          ],
                        ),
                      );
                    },
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

  void _deleteAgency(String docId) async {
    try {
      // التحقق من استخدام الوكالة
      final usagesSnapshot =
          await FirebaseFirestore.instance
              .collection('agencyUsages')
              .where('agencyId', isEqualTo: docId)
              .get();

      if (usagesSnapshot.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('لا يمكن حذف الوكالة لأنها مستخدمة في عقود'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('agencies')
          .doc(docId)
          .delete();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تم حذف الوكالة بنجاح')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء الحذف: $e')));
    }
  }

  void _printAgency(Map<String, dynamic> agency) {
    // تنفيذ طباعة الوكالة
  }

  void _addNewAgency() {
    // تنفيذ إضافة وكالة جديدة
  }
}
