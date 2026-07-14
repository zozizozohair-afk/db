import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// مساعدات رفع الصكوك مع تحسينات الأداء - Supabase Storage
class DeedUploadUtils {
  static const int maxFileSize = 25 * 1024 * 1024; // 25 MB
  static const int maxRetries = 3;
  static const Duration uploadTimeout = Duration(minutes: 10);
  static const Duration databaseTimeout = Duration(seconds: 30);

  // الحصول على عميل Supabase
  static SupabaseClient get supabase => Supabase.instance.client;

  /// فحص صلاحيات المستخدم
  static Future<bool> checkUserPermissions() async {
    final user = supabase.auth.currentUser;
    return user != null;
  }

  /// التحقق من صحة الملف
  static String? validateFile({
    required String fileName,
    required int fileSize,
    Uint8List? bytes,
    String? filePath,
  }) {
    // التحقق من امتداد الملف
    if (!fileName.toLowerCase().endsWith('.pdf')) {
      return 'يجب أن يكون الملف من نوع PDF';
    }

    // التحقق من حجم الملف
    if (fileSize > maxFileSize) {
      final sizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(1);
      return 'حجم الملف ($sizeMB MB) كبير جداً. يجب أن يكون أقل من 25 ميجابايت';
    }

    if (fileSize == 0) {
      return 'الملف فارغ';
    }

    // التحقق من وجود البيانات
    if (kIsWeb) {
      if (bytes == null || bytes.isEmpty) {
        return 'لا يمكن قراءة الملف - البيانات فارغة';
      }
    } else {
      if (filePath == null || filePath.isEmpty) {
        return 'لا يمكن الوصول للملف - المسار فارغ';
      }
    }

    return null; // الملف صحيح
  }

  /// إنشاء مسار التخزين في Supabase
  static String createStoragePath({
    required String apartmentNumber,
    required String fileName,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final cleanFileName = fileName.replaceAll(RegExp(r'[^\w\-_\.]'), '_');
    return 'deeds/apartment_${apartmentNumber}_${timestamp}_$cleanFileName';
  }

  /// إنشاء metadata للملف
  static Map<String, String> createFileMetadata({
    required String apartmentNumber,
    required String fileName,
    required int fileSize,
  }) {
    return {
      'apartmentNumber': apartmentNumber.toString(),
      'uploadedBy': supabase.auth.currentUser?.id ?? 'unknown',
      'originalName': fileName,
      'uploadDate': DateTime.now().toIso8601String(),
      'fileSize': fileSize.toString(),
      'version': '2.0',
      'contentType': 'application/pdf',
    };
  }

  /// رفع الملف إلى Supabase Storage مع تتبع التقدم
  static Future<String> uploadFileToStorage({
    required String storagePath,
    required Map<String, String> metadata,
    Uint8List? bytes,
    String? filePath,
    Function(double)? onProgress,
  }) async {
    try {
      // محاكاة تقدم الرفع
      if (onProgress != null) {
        onProgress(0.1); // بدء الرفع
        await Future.delayed(Duration(milliseconds: 100));
      }

      if (kIsWeb) {
        if (bytes == null) {
          throw Exception('بيانات الملف مفقودة للويب');
        }

        if (onProgress != null) {
          onProgress(0.3); // تحضير البيانات
          await Future.delayed(Duration(milliseconds: 200));
        }

        // رفع الملف للويب
        final response = await supabase.storage
            .from('deeds')
            .uploadBinary(
              storagePath,
              bytes,
              fileOptions: FileOptions(
                contentType: 'application/pdf',
                metadata: metadata,
              ),
            )
            .timeout(uploadTimeout);

        if (onProgress != null) {
          onProgress(0.8); // اكتمال الرفع
          await Future.delayed(Duration(milliseconds: 100));
        }

        if (response.isEmpty) {
          throw Exception('فشل في رفع الملف');
        }

        // الحصول على الرابط العام
        final publicUrl = supabase.storage
            .from('deeds')
            .getPublicUrl(storagePath);

        if (onProgress != null) {
          onProgress(1.0); // اكتمال العملية
        }

        return publicUrl;
      } else {
        if (filePath == null) {
          throw Exception('مسار الملف مفقود للموبايل');
        }

        final file = File(filePath);
        if (!await file.exists()) {
          throw Exception('الملف غير موجود في المسار المحدد');
        }

        if (onProgress != null) {
          onProgress(0.3); // تحضير الملف
          await Future.delayed(Duration(milliseconds: 200));
        }

        // رفع الملف للموبايل
        final response = await supabase.storage
            .from('deeds')
            .upload(
              storagePath,
              file,
              fileOptions: FileOptions(
                contentType: 'application/pdf',
                metadata: metadata,
              ),
            )
            .timeout(uploadTimeout);

        if (onProgress != null) {
          onProgress(0.8); // اكتمال الرفع
          await Future.delayed(Duration(milliseconds: 100));
        }

        if (response.isEmpty) {
          throw Exception('فشل في رفع الملف');
        }

        // الحصول على الرابط العام
        final publicUrl = supabase.storage
            .from('deeds')
            .getPublicUrl(storagePath);

        if (onProgress != null) {
          onProgress(1.0); // اكتمال العملية
        }

        return publicUrl;
      }
    } catch (e) {
      if (e.toString().contains('timeout')) {
        throw Exception(
          'انتهت مهلة رفع الملف. يرجى التحقق من الاتصال والمحاولة مرة أخرى',
        );
      }
      rethrow;
    }
  }

  /// حفظ معلومات الملف في قاعدة البيانات
  static Future<void> saveFileInfoToDatabase({
    required String docId,
    required String downloadUrl,
    required String fileName,
    required int fileSize,
    String? apartmentNumber,
    String? projectNumber,
  }) async {
    try {
      final pnNumber = 'PN${DateTime.now().millisecondsSinceEpoch}';
      final currentUser = supabase.auth.currentUser;
      
      // إنشاء apartment_id بصيغة "رقم الشقة-رقم المشروع"
      final apartmentId = '${apartmentNumber ?? ''}-${projectNumber ?? ''}';
      
      // حفظ البيانات في جدول deed_files في Supabase
      await supabase.from('deed_files').insert({
        'id': docId,
        'apartment_id': apartmentId,
        'project_number': projectNumber,
        'pn': pnNumber,
        'file_name': fileName,
        'file_path': downloadUrl,
        'file_url': downloadUrl,
        'file_size': fileSize,
        'upload_date': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'metadata': {
          'uploadedBy': currentUser?.id,
          'uploadVersion': '2.0',
          'storageProvider': 'supabase',
          'contentType': 'application/pdf',
        },
      }).timeout(
        databaseTimeout,
        onTimeout: () {
          throw Exception('انتهت مهلة حفظ البيانات في قاعدة البيانات');
        },
      );
    } catch (e) {
      throw Exception('فشل في حفظ البيانات: ${e.toString()}');
    }
  }

  /// رفع الملف مع إعادة المحاولة
  static Future<String> uploadWithRetry({
    required String docId,
    required String apartmentNumber,
    required String fileName,
    required int fileSize,
    String? projectNumber,
    Uint8List? bytes,
    String? filePath,
    Function(double)? onProgress,
    Function(String)? onStatusUpdate,
  }) async {
    Exception? lastException;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        onStatusUpdate?.call('المحاولة $attempt من $maxRetries');

        // التحقق من صحة الملف
        final validationError = validateFile(
          fileName: fileName,
          fileSize: fileSize,
          bytes: bytes,
          filePath: filePath,
        );
        if (validationError != null) {
          throw Exception(validationError);
        }

        // إنشاء مسار التخزين والmetadata
        final storagePath = createStoragePath(
          apartmentNumber: apartmentNumber,
          fileName: fileName,
        );
        final metadata = createFileMetadata(
          apartmentNumber: apartmentNumber,
          fileName: fileName,
          fileSize: fileSize,
        );

        // رفع الملف
        onStatusUpdate?.call('جاري رفع الملف إلى Supabase...');
        final downloadUrl = await uploadFileToStorage(
          storagePath: storagePath,
          metadata: metadata,
          bytes: bytes,
          filePath: filePath,
          onProgress: onProgress,
        );

        // حفظ البيانات في قاعدة البيانات
        onStatusUpdate?.call('جاري حفظ البيانات...');
        await saveFileInfoToDatabase(
          docId: docId,
          downloadUrl: downloadUrl,
          fileName: fileName,
          fileSize: fileSize,
          apartmentNumber: apartmentNumber,
          projectNumber: projectNumber,
        );

        onStatusUpdate?.call('تم الرفع بنجاح إلى Supabase');
        return downloadUrl;
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        print('المحاولة $attempt فشلت: $e');

        if (attempt == maxRetries) {
          break; // فشل نهائياً
        }

        // انتظار متزايد بين المحاولات
        final waitTime = Duration(seconds: attempt * 2);
        onStatusUpdate?.call(
          'فشلت المحاولة $attempt، إعادة المحاولة خلال ${waitTime.inSeconds} ثانية...',
        );
        await Future.delayed(waitTime);
      }
    }

    throw lastException ??
        Exception('فشل في رفع الملف بعد $maxRetries محاولات');
  }

  /// الحصول على رسالة خطأ مفصلة
  static String getDetailedErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('permission') ||
        errorString.contains('unauthorized')) {
      return 'خطأ في الصلاحيات - تأكد من تسجيل الدخول وصلاحيات Supabase Storage';
    } else if (errorString.contains('network') ||
        errorString.contains('connection')) {
      return 'خطأ في الشبكة - تأكد من الاتصال بالإنترنت';
    } else if (errorString.contains('storage') ||
        errorString.contains('quota')) {
      return 'خطأ في التخزين - قد تكون المساحة المتاحة ممتلئة في Supabase';
    } else if (errorString.contains('firestore')) {
      return 'خطأ في قاعدة البيانات - تأكد من إعدادات Firestore';
    } else if (errorString.contains('supabase')) {
      return 'خطأ في Supabase - تأكد من إعدادات الاتصال';
    } else if (errorString.contains('timeout') ||
        errorString.contains('انتهت مهلة')) {
      return 'انتهت مهلة العملية - يرجى التحقق من سرعة الإنترنت والمحاولة مرة أخرى';
    } else if (errorString.contains('حجم الملف')) {
      return error.toString();
    } else if (errorString.contains('cancelled') ||
        errorString.contains('canceled')) {
      return 'تم إلغاء عملية الرفع';
    } else if (errorString.contains('unauthenticated')) {
      return 'يرجى تسجيل الدخول أولاً';
    } else if (errorString.contains('file not found') ||
        errorString.contains('الملف غير موجود')) {
      return 'الملف المحدد غير موجود';
    } else if (errorString.contains('invalid file') ||
        errorString.contains('ملف غير صحيح')) {
      return 'الملف المحدد غير صحيح أو تالف';
    }

    return 'حدث خطأ غير متوقع: ${error.toString()}';
  }

  /// فحص حالة الاتصال
  static Future<bool> checkConnectivity() async {
    try {
      // فحص الاتصال مع Supabase
      await supabase
          .from('apartments')
          .select('id')
          .limit(1)
          .timeout(Duration(seconds: 5));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// الحصول على مرجع التخزين (للتوافق مع الاختبارات)
  static StorageReference getStorageReference({
    required String apartmentNumber,
    required String fileName,
  }) {
    final storagePath = createStoragePath(
      apartmentNumber: apartmentNumber,
      fileName: fileName,
    );
    return StorageReference(fullPath: storagePath);
  }

  /// إحصائيات الرفع
  static Map<String, dynamic> getUploadStats({
    required int fileSize,
    required DateTime startTime,
    required DateTime endTime,
  }) {
    final duration = endTime.difference(startTime);
    final speedBytesPerSecond = fileSize / duration.inSeconds;
    final speedMBPerSecond = speedBytesPerSecond / (1024 * 1024);

    return {
      'fileSize': fileSize,
      'fileSizeMB': (fileSize / (1024 * 1024)).toStringAsFixed(2),
      'duration': duration.inSeconds,
      'speedMBPerSecond': speedMBPerSecond.toStringAsFixed(2),
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'storageProvider': 'supabase',
    };
  }

  /// حذف ملف من Supabase Storage
  static Future<void> deleteFileFromStorage(String storagePath) async {
    try {
      await supabase.storage.from('deeds').remove([storagePath]);
    } catch (e) {
      print('خطأ في حذف الملف من Supabase: $e');
      // لا نرمي خطأ هنا لأن حذف الملف قد لا يكون ضرورياً
    }
  }

  /// الحصول على معلومات الملف من Supabase
  static Future<Map<String, dynamic>?> getFileInfo(String storagePath) async {
    try {
      final response = await supabase.storage.from('deeds').info(storagePath);
      return {
        'name': response.name,
        'size': response.size,
        'metadata': response.metadata,
        'createdAt': response.createdAt,
        'lastModified': response.lastModified,
        'etag': response.etag,
      };
    } catch (e) {
      print('خطأ في الحصول على معلومات الملف: $e');
      return null;
    }
  }
}

/// نموذج مرجع التخزين (للتوافق مع الاختبارات)
class StorageReference {
  final String fullPath;
  
  const StorageReference({required this.fullPath});
}

/// نموذج لحالة الرفع
class UploadState {
  final bool isUploading;
  final double progress;
  final String? statusMessage;
  final String? errorMessage;
  final String? storageProvider;

  const UploadState({
    this.isUploading = false,
    this.progress = 0.0,
    this.statusMessage,
    this.errorMessage,
    this.storageProvider = 'supabase',
  });

  UploadState copyWith({
    bool? isUploading,
    double? progress,
    String? statusMessage,
    String? errorMessage,
    String? storageProvider,
  }) {
    return UploadState(
      isUploading: isUploading ?? this.isUploading,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: errorMessage ?? this.errorMessage,
      storageProvider: storageProvider ?? this.storageProvider,
    );
  }

  bool get hasError => errorMessage != null;
  bool get isCompleted => !isUploading && progress >= 1.0 && !hasError;
}
