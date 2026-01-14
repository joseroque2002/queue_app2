# Email Troubleshooting Guide

## Why am I not receiving emails?

The queue system uses **EmailJS** to send email notifications. Here are common reasons why you might not receive emails and how to fix them:

### 1. **Check Your Spam/Junk Folder** 📧
   - Emails from EmailJS often go to spam folders
   - Check your spam/junk folder first
   - Mark the email as "Not Spam" if found

### 2. **EmailJS Configuration Issues** ⚙️
   The email service requires proper EmailJS setup:
   - **Service ID**: `service_q6pzdnm` (in `lib/services/email_service.dart`)
   - **Template ID**: `template_oo948ko` (for queue creation emails)
   - **Public Key**: `5VGpaO0kbh6Mby-Gw`
   
   **To fix:**
   - Go to [EmailJS Dashboard](https://dashboard.emailjs.com/)
   - Verify your Service ID, Template ID, and Public Key match the code
   - Make sure your EmailJS account is active and not suspended

### 3. **EmailJS Template Issues** 📝
   - Check that your EmailJS template has the correct variable names:
     - `to_email`
     - `to_name`
     - `queue_number`
     - `reference_number`
     - `department`
     - `purpose`
     - `message`
   - Make sure the template is published and active

### 4. **EmailJS Rate Limits** ⏱️
   - Free EmailJS accounts have rate limits (usually 200 emails/month)
   - If you've exceeded the limit, emails won't be sent
   - Check your EmailJS dashboard for usage statistics
   - Upgrade to a paid plan if needed

### 5. **Invalid Email Address** ❌
   - Make sure the email address entered is valid
   - Check for typos in the email address
   - The email must contain `@` and `.` characters

### 6. **Network Issues** 🌐
   - Check your internet connection
   - EmailJS API might be temporarily unavailable
   - Try again after a few minutes

### 7. **Check Console Logs** 🔍
   When you register for the queue, check the console/terminal for:
   - `✅ EmailJS (created) sent successfully` - Email was sent
   - `❌ EmailJS (created) error` - Email failed (check error details)
   - `⚠️ Queue creation email failed` - Email service issue

## How to Verify EmailJS Setup

1. **Check EmailJS Dashboard:**
   - Login to https://dashboard.emailjs.com/
   - Verify your service is active
   - Check template configuration
   - Review email logs/statistics

2. **Test Email Sending:**
   - Use EmailJS's test feature in the dashboard
   - Send a test email to verify configuration

3. **Check Code Configuration:**
   - Open `lib/services/email_service.dart`
   - Verify `serviceId`, `templateId`, and `publicKey` match your EmailJS account

## Common Error Messages

### "Invalid service ID"
- **Fix**: Update `serviceId` in `email_service.dart` with your EmailJS Service ID

### "Invalid template ID"
- **Fix**: Update `templateId` in `email_service.dart` with your EmailJS Template ID

### "Invalid user ID"
- **Fix**: Update `publicKey` in `email_service.dart` with your EmailJS Public Key

### "Rate limit exceeded"
- **Fix**: Wait a few minutes or upgrade your EmailJS plan

### "Network timeout"
- **Fix**: Check your internet connection and try again

## Alternative: Use a Different Email Service

If EmailJS continues to have issues, you can:
1. Switch to SendGrid, Mailgun, or AWS SES
2. Update the `EmailService` class to use the new service
3. Configure API keys and endpoints

## Need Help?

If emails still don't work after checking all the above:
1. Check the console logs for detailed error messages
2. Verify EmailJS account status
3. Test email sending directly from EmailJS dashboard
4. Contact the system administrator











