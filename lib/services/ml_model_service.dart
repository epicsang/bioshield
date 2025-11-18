// lib/services/ml_model_service.dart
// Machine Learning Model Service - TensorFlow Lite integration
// Provides spoof detection and anomaly detection capabilities

import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:io';

// NOTE: TFLite models need to be trained and placed in assets/models/
// For now, this will use simulated predictions until models are available

/// ML prediction result
class MLPrediction {
  final bool isAnomaly;
  final double confidence;
  final String classification;
  final Map<String, double> features;

  MLPrediction({
    required this.isAnomaly,
    required this.confidence,
    required this.classification,
    required this.features,
  });

  Map<String, dynamic> toMap() {
    return {
      'isAnomaly': isAnomaly,
      'confidence': confidence,
      'classification': classification,
      'features': features,
    };
  }
}

/// Machine Learning Model Service
/// TensorFlow Lite integration for biometric security analysis
class MLModelService {
  bool _isInitialized = false;
  Interpreter? _spoofDetector;
  Interpreter? _anomalyDetector;

  // Model thresholds
  static const double SPOOF_THRESHOLD = 0.5;
  static const double ANOMALY_THRESHOLD = 0.5;

  // StandardScaler parameters (from Python training - generated Nov 2023)
  // Updated with actual values from train_bioshield_models.ipynb output
  static const List<double> SPOOF_SCALER_MEAN = [
    30.282838688027674,   // sensor_latency
    115.27115081284573,   // detection_latency
    34.84808114246492,    // completion_latency
    180.284600071701,     // total_duration
    0.8511428571428571,   // retry_count
    0.7022857142857143,   // failure_reason
    0.46995879726626694,  // cpu_load
    0.3942857142857143,   // thermal_state
    1.1077142857142857,   // screen_state
    0.49619484531637825,  // entropy
    0.5554285714285714,   // hasCrypto
    0.38085714285714284,  // networkFlag
  ];

  static const List<double> SPOOF_SCALER_STD = [
    22.952315178713224,   // sensor_latency
    89.9890015899621,     // detection_latency
    17.402736417570015,   // completion_latency
    124.3958685166871,    // total_duration
    1.1930088526280904,   // retry_count
    1.19400666596436,     // failure_reason
    0.31778629268968067,  // cpu_load
    0.6667374112123852,   // thermal_state
    0.7002839657260967,   // screen_state
    0.32345569811570296,  // entropy
    0.49691817582916936,  // hasCrypto
    0.48559754899694196,  // networkFlag
  ];

  static const List<double> ANOMALY_SCALER_MEAN = [
    56.436120619643674,   // sensor_latency
    239.51277585702846,   // detection_latency
    43.97003656705354,    // completion_latency
    339.2125737247317,    // total_duration
    0.5065714285714286,   // retry_count
    0.3357142857142857,   // failure_reason
    0.3911008448476017,   // cpu_load
    0.386,                // thermal_state
    1.0994285714285714,   // screen_state
    0.5410153151736792,   // entropy
    10.44234359452109,    // timeOfDay
    3.963142857142857,    // dayOfWeek
  ];

  static const List<double> ANOMALY_SCALER_STD = [
    38.80332753601904,    // sensor_latency
    150.02423348665624,   // detection_latency
    14.653524620416393,   // completion_latency
    183.0142398033698,    // total_duration
    0.9807939724154735,   // retry_count
    0.8288607869127755,   // failure_reason
    0.28800058974696063,  // cpu_load
    0.711038275039675,    // thermal_state
    0.6195387355912297,   // screen_state
    0.24045020239866505,  // entropy
    6.455778328076898,    // timeOfDay
    1.9661598124676998,   // dayOfWeek
  ];

  /// Initialize ML models
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Try to load TensorFlow Lite models if they exist
      try {
        _spoofDetector = await Interpreter.fromAsset('assets/models/spoof_detector.tflite');
        print('✅ Spoof detector model loaded');
      } catch (e) {
        print('⚠️ Spoof detector model not found, using simulated predictions');
      }

      try {
        _anomalyDetector = await Interpreter.fromAsset('assets/models/anomaly_detector.tflite');
        print('✅ Anomaly detector model loaded');
      } catch (e) {
        print('⚠️ Anomaly detector model not found, using simulated predictions');
      }

      _isInitialized = true;
      print('✅ ML service initialized');
    } catch (e) {
      print('❌ ML initialization error: $e');
      _isInitialized = true; // Continue with simulated mode
    }
  }

  /// Detect spoofing attempts
  /// Analyzes biometric data to identify fake biometric attempts
  Future<MLPrediction> detectSpoof({
    required Map<String, dynamic> biometricData,
  }) async {
    if (!_isInitialized) await initialize();

    final features = _extractSpoofFeatures(biometricData);
    double confidence;

    // Use TFLite model if available, otherwise simulate
    if (_spoofDetector != null) {
      confidence = await _runSpoofModel(features);
    } else {
      confidence = _simulateSpoofPrediction(features);
    }

    final isSpoof = confidence > SPOOF_THRESHOLD;

    return MLPrediction(
      isAnomaly: isSpoof,
      confidence: confidence,
      classification: isSpoof ? 'Fake Biometric' : 'Genuine Biometric',
      features: features,
    );
  }

  /// Run actual TFLite spoof detection model
  Future<double> _runSpoofModel(Map<String, double> features) async {
    try {
      // Extract features in correct order (12 features)
      final featureList = [
        features['sensor_latency']!,
        features['detection_latency']!,
        features['completion_latency']!,
        features['total_duration']!,
        features['retry_count']!,
        features['failure_reason']!,
        features['cpu_load']!,
        features['thermal_state']!,
        features['screen_state']!,
        features['entropy']!,
        features['hasCrypto']!,
        features['networkFlag']!,
      ];

      // Apply StandardScaler normalization: (x - mean) / std
      final normalizedFeatures = List<double>.generate(12, (i) {
        return (featureList[i] - SPOOF_SCALER_MEAN[i]) / SPOOF_SCALER_STD[i];
      });

      // Prepare input tensor [1, 12]
      final input = [normalizedFeatures];

      // Prepare output tensor [1, 1]
      final output = List.filled(1, 0.0).reshape([1, 1]);

      // Run inference
      _spoofDetector!.run(input, output);

      return output[0][0];
    } catch (e) {
      print('⚠️ TFLite inference error, falling back to simulation: $e');
      return _simulateSpoofPrediction(features);
    }
  }

  /// Detect anomalies in authentication patterns
  /// Identifies unusual authentication behavior
  Future<MLPrediction> detectAnomaly({
    required Map<String, dynamic> authMetrics,
  }) async {
    if (!_isInitialized) await initialize();

    final features = _extractAnomalyFeatures(authMetrics);
    double confidence;

    // Use TFLite model if available, otherwise simulate
    if (_anomalyDetector != null) {
      confidence = await _runAnomalyModel(features);
    } else {
      confidence = _simulateAnomalyPrediction(features);
    }

    final isAnomaly = confidence > ANOMALY_THRESHOLD;

    return MLPrediction(
      isAnomaly: isAnomaly,
      confidence: confidence,
      classification: isAnomaly
          ? 'Anomalous Authentication'
          : 'Normal Authentication',
      features: features,
    );
  }

  /// Run actual TFLite anomaly detection model
  Future<double> _runAnomalyModel(Map<String, double> features) async {
    try {
      // Extract features in correct order (12 features)
      final featureList = [
        features['sensor_latency']!,
        features['detection_latency']!,
        features['completion_latency']!,
        features['total_duration']!,
        features['retry_count']!,
        features['failure_reason']!,
        features['cpu_load']!,
        features['thermal_state']!,
        features['screen_state']!,
        features['entropy']!,
        features['timeOfDay']!,
        features['dayOfWeek']!,
      ];

      // Apply StandardScaler normalization: (x - mean) / std
      final normalizedFeatures = List<double>.generate(12, (i) {
        return (featureList[i] - ANOMALY_SCALER_MEAN[i]) / ANOMALY_SCALER_STD[i];
      });

      // Prepare input tensor [1, 12]
      final input = [normalizedFeatures];

      // Prepare output tensor [1, 1]
      final output = List.filled(1, 0.0).reshape([1, 1]);

      // Run inference
      _anomalyDetector!.run(input, output);

      return output[0][0];
    } catch (e) {
      print('⚠️ TFLite inference error, falling back to simulation: $e');
      return _simulateAnomalyPrediction(features);
    }
  }

  /// Extract features for spoof detection (Enhanced - 12 features)
  Map<String, double> _extractSpoofFeatures(Map<String, dynamic> data) {
    // Get timestamps with defaults
    final authStart = (data['auth_start_ms'] as num?)?.toDouble() ?? 0.0;
    final sensorAcquire = (data['sensor_acquire_ms'] as num?)?.toDouble() ?? (authStart + 50);
    final detection = (data['detection_ms'] as num?)?.toDouble() ?? (sensorAcquire + 200);
    final successFailure = (data['success_failure_ms'] as num?)?.toDouble() ?? (detection + 50);

    // Calculate derived latencies
    final sensorLatency = sensorAcquire - authStart;
    final detectionLatency = detection - sensorAcquire;
    final completionLatency = successFailure - detection;
    final totalDuration = successFailure - authStart;

    return {
      // Timing features
      'sensor_latency': sensorLatency.clamp(0, 5000),
      'detection_latency': detectionLatency.clamp(0, 5000),
      'completion_latency': completionLatency.clamp(0, 5000),
      'total_duration': totalDuration.clamp(0, 5000),
      // Failure analysis
      'retry_count': (data['retry_count'] as num?)?.toDouble() ?? 0.0,
      'failure_reason': (data['failure_reason'] as num?)?.toDouble() ?? 0.0,
      // Device state
      'cpu_load': (data['cpu_load'] as num?)?.toDouble() ?? 0.0,
      'thermal_state': (data['thermal_state'] as num?)?.toDouble() ?? 0.0,
      'screen_state': (data['screen_state'] as num?)?.toDouble() ?? 1.0,
      // Biometric quality
      'entropy': (data['entropy'] as num?)?.toDouble() ?? 0.5,
      'hasCrypto': (data['hasCrypto'] as num?)?.toDouble() ?? 0.0,
      'networkFlag': (data['networkFlag'] as num?)?.toDouble() ?? 0.0,
    };
  }

  /// Extract features for anomaly detection (Enhanced - 12 features)
  Map<String, double> _extractAnomalyFeatures(Map<String, dynamic> data) {
    // Get timestamps with defaults
    final authStart = (data['auth_start_ms'] as num?)?.toDouble() ?? 0.0;
    final sensorAcquire = (data['sensor_acquire_ms'] as num?)?.toDouble() ?? (authStart + 50);
    final detection = (data['detection_ms'] as num?)?.toDouble() ?? (sensorAcquire + 200);
    final successFailure = (data['success_failure_ms'] as num?)?.toDouble() ?? (detection + 50);

    // Calculate derived latencies
    final sensorLatency = sensorAcquire - authStart;
    final detectionLatency = detection - sensorAcquire;
    final completionLatency = successFailure - detection;
    final totalDuration = successFailure - authStart;

    // Extract temporal context from timestamp
    final timestamp = authStart > 0 ? DateTime.fromMillisecondsSinceEpoch(authStart.toInt()) : DateTime.now();

    return {
      // Timing features
      'sensor_latency': sensorLatency.clamp(0, 5000),
      'detection_latency': detectionLatency.clamp(0, 5000),
      'completion_latency': completionLatency.clamp(0, 5000),
      'total_duration': totalDuration.clamp(0, 5000),
      // Failure analysis
      'retry_count': (data['retry_count'] as num?)?.toDouble() ?? 0.0,
      'failure_reason': (data['failure_reason'] as num?)?.toDouble() ?? 0.0,
      // Device state
      'cpu_load': (data['cpu_load'] as num?)?.toDouble() ?? 0.0,
      'thermal_state': (data['thermal_state'] as num?)?.toDouble() ?? 0.0,
      'screen_state': (data['screen_state'] as num?)?.toDouble() ?? 1.0,
      // Biometric quality
      'entropy': (data['entropy'] as num?)?.toDouble() ?? 0.5,
      // Temporal context
      'timeOfDay': timestamp.hour.toDouble(),
      'dayOfWeek': timestamp.weekday.toDouble(),
    };
  }

  /// Simulate spoof prediction (Enhanced heuristics - REPLACE WITH ACTUAL MODEL)
  double _simulateSpoofPrediction(Map<String, double> features) {
    final random = Random();

    // Enhanced heuristic simulation using all 12 features
    double score = 0.0;

    // Timing analysis - too fast is suspicious
    if (features['total_duration']! < 100) {
      score += 0.25;
    }
    if (features['sensor_latency']! < 20) {
      score += 0.15;
    }
    if (features['detection_latency']! < 50) {
      score += 0.15;
    }

    // Failure analysis - high retry count is suspicious
    if (features['retry_count']! > 2) {
      score += 0.2;
    }

    // Device state - high CPU with fast auth is suspicious
    if (features['cpu_load']! > 0.7 && features['total_duration']! < 200) {
      score += 0.2;
    }

    // Biometric quality - low entropy is suspicious
    if (features['entropy']! < 0.3) {
      score += 0.15;
    }

    // No crypto is suspicious
    if (features['hasCrypto']! == 0.0) {
      score += 0.15;
    }

    // Network transmission is suspicious
    if (features['networkFlag']! == 1.0) {
      score += 0.15;
    }

    // Add some randomness
    score += random.nextDouble() * 0.1;

    return score.clamp(0.0, 1.0);
  }

  /// Simulate anomaly prediction (Enhanced heuristics - REPLACE WITH ACTUAL MODEL)
  double _simulateAnomalyPrediction(Map<String, double> features) {
    final random = Random();

    // Enhanced heuristic simulation using all 12 features
    double score = 0.0;

    // Timing analysis - very short or very long is anomalous
    if (features['total_duration']! < 50 || features['total_duration']! > 2000) {
      score += 0.3;
    }

    // Inconsistent timing pattern
    if (features['sensor_latency']! > 300 || features['detection_latency']! > 1000) {
      score += 0.2;
    }

    // Failure analysis - high retry count is anomalous
    if (features['retry_count']! > 3) {
      score += 0.25;
    }

    // Device state - unusual thermal state
    if (features['thermal_state']! >= 2) {
      score += 0.15;
    }

    // Screen off during auth is anomalous
    if (features['screen_state']! == 0.0) {
      score += 0.2;
    }

    // Low entropy is anomalous
    if (features['entropy']! < 0.2) {
      score += 0.2;
    }

    // Authentication at unusual times (1-5 AM) is suspicious
    if (features['timeOfDay']! >= 1 && features['timeOfDay']! <= 5) {
      score += 0.25;
    }

    // Weekend authentication patterns (less common)
    if (features['dayOfWeek']! >= 6) {
      score += 0.1;
    }

    // Add some randomness
    score += random.nextDouble() * 0.1;

    return score.clamp(0.0, 1.0);
  }

  /// Dispose resources
  void dispose() {
    // Close TensorFlow Lite interpreters
    _spoofDetector?.close();
    _anomalyDetector?.close();
    _spoofDetector = null;
    _anomalyDetector = null;
    _isInitialized = false;
  }
}

/* =============================================================================
   ACTUAL TENSORFLOW LITE IMPLEMENTATION GUIDE
   =============================================================================

   Step 1: Add dependencies to pubspec.yaml
   -----------------------------------------
   dependencies:
     tflite_flutter: ^0.10.0
     tflite_flutter_helper: ^0.3.1

   Step 2: Train your models (Python/TensorFlow)
   -----------------------------------------------
   import tensorflow as tf
   from tensorflow import keras

   # Example: Spoof Detection Model
   model = keras.Sequential([
       keras.layers.Dense(64, activation='relu', input_shape=(4,)),
       keras.layers.Dropout(0.2),
       keras.layers.Dense(32, activation='relu'),
       keras.layers.Dense(1, activation='sigmoid')
   ])

   model.compile(
       optimizer='adam',
       loss='binary_crossentropy',
       metrics=['accuracy']
   )

   # Train with your dataset
   model.fit(X_train, y_train, epochs=50, validation_split=0.2)

   # Convert to TensorFlow Lite
   converter = tf.lite.TFLiteConverter.from_keras_model(model)
   tflite_model = converter.convert()

   with open('spoof_detector.tflite', 'wb') as f:
       f.write(tflite_model)

   Step 3: Add models to Flutter assets
   -------------------------------------
   1. Create assets/models/ folder
   2. Copy .tflite files to assets/models/
   3. Update pubspec.yaml:
      flutter:
        assets:
          - assets/models/spoof_detector.tflite
          - assets/models/anomaly_detector.tflite

   Step 4: Implement actual inference
   -----------------------------------
   import 'package:tflite_flutter/tflite_flutter.dart';

   class ActualMLService {
     Interpreter? _spoofDetector;
     Interpreter? _anomalyDetector;

     Future<void> loadModels() async {
       _spoofDetector = await Interpreter.fromAsset(
         'assets/models/spoof_detector.tflite'
       );
       _anomalyDetector = await Interpreter.fromAsset(
         'assets/models/anomaly_detector.tflite'
       );
     }

     Future<double> detectSpoof(List<double> features) async {
       var input = [features];  // Shape: [1, 4]
       var output = List.filled(1, 0.0).reshape([1, 1]);

       _spoofDetector!.run(input, output);

       return output[0][0];  // Probability of spoof
     }
   }

   Step 5: Feature engineering
   ---------------------------
   - Collect training data from real authentication attempts
   - Label data as genuine/spoof or normal/anomaly
   - Extract relevant features (timing, entropy, etc.)
   - Normalize features to 0-1 range
   - Train model with balanced dataset
   - Evaluate on test set (aim for >92% accuracy)

   Step 6: Deploy and monitor
   ---------------------------
   - Deploy models with app
   - Monitor model performance in production
   - Collect feedback for retraining
   - Update models periodically
   - Version models for A/B testing

============================================================================= */
