import 'package:flutter/material.dart';
import 'package:msakinal/astlam.dart';
import 'package:msakinal/mony.dart';

import 'اللطباعة.dart';
import 'جلب.dart';
import 'طباعة محضر الاستلام.dart';
import 'عرض التسويات1.dart';
import 'عرض عقود اعادة بيع.dart';

class ContractsPage12 extends StatefulWidget {
  const ContractsPage12({super.key});

  @override
  State<ContractsPage12> createState() => _ContractsPage12State();
}

class _ContractsPage12State extends State<ContractsPage12> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 600;
            return isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildContractsSection(context),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildAddContractSection(context),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildContractsSection(context),
                        const SizedBox(height: 20),
                        _buildAddContractSection(context),
                      ],
                    ),
                  );
          },
        ),
      ),
    );
  }

  Widget _buildContractsSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment, color: Colors.indigo[700], size: 22),
              const SizedBox(width: 10),
              Text(
                "العقود الحالية",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildNavigationButton(
            context,
            "عقد تحت الإنشاء",
            Icons.edit_document,
            Colors.blue[600]!,
            () => ContractsPage0(),
          ),
          _buildNavigationButton(
            context,
            "عقد إعادة بيع",
            Icons.repeat_one,
            Colors.teal[600]!,
            () => ResaleContractsListPage(),
          ),
          _buildNavigationButton(
            context,
            "عقد تسوية مالية",
            Icons.account_balance_wallet,
            Colors.orange[600]!,
            () => FinancialSettlementsPage(),
          ),
          _buildNavigationButton(
            context,
            "إفراغ / محضر استلام",
            Icons.check_circle_outline,
            Colors.purple[600]!,
            () => Fprintastlam(),
          ),
        ],
      ),
    );
  }

  Widget _buildAddContractSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.add_circle, color: Colors.indigo[700], size: 22),
              const SizedBox(width: 10),
              Text(
                "إضافة عقد جديد",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildNavigationButton(
            context,
            "إضافة عقد تحت الإنشاء",
            Icons.add,
            Colors.blue[800]!,
            () => ContractsPage0(),
          ),
          _buildNavigationButton(
            context,
            "إضافة عقد إعادة بيع",
            Icons.add,
            Colors.teal[800]!,
            () => ResaleContractFormPage(originalContractId: '111-1'),
          ),
          _buildNavigationButton(
            context,
            "إضافة عقد تسوية مالية",
            Icons.add,
            Colors.orange[800]!,
            () => FinancialSettlementContract(progect: '000-0'),
          ),
          _buildNavigationButton(
            context,
            "إضافة إفراغ / محضر استلام",
            Icons.add,
            Colors.purple[800]!,
            () => Aistlam(),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButton(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Widget Function() pageBuilder,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => pageBuilder()),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            constraints: const BoxConstraints(minHeight: 68, maxHeight: 88),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 14, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
