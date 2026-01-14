# Gmail Setup Guide for EmailJS

This guide will help you configure Gmail to send emails through EmailJS.

## Step 1: Configure Gmail in EmailJS Dashboard

1. **Login to EmailJS Dashboard**
   - Go to https://dashboard.emailjs.com/
   - Login with your account

2. **Add Gmail Service**
   - Click on "Add New Service"
   - Select "Gmail" as the email service
   - Click "Connect Account"
   - You'll be redirected to Google to authorize EmailJS
   - Grant permissions to EmailJS to send emails on your behalf
   - Your Gmail service will be created with ID: `service_q6pzdnm`

## Step 2: Create Email Templates

### Template 1: Queue Creation Email (template_oo948ko)

1. **Go to Email Templates**
   - Click "Email Templates" in the sidebar
   - Click "Create New Template"

2. **Template Settings:**
   - **Template Name**: Queue Creation Email
   - **Template ID**: `template_oo948ko` (or use the generated ID)
   - **Service**: Select your Gmail service (`service_q6pzdnm`)

3. **Email Content:**
   ```
   Subject: Queue Registration Confirmation - Queue #{{queue_number}}

   Hello {{to_name}},

   You have been successfully added to the queue!

   Queue Details:
   - Queue Number: #{{queue_number}}
   - Reference Number: {{reference_number}}
   - Department: {{department}}
   - Purpose: {{purpose}}

   {{message}}

   Please wait for your turn. You will be notified when it's your turn.

   Thank you,
   {{from_name}}
   ```

4. **Template Variables:**
   Make sure these variables are available in your template:
   - `{{to_email}}` - Recipient email
   - `{{to_name}}` - Recipient name
   - `{{from_name}}` - Sender name (SSU Queue System)
   - `{{from_email}}` - Sender email (your Gmail)
   - `{{queue_number}}` - Queue number (formatted as 001, 002, etc.)
   - `{{reference_number}}` - Reference number
   - `{{department}}` - Department code
   - `{{purpose}}` - Purpose of visit
   - `{{message}}` - Custom message

5. **Save and Publish** the template

### Template 2: Top 5 Alert Email (template_ark0svi)

1. **Create another template** for top 5 notifications

2. **Template Settings:**
   - **Template Name**: Top 5 Queue Alert
   - **Template ID**: `template_ark0svi` (or use the generated ID)
   - **Service**: Select your Gmail service

3. **Email Content:**
   ```
   Subject: {{subject}}

   Hello {{to_name}},

   🔔 Top 5 Alert!

   You are now among the top 5 in the queue!

   Queue Details:
   - Queue Number: #{{queue_number}}
   - Reference Number: {{reference_number}}
   - Department: {{department}}
   - Purpose: {{purpose}}
   - Course: {{course}}
   - {{estimated_wait}}
   - Current Time: {{current_time}}

   {{message}}

   Please be ready and stay nearby. You will be called soon!

   Thank you,
   {{from_name}}
   ```

4. **Save and Publish** the template

## Step 3: Update Code Configuration

1. **Open** `lib/services/email_service.dart`

2. **Update Gmail Sender Email:**
   ```dart
   // Replace with your actual Gmail address
   static const String gmailSenderEmail = 'your-email@gmail.com';
   static const String gmailSenderName = 'SSU Queue System';
   ```

3. **Verify EmailJS Credentials:**
   ```dart
   static const String serviceId = 'service_q6pzdnm';
   static const String templateId = 'template_oo948ko';
   static const String templateTopFiveId = 'template_ark0svi';
   static const String publicKey = '5VGpaO0kbh6Mby-Gw';
   ```

## Step 4: Gmail Security Settings

To allow EmailJS to send emails from your Gmail account:

1. **Enable 2-Step Verification** (if not already enabled)
   - Go to https://myaccount.google.com/security
   - Enable 2-Step Verification

2. **Generate App Password** (if needed)
   - Go to https://myaccount.google.com/apppasswords
   - Generate an app password for "Mail"
   - Use this password in EmailJS if prompted

3. **Allow Less Secure Apps** (if required)
   - Go to https://myaccount.google.com/lesssecureapps
   - Enable "Allow less secure apps" (Note: This is less secure, use app passwords instead)

## Step 5: Test Email Sending

1. **Test from EmailJS Dashboard:**
   - Go to your template in EmailJS
   - Click "Test" button
   - Fill in test values
   - Send test email
   - Check your inbox (and spam folder)

2. **Test from App:**
   - Register for a queue in the app
   - Check console logs for email sending status
   - Check your email inbox

## Step 6: Verify EmailJS Public Key

1. **Get Your Public Key:**
   - Go to EmailJS Dashboard
   - Click on "Account" → "General"
   - Copy your "Public Key"
   - Update in code: `static const String publicKey = 'YOUR_PUBLIC_KEY';`

## Troubleshooting

### Emails not sending?

1. **Check EmailJS Dashboard:**
   - Go to "Email Logs" to see if emails were sent
   - Check for any error messages

2. **Check Gmail Service:**
   - Verify Gmail service is connected in EmailJS
   - Re-authorize if needed

3. **Check Template Variables:**
   - Make sure all template variables match the code
   - Variables are case-sensitive

4. **Check Spam Folder:**
   - Emails might go to spam initially
   - Mark as "Not Spam" to improve deliverability

5. **Check Console Logs:**
   - Look for error messages in the app console
   - Check EmailJS response status codes

### Common Errors

- **"Invalid service ID"**: Verify `serviceId` matches your EmailJS service
- **"Invalid template ID"**: Verify `templateId` matches your EmailJS template
- **"Invalid user ID"**: Verify `publicKey` matches your EmailJS public key
- **"Rate limit exceeded"**: You've exceeded EmailJS free tier limits (200 emails/month)

## EmailJS Configuration Summary

```
Service ID: service_q6pzdnm
Template ID (Queue Creation): template_oo948ko
Template ID (Top 5 Alert): template_ark0svi
Public Key: 5VGpaO0kbh6Mby-Gw
Gmail Sender: your-email@gmail.com (UPDATE THIS!)
```

## Next Steps

1. ✅ Configure Gmail service in EmailJS
2. ✅ Create email templates
3. ✅ Update Gmail sender email in code
4. ✅ Test email sending
5. ✅ Verify emails are received

Your emails will now be sent from your Gmail account through EmailJS! 📧











