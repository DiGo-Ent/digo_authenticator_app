import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'Digo Authenticator',
      'search_placeholder': 'Search accounts...',
      'otp_copied': 'OTP copied to clipboard',
      'add_account': 'Add Account',
      'scan_qr': 'Scan QR Code',
      'manual_entry': 'Enter Key Manually',
      'secret_key': 'Secret Key',
      'account_name': 'Account Name',
      'issuer': 'Issuer',
      'digits': 'Digits',
      'period': 'Period (seconds)',
      'algorithm': 'Algorithm',
      'save': 'Save',
      'cancel': 'Cancel',
      'settings': 'Settings',
      'theme': 'Theme',
      'light_mode': 'Light Mode',
      'dark_mode': 'Dark Mode',
      'system_mode': 'System Default',
      'language': 'Language',
      'biometrics': 'Biometric Authentication',
      'screen_protection': 'Block Screenshots / Recents',
      'auto_lock': 'Auto-Lock Inactivity',
      'never': 'Never',
      'sec_30': '30 Seconds',
      'min_1': '1 Minute',
      'min_5': '5 Minutes',
      'min_10': '10 Minutes',
      'export_backup': 'Export Encrypted Backup',
      'import_backup': 'Import Encrypted Backup',
      'backup_password': 'Backup Password',
      'backup_password_hint': 'Choose a strong password to encrypt file',
      'enter_backup_password': 'Enter Password to Decrypt',
      'import_success': 'Backup restored successfully!',
      'import_failed': 'Failed to restore backup: Invalid password or corrupted file',
      'about': 'About Authenticator',
      'about_text': 'A secure, offline-first MFA authenticator built using enterprise-grade encryption standard practices.',
      'privacy_policy': 'Privacy Policy',
      'privacy_text': 'Your keys never leave your device. We collect no analytics, no logs, and no personal data.',
      'enter_pin': 'Enter Security PIN',
      'setup_pin': 'Setup Security PIN',
      'confirm_pin': 'Confirm Security PIN',
      'pins_do_not_match': 'PINs do not match. Try again.',
      'incorrect_pin': 'Incorrect PIN. Remaining attempts: {attempts}',
      'biometric_prompt': 'Authenticate to unlock Digo Authenticator',
      'time_correction': 'Sync Time (Time Correction)',
      'time_sync_success': 'Time offset corrected by {offset}ms',
      'favorites': 'Favorites',
      'groups': 'Groups',
      'no_accounts': 'No accounts added yet. Tap the button below to add your first MFA token.',
      'invalid_qr': 'Invalid QR Code. Please ensure it is an otpauth:// URI.',
      'counter': 'Counter (HOTP)',
      'notes': 'Notes (Encrypted)',
      'group_name': 'Group (Optional)',
      'edit_account': 'Edit Account',
      'delete_account': 'Delete Account',
      'delete_confirm': 'Are you sure you want to delete this account? This action CANNOT be undone.',
      'show_qr': 'Show Transfer QR',
      'copied_uri': 'Account URI copied to clipboard',
    },
    'hi': {
      'app_title': 'डिगो प्रमाणक',
      'search_placeholder': 'खाते खोजें...',
      'otp_copied': 'ओटीपी क्लिपबोर्ड पर कॉपी हो गया',
      'add_account': 'खाता जोड़ें',
      'scan_qr': 'क्यूआर कोड स्कैन करें',
      'manual_entry': 'मैन्युअल रूप से कुंजी दर्ज करें',
      'secret_key': 'गुप्त कुंजी (Secret Key)',
      'account_name': 'खाते का नाम',
      'issuer': 'जारीकर्ता (Issuer)',
      'digits': 'अंक (Digits)',
      'period': 'समय सीमा (सेकंड)',
      'algorithm': 'एल्गोरिदम (Algorithm)',
      'save': 'सहेजें',
      'cancel': 'रद्द करें',
      'settings': 'सेटिंग्स',
      'theme': 'थीम',
      'light_mode': 'लाइट मोड',
      'dark_mode': 'डार्क मोड',
      'system_mode': 'सिस्टम डिफ़ॉल्ट',
      'language': 'भाषा',
      'biometrics': 'बायोमेट्रिक प्रमाणीकरण',
      'screen_protection': 'स्क्रीनशॉट ब्लॉक करें',
      'auto_lock': 'ऑटो-लॉक निष्क्रियता',
      'never': 'कभी नहीं',
      'sec_30': '३० सेकंड',
      'min_1': '१ मिनट',
      'min_5': '५ मिनट',
      'min_10': '१० मिनट',
      'export_backup': 'एन्क्रिप्टेड बैकअप निर्यात करें',
      'import_backup': 'एन्क्रिप्टेड बैकअप आयात करें',
      'backup_password': 'बैकअप पासवर्ड',
      'backup_password_hint': 'फ़ाइल को एन्क्रिप्ट करने के लिए एक मजबूत पासवर्ड चुनें',
      'enter_backup_password': 'डिक्रिप्ट करने के लिए पासवर्ड दर्ज करें',
      'import_success': 'बैकअप सफलतापूर्वक पुनर्स्थापित किया गया!',
      'import_failed': 'बैकअप पुनर्स्थापित करने में विफल: अमान्य पासवर्ड या दूषित फ़ाइल',
      'about': 'प्रमाणक के बारे में',
      'about_text': 'उद्यम-ग्रेड एन्क्रिप्शन मानकों का उपयोग करके बनाया गया एक सुरक्षित, ऑफ़लाइन-प्रथम MFA प्रमाणक।',
      'privacy_policy': 'गोपनीयता नीति',
      'privacy_text': 'आपकी कुंजियाँ कभी भी आपकी डिवाइस से बाहर नहीं जाती हैं। हम कोई विश्लेषण, कोई लॉग और कोई व्यक्तिगत डेटा एकत्र नहीं करते हैं।',
      'enter_pin': 'सुरक्षा पिन दर्ज करें',
      'setup_pin': 'सुरक्षा पिन सेट करें',
      'confirm_pin': 'सुरक्षा पिन की पुष्टि करें',
      'pins_do_not_match': 'पिन मेल नहीं खाते। पुन: प्रयास करें।',
      'incorrect_pin': 'गलत पिन। शेष प्रयास: {attempts}',
      'biometric_prompt': 'डिगो प्रमाणक को अनलॉक करने के लिए प्रमाणित करें',
      'time_correction': 'समय सुधार (सिंक)',
      'time_sync_success': 'समय ऑफसेट {offset}ms द्वारा ठीक किया गया',
      'favorites': 'पसंदीदा',
      'groups': 'समूह',
      'no_accounts': 'अभी तक कोई खाता नहीं जोड़ा गया है। अपना पहला MFA टोकन जोड़ने के लिए नीचे दिए गए बटन पर टैप करें।',
      'invalid_qr': 'अमान्य क्यूआर कोड। कृपया सुनिश्चित करें कि यह एक otpauth:// यूआरआई है।',
      'counter': 'काउंटर (HOTP)',
      'notes': 'नोट्स (एन्क्रिप्टेड)',
      'group_name': 'समूह (वैकल्पिक)',
      'edit_account': 'खाता संपादित करें',
      'delete_account': 'खाता हटाएं',
      'delete_confirm': 'क्या आप वाकई इस खाते को हटाना चाहते हैं? यह क्रिया वापस नहीं ली जा सकती।',
      'show_qr': 'ट्रांसफर क्यूआर दिखाएं',
      'copied_uri': 'खाता यूआरआई क्लिपबोर्ड पर कॉपी हो गया',
    }
  };

  String translate(String key, {Map<String, String>? arguments}) {
    String value = _localizedValues[locale.languageCode]?[key] ?? _localizedValues['en']?[key] ?? key;
    if (arguments != null) {
      arguments.forEach((k, v) {
        value = value.replaceAll('{$k}', v);
      });
    }
    return value;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'hi'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
