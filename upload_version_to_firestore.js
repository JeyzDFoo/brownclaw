const admin = require('firebase-admin');
const fs = require('fs');

// Initialize Firebase Admin (uses default credentials)
admin.initializeApp();

const db = admin.firestore();

async function uploadVersionDoc() {
  try {
    // Read the generated JSON file
    const versionData = JSON.parse(fs.readFileSync('firestore_version_doc.json', 'utf8'));
    
    console.log('🔥 Uploading version document to Firestore...');
    console.log(`📦 Version: ${versionData.version} (Build ${versionData.buildNumber})`);
    
    // Upload to Firestore
    await db.collection('app_config').doc('version').set(versionData);
    
    console.log('✅ Version document uploaded successfully!');
    console.log('');
    console.log('🚀 Your app will now check Firestore for version updates');
    console.log('   This completely bypasses PWA caching issues!');
    
  } catch (error) {
    console.error('❌ Error uploading version document:', error);
    process.exit(1);
  }
}

uploadVersionDoc();