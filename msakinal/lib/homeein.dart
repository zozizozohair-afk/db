import 'package:flutter/material.dart';

import 'add.dart';
// تأكد إن الملف موجود بنفس المسار

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    DateTime contractDate = DateTime.now(); // تاريخ توقيع العقد
    DateTime deliveryDate = DateTime(contractDate.year, contractDate.month + 12, contractDate.day); // بعد 12 شهر

    return Scaffold(
      appBar: AppBar(title: Text("صفحة العميل")),
      body: Center(
        child: ElevatedButton(
          child: Text("عرض العداد"),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CountdownScreen(deliveryDate: deliveryDate),
              ),
            );
          },
        ),
      ),
    );
  }
}
