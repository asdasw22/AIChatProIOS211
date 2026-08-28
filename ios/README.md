# Telegram Photo Drive iOS

تطبيق SwiftUI لـ iOS 17+ يرفع صور الجهاز مباشرةً إلى Telegram Bot API باستخدام Bot Token وChat ID.

## البناء

1. افتح `TelegramPhotoDrive.xcodeproj` على macOS باستخدام Xcode 15 أو أحدث.
2. القيمة الافتراضية للـ Bundle Identifier هي `com.youssef.telegramphotodrive`.
3. فعّل Signing & Capabilities:
   - Photos Library access عبر `Info.plist`.
   - Background Modes: Background fetch و Background processing.
4. شغّل على جهاز iPhone حقيقي لاختبار الخلفية والصور.

## ملاحظات

- لا يحتوي المشروع على Telegram Bot Token ثابت داخل الكود.
- توكن البوت الذي تدخله داخل التطبيق يُحفظ في Keychain على الجهاز.
- التطبيق يحفظ حالة كل صورة في SwiftData ويكمل من الصور غير المرفوعة بعد إعادة الفتح.
- iOS لا يضمن التشغيل المستمر في الخلفية، خصوصًا بعد إغلاق التطبيق بالقوة.