import 'package:flutter/material.dart';
import 'building_layout_page.dart';

void main() {
  runApp(const BuildingLayoutDemo());
}

class BuildingLayoutDemo extends StatelessWidget {
  const BuildingLayoutDemo({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مخطط المبنى',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'Arial'),
      home: const BuildingLayoutPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
