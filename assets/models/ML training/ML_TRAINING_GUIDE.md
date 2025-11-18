# BioShield ML Training Guide

## Overview
BioShield uses supervised learning for two binary classification tasks:
1. **Spoof Detection**: Genuine vs Fake biometric authentication
2. **Anomaly Detection**: Normal vs Anomalous authentication patterns

## Current Status

### ✅ What You Have
- **Training Notebook**: [train_bioshield_models.ipynb](train_bioshield_models.ipynb)
  - Complete TensorFlow training pipeline
  - Synthetic data generation
  - Model evaluation and visualization
  - TFLite conversion

- **ML Service**: [lib/services/ml_model_service.dart](lib/services/ml_model_service.dart)
  - Ready for TFLite model integration
  - Fallback to simulated predictions
  - Feature extraction implemented

- **Recommendation Engine**: [lib/services/recommendation_engine.dart](lib/services/recommendation_engine.dart)
  - ✅ **FULLY IMPLEMENTED**
  - Vulnerability-based recommendations
  - Priority-based mitigation strategies
  - Implementation plans with code examples

### ⚠️ What You Need
- **Real-world datasets** for training (currently using synthetic data)
- **Trained TFLite models** placed in `assets/models/`

---

## 📊 Recommended Datasets for Supervised Learning

### 1. Android Malware Detection Datasets

#### **CICAndMal2017** (Recommended ⭐)
- **Type**: Android malware detection
- **Size**: 5,000+ apps (426 malware families)
- **Labels**: Malware category labels
- **Features**: API calls, permissions, network traffic
- **Download**: https://www.unb.ca/cic/datasets/andmal2017.html
- **Use Case**: Train models to detect malicious behavior in apps

#### **Drebin Dataset** (Popular ⭐⭐⭐)
- **Type**: Android malware detection
- **Size**: 123,453 apps (5,560 malware samples)
- **Labels**: Binary (malware/benign)
- **Features**: Permissions, API calls, intents, network addresses
- **Download**: https://www.sec.cs.tu-bs.de/~danarp/drebin/
- **Use Case**: Excellent for permission-based malware detection

#### **AndroZoo**
- **Type**: Large-scale Android app repository
- **Size**: 10+ million APKs
- **Labels**: VirusTotal scan results
- **Download**: https://androzoo.uni.lu/
- **Use Case**: Need API key; great for large-scale training

#### **AMD (Android Malware Dataset)**
- **Type**: Android malware
- **Size**: 24,553 samples (71 malware families)
- **Labels**: Family labels
- **Download**: http://amd.arguslab.org/
- **Use Case**: Malware family classification

### 2. Biometric Security Datasets

#### **NIST Biometric Datasets**
- **Type**: Fingerprint, face, iris biometrics
- **Download**: https://www.nist.gov/itl/iad/image-group/biometric-special-databases
- **Use Case**: Train genuine vs spoof biometric detection

#### **LivDet (Liveness Detection)**
- **Type**: Fingerprint liveness detection
- **Size**: Thousands of live and fake fingerprint samples
- **Download**: http://livdet.org/
- **Use Case**: Spoof detection for biometric authentication

#### **CASIA Face Anti-Spoofing**
- **Type**: Face anti-spoofing
- **Size**: Video sequences of real and fake faces
- **Download**: http://www.cbsr.ia.ac.cn/users/jjyan/FAS.html
- **Use Case**: Detect presentation attacks (photos, videos, masks)

### 3. Network Intrusion & Anomaly Detection

#### **KDD Cup 99 / NSL-KDD**
- **Type**: Network intrusion detection
- **Labels**: Normal, DoS, Probe, R2L, U2R
- **Download**: https://www.unb.ca/cic/datasets/nsl.html
- **Use Case**: Anomaly detection in network traffic

#### **CICIDS2017/2018**
- **Type**: Intrusion detection system evaluation
- **Size**: 80+ features, labeled attack types
- **Download**: https://www.unb.ca/cic/datasets/ids-2017.html
- **Use Case**: Modern network anomaly detection

### 4. Authentication & User Behavior

#### **ADFA Intrusion Detection**
- **Type**: Host-based intrusion detection
- **Labels**: Normal vs attack behavior
- **Download**: https://www.unsw.adfa.edu.au/australian-centre-for-cyber-security/cybersecurity/ADFA-IDS-Datasets/
- **Use Case**: User behavior anomaly detection

---

## 🚀 Quick Start: Training Your Models

### Step 1: Install Prerequisites
```bash
pip install tensorflow numpy pandas scikit-learn matplotlib seaborn
```

### Step 2: Open Training Notebook
```bash
jupyter notebook train_bioshield_models.ipynb
```

### Step 3: Run All Cells
The notebook will:
1. Generate synthetic training data
2. Train both models (spoof detector & anomaly detector)
3. Evaluate model performance
4. Convert to TFLite format
5. Save models: `spoof_detector.tflite` and `anomaly_detector.tflite`

### Step 4: Deploy Models to Flutter
```bash
# Create models directory
mkdir -p assets/models

# Copy TFLite models
cp spoof_detector.tflite assets/models/
cp anomaly_detector.tflite assets/models/
```

### Step 5: Update pubspec.yaml
```yaml
flutter:
  assets:
    - assets/models/spoof_detector.tflite
    - assets/models/anomaly_detector.tflite
```

### Step 6: Test Integration
```bash
flutter run
```

---

## 📈 Training with Real Datasets

### Using Drebin Dataset (Example)

```python
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split

# Load Drebin dataset
df = pd.read_csv('drebin_features.csv')

# Features: API calls, permissions, network addresses
X = df.drop('label', axis=1).values  # Features
y = df['label'].values  # 0 = benign, 1 = malware

# Split data
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

# Train your model
model.fit(X_train, y_train, epochs=50, validation_split=0.2)

# Evaluate
loss, accuracy = model.evaluate(X_test, y_test)
print(f'Test Accuracy: {accuracy:.3f}')
```

### Using CICAndMal2017 (Example)

```python
# Extract features from APKs using Androguard
from androguard.core.bytecodes.apk import APK

def extract_features(apk_path):
    apk = APK(apk_path)

    features = {
        'permissions': len(apk.get_permissions()),
        'activities': len(apk.get_activities()),
        'services': len(apk.get_services()),
        'receivers': len(apk.get_receivers()),
        # Add more features...
    }

    return features

# Process dataset
features_list = []
labels_list = []

for apk_file in dataset_files:
    features = extract_features(apk_file)
    label = get_label(apk_file)  # From dataset metadata

    features_list.append(features)
    labels_list.append(label)

# Train model
X = np.array(features_list)
y = np.array(labels_list)
model.fit(X, y, epochs=100)
```

---

## 🎯 Model Performance Targets

### Spoof Detector
- **Accuracy**: > 95%
- **Precision**: > 93% (minimize false positives)
- **Recall**: > 97% (catch most spoofs)
- **F1-Score**: > 0.95

### Anomaly Detector
- **Accuracy**: > 92%
- **Precision**: > 90%
- **Recall**: > 88%
- **F1-Score**: > 0.89

---

## 🔧 Advanced Training Pipeline

### Enhanced Feature Engineering

```python
def extract_advanced_features(scan_data):
    """Extract comprehensive features for better detection"""

    features = {
        # Timing features
        'duration_ms': scan_data['duration'],
        'time_of_day': datetime.now().hour,
        'day_of_week': datetime.now().weekday(),

        # Entropy features
        'shannon_entropy': calculate_entropy(scan_data['data']),
        'byte_entropy': calculate_byte_distribution(scan_data['data']),

        # Crypto features
        'has_crypto': 1 if detect_crypto(scan_data) else 0,
        'crypto_strength': measure_crypto_strength(scan_data),

        # Network features
        'network_active': 1 if scan_data['network_detected'] else 0,
        'connection_count': len(scan_data.get('connections', [])),

        # Behavioral features
        'failed_attempts': scan_data.get('failed_count', 0),
        'location_change': detect_location_anomaly(scan_data),
        'device_change': detect_device_change(scan_data),
    }

    return features
```

### Cross-Validation

```python
from sklearn.model_selection import StratifiedKFold
from sklearn.metrics import classification_report

# 5-fold cross-validation
kfold = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)

cv_scores = []
for train_idx, val_idx in kfold.split(X, y):
    X_train, X_val = X[train_idx], X[val_idx]
    y_train, y_val = y[train_idx], y[val_idx]

    model = build_model()
    history = model.fit(X_train, y_train, epochs=50, verbose=0)

    score = model.evaluate(X_val, y_val, verbose=0)
    cv_scores.append(score[1])  # Accuracy

print(f'Cross-validation accuracy: {np.mean(cv_scores):.3f} ± {np.std(cv_scores):.3f}')
```

### Hyperparameter Tuning

```python
import keras_tuner as kt

def build_model(hp):
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(input_dim,)),
        tf.keras.layers.Dense(
            units=hp.Int('units_1', min_value=32, max_value=128, step=32),
            activation='relu'
        ),
        tf.keras.layers.Dropout(
            rate=hp.Float('dropout_1', min_value=0.1, max_value=0.5, step=0.1)
        ),
        tf.keras.layers.Dense(
            units=hp.Int('units_2', min_value=16, max_value=64, step=16),
            activation='relu'
        ),
        tf.keras.layers.Dense(1, activation='sigmoid')
    ])

    model.compile(
        optimizer=tf.keras.optimizers.Adam(
            hp.Float('learning_rate', min_value=1e-4, max_value=1e-2, sampling='LOG')
        ),
        loss='binary_crossentropy',
        metrics=['accuracy']
    )

    return model

# Run hyperparameter search
tuner = kt.RandomSearch(
    build_model,
    objective='val_accuracy',
    max_trials=20,
    directory='tuning',
    project_name='bioshield_spoof'
)

tuner.search(X_train, y_train, epochs=50, validation_split=0.2)
best_model = tuner.get_best_models(num_models=1)[0]
```

---

## 📦 Model Deployment Checklist

- [ ] Train models with sufficient data (>5000 samples per class)
- [ ] Achieve target accuracy (>92%)
- [ ] Convert to TFLite format
- [ ] Test TFLite inference
- [ ] Optimize model size (if needed)
- [ ] Copy to `assets/models/`
- [ ] Update `pubspec.yaml`
- [ ] Test in Flutter app
- [ ] Monitor production performance
- [ ] Plan retraining schedule

---

## 🔬 Data Collection Strategy

### For Production Models

1. **Collect Real Authentication Data**
   - User authentication attempts
   - Timing metrics
   - Success/failure rates
   - Device information

2. **Label Data**
   - Use expert review
   - Implement user feedback mechanism
   - Cross-validate with multiple methods

3. **Continuous Learning**
   - Collect new samples monthly
   - Retrain models quarterly
   - A/B test new models
   - Monitor drift metrics

---

## 📚 Additional Resources

- **TensorFlow Lite Guide**: https://www.tensorflow.org/lite/guide
- **Flutter TFLite Plugin**: https://pub.dev/packages/tflite_flutter
- **Scikit-learn Documentation**: https://scikit-learn.org/
- **Android Malware Analysis**: https://github.com/quark-engine/quark-engine

---

## 🆘 Troubleshooting

### Model Not Loading
```dart
// Check if model files exist
File modelFile = File('assets/models/spoof_detector.tflite');
if (!await modelFile.exists()) {
  print('Model file not found!');
}
```

### Low Accuracy
- Increase training data size
- Add more features
- Try different architectures
- Adjust hyperparameters
- Check data quality

### Slow Inference
- Use model quantization
- Reduce model complexity
- Enable GPU acceleration

---

## Next Steps

1. **Choose a dataset** from the recommendations above
2. **Modify the training notebook** to use real data
3. **Train your models** and evaluate performance
4. **Deploy to Flutter** and test integration
5. **Monitor and iterate** based on real-world performance
