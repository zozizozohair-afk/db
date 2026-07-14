import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class LuxuryLogsPage extends StatefulWidget {
  const LuxuryLogsPage({super.key});

  @override
  State<LuxuryLogsPage> createState() => _LuxuryLogsPageState();
}

class _LuxuryLogsPageState extends State<LuxuryLogsPage> {
  Set<String> expandedCards = {};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double width = MediaQuery.of(context).size.width;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(74),
        child: GlassAppBar(
          title: '📜 سجل الأحداث',
          isDark: isDark,
        ),
      ),
      body: Stack(
        children: [
          // خلفية زجاجية متدرجة مع جزيئات خفيفة
          Positioned.fill(child: _AnimatedParticlesBackground(isDark: isDark)),
          SafeArea(
            top: false,
            child: Container(
              padding: EdgeInsets.only(top: 82),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('logs')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.amber[400]!),
                        strokeWidth: 3,
                      ),
                    );
                  }

                  final logs = snapshot.data!.docs;

                  return ListView.builder(
                    padding: EdgeInsets.only(top: 4, bottom: 44),
                    physics: BouncingScrollPhysics(),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final data = log.data() as Map<String, dynamic>;
                      final timestamp = (data['timestamp'] as Timestamp).toDate();
                      final formattedDate = DateFormat('hh:mm a | yyyy/MM/dd').format(timestamp);
                      final isStatusChange = data['action'] == 'تغيير الحالة';

                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: width < 600 ? 8 : 52, vertical: 4),
                        child: Column(
                          children: [
                            if (index == 0 ||
                                _isNewDay(
                                    (logs[index - 1].data() as Map<String, dynamic>)['timestamp'],
                                    data['timestamp']))
                              _buildGoldenDateSeparator(timestamp, isDark),
_buildNotificationCard(
                              log.id,
                              data,
                              formattedDate,
                              isStatusChange,
                              isDark,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

Widget _buildNotificationCard(
    String logId,
    Map<String, dynamic> data,
    String formattedDate,
    bool isStatusChange,
    bool isDark,
  ) {
    final isExpanded = expandedCards.contains(logId);
    final actionIcon = _getActionIcon(data['action']);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isExpanded) {
            expandedCards.remove(logId);
          } else {
            expandedCards.add(logId);
          }
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isExpanded ? 20 : 12),
          border: Border.all(
            color: isExpanded 
                ? (isDark ? Colors.amber.withOpacity(0.3) : Colors.blue.withOpacity(0.3))
                : Colors.blueGrey.withOpacity(0.08), 
            width: isExpanded ? 1.5 : 1.0
          ),
          gradient: LinearGradient(
            colors: isExpanded
                ? [
                    Colors.white.withOpacity(0.95),
                    Colors.blue[50]!.withOpacity(0.3),
                    Colors.white.withOpacity(0.4),
                  ]
                : [
                    Colors.white.withOpacity(0.85),
                    Colors.grey[50]!.withOpacity(0.2),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: isExpanded 
                  ? Colors.blueGrey.withOpacity(0.15)
                  : Colors.blueGrey.withOpacity(0.05),
              blurRadius: isExpanded ? 20 : 8,
              offset: Offset(0, isExpanded ? 6 : 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isExpanded ? 20 : 12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Padding(
              padding: EdgeInsets.all(isExpanded ? 16 : 12),
              child: Column(
                children: [
                  // الصف العلوي - دائماً مرئي
                  Row(
                    children: [
                      // أيقونة الإجراء
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getActionColor(data['action']).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          actionIcon,
                          color: _getActionColor(data['action']),
                          size: 18,
                        ),
                      ),
                      SizedBox(width: 12),
                      // النص الرئيسي
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getNotificationTitle(data),
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.grey[800],
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Tajawal',
                              ),
                              maxLines: isExpanded ? null : 1,
                              overflow: isExpanded ? null : TextOverflow.ellipsis,
                            ),
                            if (!isExpanded)
                              Text(
                                formattedDate,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                          ],
                        ),
                      ),
                      // مؤشر التوسيع
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: Duration(milliseconds: 300),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.grey[400],
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  // المحتوى المتوسع
                  AnimatedCrossFade(
                    firstChild: SizedBox.shrink(),
                    secondChild: Column(
                      children: [
                        SizedBox(height: 12),
                        Divider(
                          color: Colors.grey.withOpacity(0.2),
                          thickness: 1,
                        ),
                        SizedBox(height: 12),
                        if (isStatusChange)
                          _buildExpandedStatusChange(data, isDark)
                        else
                          _buildExpandedContent(data, isDark),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (data['user'] != null)
                              Row(
                                children: [
                                  Icon(Icons.person, size: 14, color: Colors.grey[500]),
                                  SizedBox(width: 4),
                                  Text(
                                    data['user'],
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                      fontFamily: 'Tajawal',
                                    ),
                                  ),
                                ],
                              ),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                                SizedBox(width: 4),
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                    fontFamily: 'Tajawal',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    crossFadeState: isExpanded 
                        ? CrossFadeState.showSecond 
                        : CrossFadeState.showFirst,
                    duration: Duration(milliseconds: 300),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getNotificationTitle(Map<String, dynamic> data) {
    if (data['action'] == 'تغيير الحالة') {
      return 'تم تغيير حالة الشقة ${data['itemId'] ?? ''}';
    }
    return data['action'] ?? 'إجراء جديد';
  }

  IconData _getActionIcon(String? action) {
    switch (action) {
      case 'تغيير الحالة':
        return Icons.swap_horiz;
      case 'إضافة':
        return Icons.add_circle;
      case 'حذف':
        return Icons.delete;
      case 'تعديل':
        return Icons.edit;
      case 'عرض':
        return Icons.visibility;
      default:
        return Icons.notifications;
    }
  }

  Color _getActionColor(String? action) {
    switch (action) {
      case 'تغيير الحالة':
        return Colors.orange;
      case 'إضافة':
        return Colors.green;
      case 'حذف':
        return Colors.red;
      case 'تعديل':
        return Colors.blue;
      case 'عرض':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildExpandedStatusChange(Map<String, dynamic> data, bool isDark) {
    return Column(
      children: [
        Text(
          'تفاصيل تغيير الحالة',
          style: TextStyle(
            color: isDark ? Colors.amber[300] : Colors.blue[800],
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Tajawal',
          ),
        ),
        SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStatusPill(data['oldData']?['status'], false, isDark),
            SizedBox(width: 12),
            Icon(Icons.arrow_forward, color: isDark ? Colors.cyanAccent : Colors.blue[700], size: 18),
            SizedBox(width: 12),
            _buildStatusPill(data['newData']?['status'], true, isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildExpandedContent(Map<String, dynamic> data, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data['category'] != null)
          _buildDetailRow('📌 الفئة', data['category'], isDark),
        if (data['itemId'] != null)
          _buildDetailRow('🏠 رقم الشقة', data['itemId'], isDark),
        if (data['details'] != null)
          _buildDetailRow('📝 التفاصيل', data['details'], isDark),
      ],
    );
  }



  Widget _buildStatusPill(String? status, bool isNew, bool isDark) {
    final color = _getStatusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.4 : 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isNew
              ? (isDark ? Colors.amber[400]! : Colors.blue[700]!)
              : color,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.16),
            blurRadius: 8,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Text(
        status ?? '---',
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: 'Tajawal',
        ),
      ),
    );
  }



  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: isDark ? Colors.blue[800] : Colors.blue[150],
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.grey[800],
                fontSize: 14,
                fontFamily: 'Tajawal',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoldenDateSeparator(DateTime date, bool isDark) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
            Colors.amber[200]!.withOpacity(0.5),
            Colors.amber[100]!.withOpacity(0.6),
            Colors.amber[200]!.withOpacity(0.5),
          ]
              : [
            Colors.blue[100]!.withOpacity(0.5),
            Colors.blue[50]!.withOpacity(0.7),
            Colors.blue[100]!.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.amber : Colors.blue).withOpacity(0.5),
            blurRadius: 3,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(
        DateFormat.yMMMMEEEEd('ar').format(date),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isDark ? Colors.amber[600] : Colors.blue[700],
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: 'Tajawal',
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'مباع':
        return Colors.red[600]!;
      case 'محجوز':
        return Colors.amber[600]!;
      case 'معروضة للبيع':
        return Colors.purple[600]!;
      case 'تم الإفراغ':
        return Colors.blue[600]!;
      case 'متاح':
        return Colors.green[600]!;
      case 'تحت الإنشاء':
        return Colors.orange[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  bool _isNewDay(Timestamp prevTimestamp, Timestamp currentTimestamp) {
    final prevDate = prevTimestamp.toDate();
    final currentDate = currentTimestamp.toDate();
    return prevDate.year != currentDate.year ||
        prevDate.month != currentDate.month ||
        prevDate.day != currentDate.day;
  }
}

/// Glassmorphism AppBar
class GlassAppBar extends StatelessWidget {
  final String title;
  final bool isDark;
  const GlassAppBar({required this.title, required this.isDark, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 13, left: 12, right: 12, bottom: 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: isDark
              ? [Colors.blueGrey[800]!.withOpacity(0.86), Colors.black.withOpacity(0.64)]
              : [Colors.white.withOpacity(0.91), Colors.blue[50]!.withOpacity(0.37)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isDark ? Colors.blueGrey[700]!.withOpacity(0.18) : Colors.blue[100]!.withOpacity(0.20),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.amber.withOpacity(0.08)
                : Colors.blue.withOpacity(0.08),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
            child: Center(
              child: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: isDark
                      ? [Colors.amber[600]!, Colors.amber[200]!]
                      : [Colors.indigo[700]!, Colors.blue[400]!],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ).createShader(bounds),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glassmorphism Card
class GlassCard extends StatelessWidget {
  final Widget child;
  const GlassCard({required this.child, super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.08), width: 1.2),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.89),
            Colors.blue[50]!.withOpacity(0.19),
            Colors.white.withOpacity(0.34),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.07),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
          child: child,
        ),
      ),
    );
  }
}

/// خلفية جزيئات متحركة شفافة
class _AnimatedParticlesBackground extends StatefulWidget {
  final bool isDark;
  const _AnimatedParticlesBackground({required this.isDark});
  @override
  State<_AnimatedParticlesBackground> createState() => _AnimatedParticlesBackgroundState();
}

class _AnimatedParticlesBackgroundState extends State<_AnimatedParticlesBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: 30),
      vsync: this,
    )..repeat();
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ParticlesPainter(_controller.value, widget.isDark),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ParticlesPainter extends CustomPainter {
  final double animationValue;
  final bool isDark;
  _ParticlesPainter(this.animationValue, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 26; i++) {
      final double progress = (animationValue + i * 0.03) % 1.0;
      final double x = (i * 47) % size.width;
      final double y = size.height * progress;
      final double opacity = (1 + (1 + i) * progress * 0.7) / 6;
      paint.color = [
        Color(0xFF3b82f6),
        Color(0xFF8b5cf6),
        Color(0xFF06b6d4),
        Color(0xFFfbbf24),
        Color(0xFFf43f5e),
      ][i % 5].withOpacity(opacity * (isDark ? 0.19 : 0.09));
      canvas.drawCircle(
        Offset(x, y),
        2 + (progress * 2.5),
        paint,
      );
    }
    for (int i = 0; i < 4; i++) {
      final double progress = (animationValue * 0.8 + i * 0.2) % 1.0;
      final double x = (i * 123 + (progress * 100)) % size.width;
      final double y = (size.height * progress + (1 - progress) * 50) % size.height;
      final double opacity = (progress * 0.4).clamp(0.0, 1.0);
      paint.color = [
        Color(0xFF667eea),
        Color(0xFF764ba2),
        Color(0xFFf093fb),
      ][i % 3].withOpacity(opacity * (isDark ? 0.16 : 0.07));
      canvas.drawCircle(
        Offset(x, y),
        7 + (progress * 4),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}