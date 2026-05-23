const appReviewPhone = '+2250700000000';
const appReviewOtpCode = '260493';

String normalizePhoneDigits(String value) =>
    value.replaceAll(RegExp(r'\D'), '');

bool isAppReviewPhone(String phone) {
  return normalizePhoneDigits(phone) == normalizePhoneDigits(appReviewPhone);
}

bool isAppReviewOtp(String phone, String code) {
  return isAppReviewPhone(phone) && code.trim() == appReviewOtpCode;
}
