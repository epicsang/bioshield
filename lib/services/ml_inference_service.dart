import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:math' as math;

/// ML Inference Service for BioShield
///
/// Handles loading and running TFLite models for:
/// 1. Spoof Detection - Identifies spoofed biometric attempts (Genuine/Fake)
/// 2. Anomaly Detection - Detects suspicious timing/behavior patterns (Normal/Anomalous)
///
/// Model Specifications (from train_bioshield_models.ipynb):
/// - Spoof Detector:
///   - Input: [1, 4] => [duration, entropy, hasCrypto, networkFlag]
///   - Output: [1, 1] => probability of being fake (0.0-1.0)
///   - Threshold: 0.5 (>0.5 = fake, <=0.5 = genuine)
///
/// - Anomaly Detector:
///   - Input: [1, 4] => [duration, entropy, timeOfDay, dayOfWeek]
///   - Output: [1, 1] => probability of being anomalous (0.0-1.0)
///   - Threshold: 0.5 (>0.5 = anomaly, <=0.5 = normal)
///
/// Both models use StandardScaler normalization (mean=0, std=1)
class MLInferenceService {
  // Model instances
  Interpreter? _anomalyDetector;
  Interpreter? _spoofDetector;

  // Model paths
  static const String anomalyModelPath = 'assets/models/anomaly_detector.tflite';
  static const String spoofModelPath = 'assets/models/spoof_detector.tflite';

  // Normalization parameters (from StandardScaler in training)
  // Spoof Detector: [duration, entropy, hasCrypto, networkFlag]
  static const List<double> spoofMeans = [190.0, 0.5, 0.55, 0.375];
  static const List<double> spoofStds = [110.0, 0.3, 0.5, 0.48];

  // Anomaly Detector: [duration, entropy, timeOfDay, dayOfWeek]
  static const List<double> anomalyMeans = [250.0, 0.6, 12.0, 4.0];
  static const List<double> anomalyStds = [200.0, 0.25, 6.0, 2.0];

  // Singleton pattern
  static final MLInferenceService _instance = MLInferenceService._internal();
  factory MLInferenceService() => _instance;
  MLInferenceService._internal();

  bool _isInitialized = false;

  /// Initialize both TFLite models
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load spoof detector model
      _spoofDetector = await Interpreter.fromAsset(spoofModelPath);

      // Load anomaly detector model
      _anomalyDetector = await Interpreter.fromAsset(anomalyModelPath);

      _isInitialized = true;
    } catch (e) {
      rethrow;
    }
  }

  /// Run spoof detection on biometric authentication data
  ///
  /// Input features: [duration, entropy, hasCrypto, networkFlag]
  /// Output: Probability of being fake/spoofed (0.0-1.0)
  ///
  /// Classification thresholds:
  /// - >0.7: High confidence SPOOF
  /// - 0.3-0.7: UNCERTAIN
  /// - <0.3: High confidence GENUINE
  Future<SpoofResult> detectSpoof(Map<String, dynamic> authData) async {
    if (!_isInitialized || _spoofDetector == null) {
      throw Exception('Spoof detector not initialized. Call initialize() first.');
    }

    try {
      // Extract features from auth data
      final features = _extractSpoofFeatures(authData);

      // Normalize features using training statistics
      final normalizedFeatures = _normalize(features, spoofMeans, spoofStds);

      // Prepare input tensor [1, 4]
      final input = [normalizedFeatures];

      // Prepare output tensor [1, 1]
      var output = List.filled(1, 0.0).reshape([1, 1]);

      // Run inference
      _spoofDetector!.run(input, output);

      // Parse result
      final spoofScore = output[0][0] as double;
      final genuineScore = 1.0 - spoofScore;

      // Determine classification based on confidence thresholds
      SpoofClassification classification;
      double confidence;

      if (spoofScore > 0.7) {
        // High confidence spoof
        classification = SpoofClassification.spoof;
        confidence = spoofScore;
      } else if (spoofScore < 0.3) {
        // High confidence genuine
        classification = SpoofClassification.genuine;
        confidence = genuineScore;
      } else {
        // Uncertain range
        classification = SpoofClassification.uncertain;
        confidence = 0.5 + (spoofScore - 0.5).abs();
      }

      return SpoofResult(
        classification: classification,
        confidence: confidence,
        genuineScore: genuineScore,
        spoofScore: spoofScore,
        features: features,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Run anomaly detection on hook scan data
  ///
  /// Input features: [duration, entropy, timeOfDay, dayOfWeek]
  /// Output: Probability of being anomalous (0.0-1.0)
  /// Threshold: 0.5 (>0.5 = anomaly, <=0.5 = normal)
  Future<AnomalyResult> detectAnomaly(Map<String, dynamic> scanData) async {
    if (!_isInitialized || _anomalyDetector == null) {
      throw Exception('Anomaly detector not initialized. Call initialize() first.');
    }

    try {
      // Extract features from scan data
      final features = _extractAnomalyFeatures(scanData);

      // Normalize features using training statistics
      final normalizedFeatures = _normalize(features, anomalyMeans, anomalyStds);

      // Prepare input tensor [1, 4]
      final input = [normalizedFeatures];

      // Prepare output tensor [1, 1]
      var output = List.filled(1, 0.0).reshape([1, 1]);

      // Run inference
      _anomalyDetector!.run(input, output);

      // Parse result
      final anomalyScore = output[0][0] as double;
      final normalScore = 1.0 - anomalyScore;

      return AnomalyResult(
        isAnomaly: anomalyScore > 0.5,
        confidence: anomalyScore,
        normalScore: normalScore,
        features: features,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Extract features for spoof detection from auth data
  ///
  /// Features: [duration, entropy, hasCrypto, networkFlag]
  List<double> _extractSpoofFeatures(Map<String, dynamic> authData) {
    // Duration - use total_duration from feature extractor or default 250ms
    final duration = (authData['total_duration'] ?? authData['duration'] ?? 250).toDouble();

    // Entropy from feature extractor
    final entropy = (authData['entropy'] ?? 0.5).toDouble();

    // Has crypto flag (1.0 if crypto is used, 0.0 otherwise)
    // Check both boolean and int formats
    final hasCryptoValue = authData['hasCrypto'];
    final hasCrypto = (hasCryptoValue == true || hasCryptoValue == 1) ? 1.0 : 0.0;

    // Network flag from logs (1.0 if suspicious network activity detected)
    final networkFlagValue = authData['networkFlag'];
    final networkFlag = (networkFlagValue == true || networkFlagValue == 1) ? 1.0 : 0.0;

    return [
      duration.clamp(10.0, 1000.0),
      entropy.clamp(0.0, 1.0),
      hasCrypto,
      networkFlag,
    ];
  }

  /// Extract features for anomaly detection from scan data
  ///
  /// Features: [duration, entropy, timeOfDay, dayOfWeek]
  List<double> _extractAnomalyFeatures(Map<String, dynamic> scanData) {
    // Use duration from feature data or default 250ms
    final avgDuration = (scanData['total_duration'] ?? 250.0).toDouble();

    // Use entropy from feature data or calculate from success/failure ratio
    double entropy;
    if (scanData.containsKey('entropy')) {
      entropy = (scanData['entropy'] ?? 0.5).toDouble();
    } else {
      // Calculate entropy based on success/failure ratio
      final successCount = (scanData['successCount'] ?? 0).toDouble();
      final failureCount = (scanData['failureCount'] ?? 0).toDouble();
      final totalAuth = successCount + failureCount;
      final successRate = totalAuth > 0 ? successCount / totalAuth : 0.5;
      entropy = _calculateBinaryEntropy(successRate);
    }

    // Get current time context
    final now = DateTime.now();
    final timeOfDay = now.hour.toDouble();
    final dayOfWeek = now.weekday.toDouble();

    return [
      avgDuration.clamp(10.0, 2000.0),
      entropy.clamp(0.0, 1.0),
      timeOfDay.clamp(0.0, 23.0),
      dayOfWeek.clamp(1.0, 7.0),
    ];
  }

  /// Normalize features using StandardScaler (z-score normalization)
  ///
  /// Formula: (x - mean) / std
  List<double> _normalize(List<double> features, List<double> means, List<double> stds) {
    final normalized = <double>[];
    for (int i = 0; i < features.length; i++) {
      final normalizedValue = (features[i] - means[i]) / stds[i];
      normalized.add(normalizedValue);
    }
    return normalized;
  }

  /// Calculate Shannon entropy for binary probability
  ///
  /// H(X) = -p*log2(p) - (1-p)*log2(1-p)
  /// Normalized to [0, 1] range
  double _calculateBinaryEntropy(double probability) {
    if (probability <= 0.0 || probability >= 1.0) return 0.0;

    final p = probability;
    final q = 1.0 - probability;

    // Shannon entropy (normalized)
    return -(p * _log2(p) + q * _log2(q));
  }

  /// Calculate log base 2
  double _log2(double x) {
    return x > 0 ? math.log(x) / math.ln2 : 0.0;
  }

  /// Dispose of model resources
  void dispose() {
    _anomalyDetector?.close();
    _spoofDetector?.close();
    _anomalyDetector = null;
    _spoofDetector = null;
    _isInitialized = false;
  }
}

/// Result from anomaly detection
class AnomalyResult {
  final bool isAnomaly;
  final double confidence;
  final double normalScore;
  final List<double> features;

  AnomalyResult({
    required this.isAnomaly,
    required this.confidence,
    required this.normalScore,
    required this.features,
  });

  Map<String, dynamic> toMap() {
    return {
      'isAnomaly': isAnomaly,
      'confidence': confidence,
      'normalScore': normalScore,
      'features': features,
    };
  }

  @override
  String toString() {
    return 'AnomalyResult(isAnomaly: $isAnomaly, confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
  }
}

/// Result from spoof detection
class SpoofResult {
  final SpoofClassification classification;
  final double confidence;
  final double genuineScore;
  final double spoofScore;
  final List<double> features;

  SpoofResult({
    required this.classification,
    required this.confidence,
    required this.genuineScore,
    required this.spoofScore,
    required this.features,
  });

  Map<String, dynamic> toMap() {
    return {
      'classification': classification.toString().split('.').last,
      'confidence': confidence,
      'genuineScore': genuineScore,
      'spoofScore': spoofScore,
      'features': features,
    };
  }

  @override
  String toString() {
    return 'SpoofResult(classification: ${classification.displayName}, confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
  }
}

/// Spoof detection classification
enum SpoofClassification {
  genuine,
  spoof,
  uncertain;

  String get displayName {
    switch (this) {
      case SpoofClassification.genuine:
        return 'Genuine';
      case SpoofClassification.spoof:
        return 'Spoof Detected';
      case SpoofClassification.uncertain:
        return 'Uncertain';
    }
  }

  String get emoji {
    switch (this) {
      case SpoofClassification.genuine:
        return '✅';
      case SpoofClassification.spoof:
        return '🚨';
      case SpoofClassification.uncertain:
        return '⚠️';
    }
  }
}
