# Email Debug Checklist - Bakit Hindi Nag-notify sa Gmail?

## ✅ Quick Checks (Una gawin ito)

### 1. Check Console Logs
Kapag nag-register ka, tingnan ang console/terminal output. Hanapin ang:
- `✅ EmailJS (created) sent successfully` = Email na-send
- `❌ EmailJS (created) error` = May problema sa pag-send
- `⚠️ WARNING: Gmail sender email not configured` = Kailangan i-configure ang Gmail

### 2. Check Gmail Sender Configuration
Buksan ang `lib/services/email_service.dart` at tingnan ang line 22:
```dart
static const String gmailSenderEmail = 'your-email@gmail.com';
```
**Kailangan palitan ito ng actual Gmail address mo!**

### 3. Check Spam/Junk Folder
- Buksan ang Gmail inbox
- Tingnan ang Spam/Junk folder
- Minsan doon napupunta ang emails mula sa EmailJS

## 🔍 Detailed Troubleshooting

### Problem 1: Gmail Sender Not Configured
**Symptom:** Console shows `⚠️ WARNING: Gmail sender email not configured`

**Fix:**
1. Buksan ang `lib/services/email_service.dart`
2. Hanapin ang line 22
3. Palitan ang `'your-email@gmail.com'` ng actual Gmail mo
4. Example: `static const String gmailSenderEmail = 'ssu.queue@gmail.com';`
5. Save at restart ang app

### Problem 2: EmailJS Configuration Error
**Symptom:** Console shows `❌ EmailJS (created) error: 400` o `Invalid service ID`

**Fix:**
1. I-verify ang EmailJS credentials sa `email_service.dart`:
   - Service ID: `service_q6pzdnm`
   - Template ID: `template_oo948ko`
   - Public Key: `5VGpaO0kbh6Mby-Gw`

2. I-check sa EmailJS Dashboard:
   - Login sa https://dashboard.emailjs.com/
   - I-verify na ang Service ID, Template ID, at Public Key ay match

### Problem 3: Gmail Service Not Connected
**Symptom:** Console shows `Forbidden` o `403` error

**Fix:**
1. Buksan ang EmailJS Dashboard
2. Pumunta sa "Services"
3. I-check kung connected ang Gmail service
4. Kung hindi, i-click ang "Connect Account" at i-authorize ang Gmail

### Problem 4: Email Template Not Found
**Symptom:** Console shows `Invalid template ID`

**Fix:**
1. Buksan ang EmailJS Dashboard
2. Pumunta sa "Email Templates"
3. I-verify na mayroong template na may ID: `template_oo948ko`
4. Kung wala, gumawa ng bagong template o i-update ang Template ID sa code

### Problem 5: Rate Limit Exceeded
**Symptom:** Console shows `rate limit` o `quota exceeded`

**Fix:**
1. EmailJS free tier: 200 emails/month lang
2. I-check ang usage sa EmailJS Dashboard
3. Maghintay ng ilang minuto o mag-upgrade ng plan

### Problem 6: Invalid Email Address
**Symptom:** Console shows `Invalid email address`

**Fix:**
1. I-verify na tama ang email address na nilagay sa form
2. Dapat may `@` at `.` (example: `user@gmail.com`)
3. Walang spaces o special characters na hindi allowed

## 📋 Step-by-Step Verification

### Step 1: Verify Gmail Sender Email
```dart
// Sa lib/services/email_service.dart line 22
static const String gmailSenderEmail = 'YOUR_ACTUAL_GMAIL@gmail.com';
```
✅ Dapat hindi `'your-email@gmail.com'` ang value

### Step 2: Verify EmailJS Service
1. Login sa https://dashboard.emailjs.com/
2. Pumunta sa "Services"
3. I-verify na may Gmail service na connected
4. I-check ang Service ID (dapat `service_q6pzdnm`)

### Step 3: Verify Email Template
1. Pumunta sa "Email Templates"
2. I-verify na may template na may ID `template_oo948ko`
3. I-check na ang template ay naka-link sa Gmail service
4. I-verify na published ang template

### Step 4: Test Email Sending
1. Mag-register sa queue
2. Tingnan ang console logs
3. Hanapin ang email sending status
4. I-check ang Gmail inbox (at spam folder)

### Step 5: Check EmailJS Logs
1. Pumunta sa EmailJS Dashboard
2. Pumunta sa "Email Logs" o "Activity"
3. Tingnan kung may email sending attempts
4. I-check kung may errors

## 🎯 Common Solutions

### Solution 1: Update Gmail Sender Email
```dart
// lib/services/email_service.dart
static const String gmailSenderEmail = 'ssu.queue.system@gmail.com'; // Your actual Gmail
```

### Solution 2: Re-authorize Gmail in EmailJS
1. EmailJS Dashboard → Services
2. I-click ang Gmail service
3. I-click ang "Reconnect" o "Re-authorize"
4. I-authorize ulit ang Gmail

### Solution 3: Create/Update Email Template
1. EmailJS Dashboard → Email Templates
2. Gumawa ng bagong template o i-edit ang existing
3. I-set ang Service sa Gmail service
4. I-save at i-publish

### Solution 4: Check EmailJS Public Key
1. EmailJS Dashboard → Account → General
2. I-copy ang Public Key
3. I-update sa code: `static const String publicKey = 'YOUR_KEY';`

## 📞 Still Not Working?

Kung lahat ng nasa taas ay na-check na pero hindi pa rin nagwo-work:

1. **I-check ang console logs** - May detailed error messages doon
2. **I-check ang EmailJS Dashboard** - Tingnan ang Email Logs
3. **I-test ang EmailJS template** - Gamitin ang "Test" button sa EmailJS
4. **I-verify ang internet connection** - Kailangan ng internet para sa EmailJS API
5. **I-check ang Gmail inbox settings** - Baka may filters na nagba-block

## 💡 Tips

- **Always check spam folder first** - Minsan doon napupunta ang emails
- **Wait 1-2 minutes** - Minsan may delay ang email delivery
- **Check console logs** - May detailed information doon
- **Test from EmailJS Dashboard** - Para ma-verify na working ang setup
- **Use valid Gmail address** - Dapat actual Gmail account, hindi placeholder

---

**Most Common Issue:** Gmail sender email ay hindi pa na-configure (naka-placeholder pa ang `'your-email@gmail.com'`)

**Quick Fix:** I-update ang `gmailSenderEmail` sa `lib/services/email_service.dart` line 22











