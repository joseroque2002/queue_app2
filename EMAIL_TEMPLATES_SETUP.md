# Email Templates Setup - Final Configuration ✅

## EmailJS Configuration

### Updated Settings:
- **Service ID**: `service_3qmeeng`
- **Public Key**: `AdW8i4G7rNRLeYvR7`
- **Queue Creation Template ID**: `template_acltt3l`
- **Top 5 Alert Template ID**: `template_1j1htdr`

## Template 1: Queue Creation Email (template_acltt3l)

**Template Content:**
```
Hi {{to_name}},

You have been added to the queue.

Queue #: {{queue_number}}
Reference: {{reference_number}}
Department: {{department}}
Purpose: {{purpose}}

{{message}}

Thank you,
{{from_name}}
```

**Template Variables Used:**
- `{{to_name}}` - Recipient name
- `{{queue_number}}` - Queue number (formatted as 001, 002, etc.)
- `{{reference_number}}` - Reference number
- `{{department}}` - Department code
- `{{purpose}}` - Purpose of visit
- `{{message}}` - Message: "You have been added to the queue. Please wait for your turn."
- `{{from_name}}` - Sender name (SSU Queue System)

## Template 2: Top 5 Alert Email (template_1j1htdr)

**Template Content:**
```
Hello {{to_name}},

Good news! 🎉 Your queue is now in the Top 5. Kindly prepare and stay nearby, as your turn is approaching.

Queue #: {{queue_number}}
Reference #: {{reference_number}}
Department: {{department}}
Purpose: {{purpose}}

{{message}}

Thank you,
{{from_name}}
```

**Template Variables Used:**
- `{{to_name}}` - Recipient name
- `{{queue_number}}` - Queue number (formatted as 001, 002, etc.)
- `{{reference_number}}` - Reference number
- `{{department}}` - Department code
- `{{purpose}}` - Purpose of visit
- `{{message}}` - Message: "Good news! 🎉 Your queue is now in the Top 5. Kindly prepare and stay nearby, as your turn is approaching."
- `{{from_name}}` - Sender name (SSU Queue System)

## Important: Configure Gmail Sender

**You MUST update the Gmail sender email:**

1. Open `lib/services/email_service.dart`
2. Find line 22:
   ```dart
   static const String gmailSenderEmail = 'your-email@gmail.com';
   ```
3. Replace with your actual Gmail address:
   ```dart
   static const String gmailSenderEmail = 'your-actual-gmail@gmail.com';
   ```

## How It Works

1. **When user registers:**
   - User fills out information form
   - Clicks "Join Queue"
   - Email is automatically sent using `template_acltt3l`
   - Email goes to the Gmail address entered in the form

2. **When user is in Top 5:**
   - If queue number is 1-5, additional email is sent
   - Uses `template_1j1htdr` template
   - Notifies user they're in Top 5

## Testing

1. **Register for queue:**
   - Fill out form with valid Gmail address
   - Click "Join Queue"
   - Check Gmail inbox (and spam folder)

2. **Check console logs:**
   - Look for: `✅ EmailJS (created) sent successfully`
   - If error: Check error details in console

3. **Verify EmailJS Dashboard:**
   - Login to https://dashboard.emailjs.com/
   - Check "Email Logs" to see if emails were sent
   - Verify template IDs match

## Troubleshooting

### Email not received?
1. ✅ Check spam/junk folder
2. ✅ Verify Gmail sender email is configured (NOT 'your-email@gmail.com')
3. ✅ Check EmailJS dashboard logs
4. ✅ Verify template variables match exactly
5. ✅ Check console logs for errors

### Common Errors:
- **Invalid template ID**: Verify template IDs in EmailJS dashboard
- **Invalid service ID**: Verify service ID in EmailJS dashboard
- **Invalid user ID**: Verify public key in EmailJS dashboard
- **Template variables missing**: Make sure all variables are in template

## Next Steps

1. ✅ Update Gmail sender email in `email_service.dart` line 22
2. ✅ Verify templates in EmailJS dashboard match the format above
3. ✅ Test by registering for queue
4. ✅ Check Gmail inbox for confirmation email

Your email system is now configured and ready! 📧✅










