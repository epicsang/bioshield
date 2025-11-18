# Firebase Admin Role Setup - Step by Step

## Quick Answer

You need to add the `role` field to **ONE place only**: your user document in Firestore.

---

## Exact Steps to Add Admin Role

### Step 1: Open Firebase Console
1. Go to: https://console.firebase.google.com/
2. Select your **BioShield** project

### Step 2: Navigate to Firestore Database
1. Click **"Firestore Database"** in the left sidebar
2. Click **"Data"** tab (if not already there)

### Step 3: Find Your User Document
1. Click on the **`users`** collection (should see list of user documents)
2. Find your user document by:
   - **Email**: Look for your email address
   - **UID**: Or find by your user ID

### Step 4: Add the `role` Field
1. Click on your user document (opens the document editor)
2. Look for existing fields like:
   ```
   uid: "abc123..."
   email: "youremail@example.com"
   username: "YourName"
   membership: { ... }
   ```
3. Click **"Add field"** button
4. Enter:
   - **Field name**: `role`
   - **Type**: Select `string` from dropdown
   - **Value**: `admin`
5. Click **"Save"** or **"Update"**

### Step 5: Verify
Your document should now look like this:
```
users/{your-uid}
├─ uid: "abc123..."
├─ email: "youremail@example.com"
├─ username: "YourName"
├─ role: "admin"  ✅ THIS IS WHAT YOU JUST ADDED
└─ membership:
   └─ isPremium: false
```

---

## Visual Guide

```
Firebase Console
└─ BioShield Project
   └─ Firestore Database
      └─ Data tab
         └─ users (collection)
            └─ {your-uid} (document) ← CLICK HERE
               ├─ uid: "..."
               ├─ email: "your@email.com"
               ├─ username: "..."
               ├─ role: "admin"  ← ADD THIS FIELD
               └─ membership: {...}
```

---

## Where NOT to Add It

❌ **Don't add it in**:
- Firebase Authentication (the "Users" section)
- Security Rules
- Cloud Functions
- Your code files (UserModel already handles it)
- Firebase Hosting
- Firebase Storage

✅ **Only add it in**:
- **Firestore Database → users collection → your user document**

---

## Screenshot Guide

**Step 1: Firestore Database**
```
Firebase Console Sidebar:
├─ Project Overview
├─ Authentication      ← NOT HERE
├─ Firestore Database  ← CLICK HERE ✅
├─ Storage
├─ Hosting
└─ ...
```

**Step 2: Data Tab**
```
Firestore Database tabs:
├─ Data     ← YOU ARE HERE ✅
├─ Rules
├─ Indexes
└─ Usage
```

**Step 3: Users Collection**
```
Collections:
├─ advertisementBanners
├─ supportRequests
└─ users  ← CLICK HERE ✅
   ├─ user_id_1 (document)
   ├─ user_id_2 (document) ← Find your document
   └─ user_id_3 (document)
```

**Step 4: Your User Document**
```
Document: users/abc123...

Fields:
┌──────────────┬────────┬─────────────────────┐
│ Field        │ Type   │ Value               │
├──────────────┼────────┼─────────────────────┤
│ uid          │ string │ abc123...           │
│ email        │ string │ you@email.com       │
│ username     │ string │ YourName            │
│ membership   │ map    │ { isPremium: false }│
│ role         │ string │ admin  ← ADD THIS   │
└──────────────┴────────┴─────────────────────┘

[Add field] button ← CLICK HERE TO ADD
```

---

## After Adding the Field

1. **Refresh your BioShield app** (close and reopen)
2. **Login** to your account
3. You should now see the **Admin Dashboard** option
4. Navigate to Admin Dashboard to verify access

---

## Troubleshooting

### "I added the field but I'm still not an admin"

**Check 1: Field name is correct**
- Must be exactly: `role` (lowercase, no spaces)

**Check 2: Field value is correct**
- Must be exactly: `admin` (lowercase, no quotes in Firestore UI)

**Check 3: Added to correct document**
- Make sure it's YOUR user document (check email matches)

**Check 4: App cache**
- Close and reopen the app
- Or logout and login again

### "I can't find my user document"

**Solution:**
1. In Firestore Data tab, click **`users`** collection
2. Look for the document with YOUR email address
3. If you have many users, use **Ctrl+F** to search for your email

### "The Add field button is greyed out"

**Solution:**
- Make sure you've clicked ON the document itself (not just the collection)
- You should see the document's fields displayed
- The path should show: `users/{some-id}`

---

## Quick Reference

| What | Where | Value |
|------|-------|-------|
| **Collection** | `users` | N/A |
| **Document** | Your user UID | N/A |
| **Field Name** | `role` | string |
| **Field Value** | `admin` | N/A |

---

## Summary

**You only need to add ONE field in ONE place:**

1. Open Firebase Console
2. Go to Firestore Database
3. Click `users` collection
4. Click YOUR user document
5. Add field: `role` = `"admin"`
6. Save
7. Done! ✅

**That's it!** The app code already checks this field. You don't need to add anything else anywhere else.
