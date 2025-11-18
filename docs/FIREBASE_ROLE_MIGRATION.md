# Firebase Role Field Migration Guide

## Problem
Some existing user documents in Firestore don't have a `role` field. These users need to be updated with `role: 'user'` by default.

## Updated Role System

- **`role`**: Either `'admin'` or `'user'` (not `'free'` anymore)
- **`isPremium`**: Boolean that determines if the account is premium
- **Default**: Empty or missing `role` field defaults to `'user'`

## Migration Options

### Option 1: Firebase Console Bulk Update (Recommended for < 100 users)

1. Open Firebase Console: https://console.firebase.google.com/
2. Navigate to **Firestore Database**
3. Go to `users` collection
4. For each user document WITHOUT a `role` field:
   - Click on the document
   - Click **"Add field"**
   - Field name: `role`
   - Field type: `string`
   - Value: `user`
   - Click **Save**

5. For your admin user:
   - Set `role` to `admin`

---

### Option 2: Cloud Function Migration (Recommended for > 100 users)

Create a one-time migration Cloud Function:

**functions/index.js:**
```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

/**
 * One-time migration: Add 'role: user' to all users without a role field
 *
 * Call this function ONCE via HTTP:
 * https://your-project.cloudfunctions.net/migrateUserRoles
 */
exports.migrateUserRoles = functions.https.onRequest(async (req, res) => {
  try {
    const db = admin.firestore();
    const usersRef = db.collection('users');

    // Get all users
    const snapshot = await usersRef.get();

    let migratedCount = 0;
    let alreadyHadRole = 0;

    // Use batched writes for efficiency
    const batchSize = 500;
    let batch = db.batch();
    let operationCount = 0;

    for (const doc of snapshot.docs) {
      const data = doc.data();

      // Check if role field is missing or empty
      if (!data.role || data.role === '') {
        batch.update(doc.ref, {
          role: 'user',
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        migratedCount++;
        operationCount++;

        // Commit batch every 500 operations
        if (operationCount >= batchSize) {
          await batch.commit();
          batch = db.batch();
          operationCount = 0;
        }
      } else {
        alreadyHadRole++;
      }
    }

    // Commit remaining operations
    if (operationCount > 0) {
      await batch.commit();
    }

    res.status(200).json({
      success: true,
      totalUsers: snapshot.size,
      migratedCount: migratedCount,
      alreadyHadRole: alreadyHadRole,
      message: `Migration complete! Updated ${migratedCount} users to role='user'`
    });

  } catch (error) {
    console.error('Migration error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * Helper function: Make a specific user an admin
 *
 * Call with: POST https://your-project.cloudfunctions.net/makeUserAdmin
 * Body: { "email": "admin@bioshield.com" }
 */
exports.makeUserAdmin = functions.https.onRequest(async (req, res) => {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({ error: 'Email is required' });
    }

    // Find user by email
    const db = admin.firestore();
    const snapshot = await db.collection('users')
      .where('email', '==', email)
      .limit(1)
      .get();

    if (snapshot.empty) {
      return res.status(404).json({ error: 'User not found' });
    }

    const userDoc = snapshot.docs[0];
    await userDoc.ref.update({
      role: 'admin',
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    res.status(200).json({
      success: true,
      message: `User ${email} is now an admin`,
      uid: userDoc.id
    });

  } catch (error) {
    console.error('Error making user admin:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});
```

**To deploy:**
```bash
cd functions
npm install firebase-functions firebase-admin
firebase deploy --only functions
```

**To run migration:**
```bash
# Option A: Using curl
curl https://your-project.cloudfunctions.net/migrateUserRoles

# Option B: Visit URL in browser
https://your-project.cloudfunctions.net/migrateUserRoles
```

**To make a user admin:**
```bash
curl -X POST https://your-project.cloudfunctions.net/makeUserAdmin \
  -H "Content-Type: application/json" \
  -d '{"email":"your.email@example.com"}'
```

---

### Option 3: Local Script (Node.js)

If you prefer to run migration from your local machine:

**migrate_roles.js:**
```javascript
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function migrateUserRoles() {
  try {
    const usersRef = db.collection('users');
    const snapshot = await usersRef.get();

    console.log(`Found ${snapshot.size} users`);

    let migratedCount = 0;
    let batch = db.batch();
    let operationCount = 0;

    for (const doc of snapshot.docs) {
      const data = doc.data();

      if (!data.role || data.role === '') {
        console.log(`Migrating user: ${data.email || doc.id}`);
        batch.update(doc.ref, {
          role: 'user',
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        migratedCount++;
        operationCount++;

        // Commit every 500 operations
        if (operationCount >= 500) {
          await batch.commit();
          console.log(`Committed batch of ${operationCount} updates`);
          batch = db.batch();
          operationCount = 0;
        }
      }
    }

    // Commit remaining
    if (operationCount > 0) {
      await batch.commit();
      console.log(`Committed final batch of ${operationCount} updates`);
    }

    console.log(`\n✅ Migration complete!`);
    console.log(`   Total users: ${snapshot.size}`);
    console.log(`   Migrated: ${migratedCount}`);

  } catch (error) {
    console.error('❌ Migration error:', error);
  }

  process.exit(0);
}

migrateUserRoles();
```

**To run:**
```bash
# 1. Download service account key from Firebase Console
#    Settings → Project Settings → Service Accounts → Generate new private key

# 2. Save as serviceAccountKey.json in same folder as script

# 3. Install dependencies
npm install firebase-admin

# 4. Run migration
node migrate_roles.js
```

---

## Verification

After migration, verify in Firebase Console:

1. Open Firestore Database
2. Check `users` collection
3. Each user should have:
   ```
   users/{uid}
   ├─ uid: "..."
   ├─ email: "user@example.com"
   ├─ username: "..."
   ├─ role: "user"  ✅ (or "admin" for admins)
   └─ membership:
      └─ isPremium: false
   ```

4. Your admin user should have:
   ```
   role: "admin"  ✅
   ```

---

## Testing in App

After migration, test in BioShield app:

**Test 1: Regular user access**
```dart
// Login as regular user
// Expected: role = 'user', can't access admin dashboard
```

**Test 2: Premium user access**
```dart
// Login as user with isPremium = true
// Expected: role = 'user', has premium features, can't access admin dashboard
```

**Test 3: Admin user access**
```dart
// Login as admin user
// Expected: role = 'admin', can access admin dashboard
final adminService = AdminService();
final isAdmin = await adminService.isAdmin();
print('Is Admin: $isAdmin');  // Should print: true
```

---

## Summary

**What changed:**
- ❌ Old: `role` could be `'free'`, `'premium'`, or `'admin'`
- ✅ New: `role` is either `'user'` or `'admin'`
- ✅ New: `isPremium` determines premium status (not role)
- ✅ New: Empty/missing role defaults to `'user'`

**Migration needed:**
- Add `role: 'user'` to all existing users without a role field
- Set `role: 'admin'` for admin users

**After migration:**
- All users will have a valid role
- App will correctly identify admins vs regular users
- Premium status controlled by `isPremium` field
