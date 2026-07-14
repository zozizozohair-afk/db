import 'package:flutter/material.dart';
import 'customer_update_service.dart';

/// صفحة اختبار نظام تحديث بيانات العملاء
class TestCustomerUpdatePage extends StatefulWidget {
  const TestCustomerUpdatePage({super.key});

  @override
  _TestCustomerUpdatePageState createState() => _TestCustomerUpdatePageState();
}

class _TestCustomerUpdatePageState extends State<TestCustomerUpdatePage> {
  final _oldIdentityController = TextEditingController();
  final _newNameController = TextEditingController();
  final _newIdentityController = TextEditingController();
  final _newPhoneController = TextEditingController();
  bool _isLoading = false;
  Map<String, int>? _distributionData;
  Map<String, dynamic>? _updateResults;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختبار نظام تحديث بيانات العملاء'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'بيانات العميل الحالية',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _oldIdentityController,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهوية الحالي',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _checkDistribution,
                      icon: const Icon(Icons.analytics),
                      label: const Text('فحص توزيع البيانات'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_distributionData != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'توزيع البيانات الحالية',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._distributionData!.entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(entry.key),
                              Text(
                                '${entry.value} سجل',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'الإجمالي:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${_distributionData!.values.fold(0, (sum, count) => sum + count)} سجل',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'البيانات الجديدة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _newNameController,
                      decoration: const InputDecoration(
                        labelText: 'الاسم الجديد',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newIdentityController,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهوية الجديد',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newPhoneController,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف الجديد',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _updateCustomerData,
                        icon:
                            _isLoading
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                                : const Icon(Icons.update),
                        label: Text(
                          _isLoading ? 'جاري التحديث...' : 'تحديث البيانات',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_updateResults != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _updateResults!['success']
                                ? Icons.check_circle
                                : Icons.error,
                            color:
                                _updateResults!['success']
                                    ? Colors.green
                                    : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'نتائج التحديث',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color:
                                  _updateResults!['success']
                                      ? Colors.green
                                      : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'الحالة: ${_updateResults!['success'] ? 'نجح' : 'فشل'}',
                      ),
                      Text(
                        'إجمالي السجلات المحدثة: ${_updateResults!['totalUpdated']}',
                      ),
                      if (_updateResults!['updatedTables'].isNotEmpty)
                        Text(
                          'الجداول المحدثة: ${(_updateResults!['updatedTables'] as List).join(', ')}',
                        ),
                      if (_updateResults!['errors'].isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'الأخطاء:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        ...(_updateResults!['errors'] as List).map(
                          (error) => Text(
                            '• $error',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _checkDistribution() async {
    if (_oldIdentityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال رقم الهوية الحالي'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final distribution =
          await CustomerUpdateService.checkCustomerDataDistribution(
            _oldIdentityController.text.trim(),
          );

      setState(() {
        _distributionData = distribution;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في فحص البيانات: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateCustomerData() async {
    if (_oldIdentityController.text.trim().isEmpty ||
        _newNameController.text.trim().isEmpty ||
        _newIdentityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى ملء جميع الحقول المطلوبة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _updateResults = null;
    });

    try {
      final results = await CustomerUpdateService.updateCustomerDataEverywhere(
        oldIdentityNumber: _oldIdentityController.text.trim(),
        newCustomerData: {
          'name': _newNameController.text.trim(),
          'identityNumber': _newIdentityController.text.trim(),
          'phoneNumber': _newPhoneController.text.trim(),
        },
        context: context,
      );

      setState(() {
        _updateResults = results;
      });

      // إعادة فحص التوزيع بعد التحديث
      if (results['success']) {
        await _checkDistribution();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تحديث البيانات: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _oldIdentityController.dispose();
    _newNameController.dispose();
    _newIdentityController.dispose();
    _newPhoneController.dispose();
    super.dispose();
  }
}
