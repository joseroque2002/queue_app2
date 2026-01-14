# Email Configuration Updated ✅

## New EmailJS Configuration

Your EmailJS credentials have been updated in the code:

### Updated Configuration:
- **Service ID**: `service_3qmeeng`
- **Template ID**: `template_acltt3l`
- **Public Key**: `AdW8i4G7rNRLeYvR7`

### Location:
File: `lib/services/email_service.dart`
Lines: 11-14

## How Email Notification Works

1. **When user registers for queue:**
   - User fills out the information form
   - Clicks "Join Queue"
   - Queue entry is created in database
   - **Email is automatically sent** to the Gmail address entered in the form

2. **Email sending process:**
   - Happens automatically in `addQueueEntry()` function
   - Uses EmailJS service to send email
   - Email is sent to the address in the "Email Address" field

3. **What the user sees:**
   - Success message with queue number
   - Email notification status: "Confirmation email sent to [email]"
   - Reminder to check Gmail inbox (including spam folder)

## Important: Configure Gmail Sender

**You still need to update the Gmail sender email:**

1. Open `lib/services/email_service.dart`
2. Find line 22:
   ```dart
   static const String gmailSenderEmail = 'your-email@gmail.com';
   ```
3. Replace `'your-email@gmail.com'` with your actual Gmail address
4. Example:
   ```dart
   static const String gmailSenderEmail = 'ssu.queue@gmail.com';
   ```

## EmailJS Template Setup

Make sure your EmailJS template (`template_acltt3l`) has these variables:

- `{{to_email}}` - Recipient email (from form)
- `{{to_name}}` - Recipient name (from form)
- `{{from_name}}` - Sender name (SSU Queue System)
- `{{from_email}}` - Sender email (your Gmail)
- `{{queue_number}}` - Queue number (formatted as 001, 002, etc.)
- `{{reference_number}}` - Reference number
- `{{department}}` - Department code
- `{{purpose}}` - Purpose of visit
- `{{message}}` - Message content

## Testing

1. **Register for queue:**
   - Fill out the information form
   - Enter a valid Gmail address
   - Click "Join Queue"

2. **Check email:**
   - Check your Gmail inbox
   - Check spam/junk folder
   - Email should arrive within 1-2 minutes

3. **Check console logs:**
   - Look for: `✅ EmailJS (created) sent successfully`
   - If error: `❌ EmailJS (created) error` - check error details

## Troubleshooting

### Email not received?
1. ✅ Check spam/junk folder
2. ✅ Verify Gmail sender email is configured
3. ✅ Check EmailJS dashboard for email logs
4. ✅ Verify template has correct variables
5. ✅ Check console logs for errors

### Common errors:
- **Invalid service ID**: Verify Service ID in EmailJS dashboard
- **Invalid template ID**: Verify Template ID in EmailJS dashboard
- **Invalid user ID**: Verify Public Key in EmailJS dashboard
- **Rate limit**: Free tier is 200 emails/month

## Next Steps

1. ✅ Update Gmail sender email in code
2. ✅ Verify EmailJS template has correct variables
3. ✅ Test email sending by registering for queue
4. ✅ Check Gmail inbox for confirmation email

Your email notification system is now configured and ready to send emails when users register for the queue! 📧✅










