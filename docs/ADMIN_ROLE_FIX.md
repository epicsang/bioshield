# Admin Role Fix - Firebase

## Problem

Your admin user lost admin privileges and became a regular user.

### Root Cause

**The `UserModel.toMap()` method was NOT saving the `role` field to Firestore.**

When users were created or updated:
```dart
// OLD CODE (BROKEN):
Map<String, dynamic> toMap() {
  return {
    'uid': uid,
    'username': username,
    'email': email,
    // ❌ NO 'role' FIELD!
    'membership': {...},
  };
}
```

Later, when checking admin status:
```dart
final role = data?['role'] ?? 'user';  // ❌ Defaults to 'user' if missing!
return role == 'admin';
```

**Result:** All users became regular 'user' role because `role` field was missing!

---

## Solution Applied

### ✅ Fixed UserModel

**1. Added `role` field to class:**
```dart
class UserModel {
  final String uid;
  final String username;
  final String email;
  final bool isPremium;  // ✅ Determines if user is premium
  final String role;     // ✅ Either 'admin' or 'user'

  UserModel({
    required this.uid,
    required this.username,
    required this.email,
    required this.isPremium,
    this.role = 'user',  // ✅ Default to 'user'
  });
}
```

**2. Updated `toMap()` to save role:**
```dart
Map<String, dynamic> toMap() {
  return {
    'uid': uid,
    'username': username,
    'email': email,
    'role': role,  // ✅ NOW SAVES ROLE!
    'membership': {...},
  };
}
```

**3. Updated `fromMap()` to read role:**
```dart
factory UserModel.fromMap(Map<String, dynamic> map) {
  return UserModel(
    uid: map['uid'] ?? '',
    username: map['username'] ?? 'Unknown',
    email: map['email'] ?? '',
    isPremium: map['membership']?['isPremium'] ?? false,
    role: (map['role'] == null || map['role'] == '') ? 'user' : map['role'],  // ✅ READS ROLE, defaults empty to 'user'
  );
}
```

---

## How to Restore Your Admin User

### Option 1: Firebase Console (Recommended)

1. **Open Firebase Console:**
   - Go to https://console.firebase.google.com/
   - Select your BioShield project
   - Navigate to **Firestore Database**

2. **Find your user document:**
   - Go to `users` collection
   - Find your user by UID or email
   - Example path: `users/{your-uid}`

3. **Add/Update the `role` field:**
   - Click on the user document
   - Click **"Add field"** (or edit existing)
   - Field name: `role`
   - Field type: `string`
   - Value: `admin`
   - Click **Save**

**Result:** Your user is now an admin! ✅

---

### Option 2: Using Firestore Rules (Temporary Override)

If you can't access Firebase Console, you can update Firestore rules to allow admin self-assignment:

**1. Update firestore.rules:**
```javascript
// Temporary rule for admin fix
match /users/{userId} {
  // Allow users to update their own role ONCE for admin fix
  allow write: if request.auth != null &&
               request.auth.uid == userId &&
               request.resource.data.role == 'admin';
}
```

**2. From your app code:**
```dart
// In your app, run once to fix your admin account:
final user = FirebaseAuth.instance.currentUser;
await FirebaseFirestore.instance
    .collection('users')
    .doc(user!.uid)
    .update({'role': 'admin'});
```

**3. Revert firestore.rules back to secure version after fix!**

---

### Option 3: Cloud Function (Best for Production)

Create a Cloud Function to assign admin role:

```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.makeAdmin = functions.https.onCall(async (data, context) => {
  // Only allow specific emails to become admin
  const allowedAdmins = [
    'your.email@example.com',
    'admin@bioshield.com'
  ];

  const email = context.auth.token.email;

  if (!allowedAdmins.includes(email)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Not authorized to become admin'
    );
  }

  // Set admin role in Firestore
  await admin.firestore()
    .collection('users')
    .doc(context.auth.uid)
    .update({ role: 'admin' });

  return { success: true, message: 'Admin role assigned' };
});
```

---

## Verification

After fixing the role, verify it works:

**1. Check in Firebase Console:**
```
users/{your-uid}
├─ uid: "..."
├─ email: "your@email.com"
├─ username: "..."
├─ role: "admin"  ✅ Should show "admin"
└─ membership: {...}
```

**2. Test in app:**
```dart
// Run this in your app to verify:
final adminService = AdminService();
final isAdmin = await adminService.isAdmin();
print('Is Admin: $isAdmin');  // Should print: true
```

**3. Check app behavior:**
- Open BioShield app
- Navigate to Admin Dashboard
- You should now have access ✅

---

## Preventing Future Issues

### ✅ Role Assignment Best Practices

**1. Define user roles as constants:**
```dart
// lib/constants/user_roles.dart
class UserRoles {
  static const String admin = 'admin';
  static const String user = 'user';
}
```

**2. Use enums for type safety:**
```dart
enum UserRole {
  admin,
  user;

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.user;
    }
  }

  String toFirestore() => name;
}
```

**3. Secure Firestore rules to prevent role tampering:**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      // Users can read their own data
      allow read: if request.auth != null && request.auth.uid == userId;

      // Users can update their own data BUT NOT their role
      allow update: if request.auth != null &&
                      request.auth.uid == userId &&
                      request.resource.data.role == resource.data.role;  // ✅ Role cannot change

      // Only create new users (signup) - role defaults to 'user'
      allow create: if request.auth != null &&
                      request.auth.uid == userId &&
                      request.resource.data.role == 'user';  // ✅ New users must be 'user'
    }
  }
}
```

**4. Admin role assignment only via Cloud Functions:**
```javascript
// Only trusted Cloud Functions can set admin role
exports.promoteToAdmin = functions.https.onCall(async (data, context) => {
  // Check if caller is already admin
  const callerDoc = await admin.firestore()
    .collection('users')
    .doc(context.auth.uid)
    .get();

  if (callerDoc.data().role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can promote users');
  }

  // Promote target user
  await admin.firestore()
    .collection('users')
    .doc(data.targetUid)
    .update({ role: 'admin' });

  return { success: true };
});
```

---

## Summary

**What happened:**
- ❌ `UserModel` didn't save `role` field → all users became regular 'user'

**What was fixed:**
- ✅ Added `role` field to `UserModel`
- ✅ Updated `toMap()` to save role
- ✅ Updated `fromMap()` to read role and default empty to 'user'
- ✅ Changed role system: 'admin' or 'user' (not 'free' anymore)
- ✅ Premium status determined by `isPremium` field

**What you need to do:**
1. Open Firebase Console
2. Find your user document in `users` collection
3. Add/update field: `role = "admin"`
4. For existing users without role field, run migration (see FIREBASE_ROLE_MIGRATION.md)
5. Done! ✅

**Going forward:**
- All new users will have `role = "user"` by default
- Existing admin users keep their role
- Use Firebase Console or Cloud Functions to assign admin role
- Premium status controlled by `isPremium` boolean
