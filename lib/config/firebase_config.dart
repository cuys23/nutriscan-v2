class FirebaseConfig {
  // Firebase project configuration
  static const String projectId = 'nutriscan-75d57';

  // Collection names
  static const String usersCollection = 'users';
  static const String foodsCollection = 'foods';
  static const String backupCollection = 'backups';

  // Document fields
  static const String userIdField = 'userId';
  static const String lastBackupField = 'lastBackup';
  static const String deviceIdField = 'deviceId';
  static const String createdAtField = 'createdAt';
  static const String updatedAtField = 'updatedAt';
  
  // Subscription fields
  static const String subscriptionField = 'subscription';
  static const String isSubscribedField = 'isSubscribed';
  static const String subscriptionTypeField = 'subscriptionType';
  static const String subscriptionExpiryField = 'subscriptionExpiry';
}
