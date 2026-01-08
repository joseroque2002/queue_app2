import 'dart:io';
import 'lib/services/supabase_service.dart';
import 'lib/services/purpose_service.dart';
import 'lib/services/admin_service.dart';

void main() async {
  print('🔍 Starting purpose deletion script...');
  
  try {
    // Initialize Supabase
    final supabaseService = SupabaseService();
    await supabaseService.initialize();
    print('✅ Supabase initialized');
    
    // Initialize services
    final purposeService = PurposeService();
    final adminService = AdminService();
    
    // Initialize default admins and login as master admin
    adminService.initializeDefaultAdmins();
    final loginSuccess = adminService.login('admin', 'admin123');
    
    if (!loginSuccess) {
      print('❌ Failed to login as admin');
      return;
    }
    
    print('✅ Logged in as master admin');
    
    // Load purposes from database
    await purposeService.initializeDefaultPurposes();
    print('✅ Purposes loaded from database');
    
    // Find the purpose "RAOT BANDOL"
    final targetPurpose = purposeService.getPurposeByName('RAOT BANDOL');
    
    if (targetPurpose == null) {
      print('❌ Purpose "RAOT BANDOL" not found in the database');
      print('📋 Available purposes:');
      final allPurposes = purposeService.getAllPurposes();
      for (final purpose in allPurposes) {
        print('   - ${purpose.name} (ID: ${purpose.id}, Active: ${purpose.isActive})');
      }
      return;
    }
    
    print('🎯 Found purpose: ${targetPurpose.name} (ID: ${targetPurpose.id})');
    print('   Description: ${targetPurpose.description}');
    print('   Active: ${targetPurpose.isActive}');
    
    // Ask for confirmation
    print('\n⚠️  Are you sure you want to delete this purpose? (y/N)');
    final input = stdin.readLineSync()?.toLowerCase();
    
    if (input != 'y' && input != 'yes') {
      print('❌ Operation cancelled by user');
      return;
    }
    
    // Delete the purpose (soft delete - sets isActive to false)
    print('🗑️  Deleting purpose...');
    final success = await purposeService.deletePurpose(targetPurpose.id);
    
    if (success) {
      print('✅ Purpose "RAOT BANDOL" has been successfully deleted (deactivated)');
      print('   The purpose is now inactive and will not appear in selection lists');
      print('   Existing queue entries with this purpose will remain unchanged');
    } else {
      print('❌ Failed to delete the purpose');
    }
    
    // Show updated list
    print('\n📋 Updated active purposes:');
    final activePurposes = purposeService.getActivePurposes();
    for (final purpose in activePurposes) {
      print('   - ${purpose.name}');
    }
    
  } catch (e, stackTrace) {
    print('❌ Error occurred: $e');
    print('Stack trace: $stackTrace');
  }
  
  print('\n🏁 Script completed');
}