// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'غابتنا';

  @override
  String get appSubtitle => 'تطبيق عون الغابات';

  @override
  String get loginTitle => 'تسجيل الدخول';

  @override
  String get loginSubtitle => 'ادخل إلى فضائك كعون';

  @override
  String get loginEmail => 'البريد الإلكتروني';

  @override
  String get loginEmailHint => 'example@email.com';

  @override
  String get loginPassword => 'كلمة المرور';

  @override
  String get loginButton => 'تسجيل الدخول';

  @override
  String get loginEmailRequired => 'البريد الإلكتروني مطلوب';

  @override
  String get loginEmailInvalid => 'بريد إلكتروني غير صالح';

  @override
  String get loginPasswordRequired => 'كلمة المرور مطلوبة';

  @override
  String get loginPasswordMin => '6 أحرف على الأقل';

  @override
  String get loginFooter => 'المديرية العامة للغابات';

  @override
  String get homeGreeting => 'مرحباً 👋';

  @override
  String get homeQuestion => 'ماذا تريد أن تفعل؟';

  @override
  String get homeCreateAlert => 'الإبلاغ عن تنبيه';

  @override
  String get homeCreateAlertSub => 'الإبلاغ عن حريق أو سرقة أو حادثة أخرى';

  @override
  String get homeMyAlerts => 'تنبيهاتي';

  @override
  String get homeMyAlertsSub => 'الاطلاع على سجل بلاغاتك';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navAlert => 'تنبيه';

  @override
  String get navHistory => 'السجل';

  @override
  String get navLogout => 'تسجيل الخروج';

  @override
  String get logoutTitle => 'تسجيل الخروج';

  @override
  String get logoutMessage => 'هل تريد فعلاً تسجيل الخروج؟';

  @override
  String get logoutCancel => 'إلغاء';

  @override
  String get logoutConfirm => 'خروج';

  @override
  String get createAlertTitle => 'الإبلاغ عن تنبيه';

  @override
  String get createAlertType => 'نوع التنبيه *';

  @override
  String get createAlertTypeHint => 'اختر نوعاً...';

  @override
  String get createAlertForest => 'الغابة المعنية *';

  @override
  String get createAlertForestHint => 'اختر غابة...';

  @override
  String get createAlertPhoto => 'الصورة';

  @override
  String get createAlertAddPhoto => 'إضافة صورة';

  @override
  String get createAlertCameraOrGallery => 'الكاميرا أو المعرض';

  @override
  String get createAlertDescription => 'الوصف';

  @override
  String get createAlertDescHint => 'صف الحادثة الملاحظة...';

  @override
  String get createAlertSubmit => 'إرسال التنبيه';

  @override
  String get createAlertSubmitting => 'جارٍ الإرسال...';

  @override
  String get createAlertSuccess => 'تم الإبلاغ عن التنبيه بنجاح ✅';

  @override
  String get createAlertTypeRequired => 'يرجى اختيار نوع التنبيه';

  @override
  String get createAlertForestRequired => 'يرجى اختيار غابة';

  @override
  String get createAlertCamera => 'التقاط صورة';

  @override
  String get createAlertGallery => 'اختيار من المعرض';

  @override
  String get createAlertChangePhoto => 'تغيير الصورة';

  @override
  String get createAlertNoForest => 'لا توجد غابات متاحة';

  @override
  String get createAlertLoading => 'جارٍ التحميل...';

  @override
  String get myAlertsTitle => 'تنبيهاتي';

  @override
  String get myAlertsEmpty => 'لا يوجد أي تنبيه مُبلَّغ عنه';

  @override
  String get myAlertsEmptySub => 'ستظهر تنبيهاتك هنا';

  @override
  String get myAlertsRetry => 'إعادة المحاولة';

  @override
  String get alertTypeIncendie => 'حريق';

  @override
  String get alertTypeVol => 'سرقة';

  @override
  String get alertTypeInondation => 'فيضان';

  @override
  String get alertTypeGlissement => 'انزلاق تربة';

  @override
  String get alertTypeMaladie => 'مرض غابوي';

  @override
  String get alertTypeAutre => 'أخرى';

  @override
  String get alertStatusEnCours => 'قيد المعالجة';

  @override
  String get alertStatusTraiter => 'تمت المعالجة';

  @override
  String get alertStatusRejeter => 'مرفوض';

  @override
  String get statusUpdated => 'تم تحديث الحالة';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get cancel => 'إلغاء';

  @override
  String get loading => 'جارٍ التحميل...';
}
