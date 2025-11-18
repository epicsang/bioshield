package com.fyp.bioshield.bioshield;

import android.content.Context;
import android.util.Log;
import org.json.JSONObject;
import java.io.File;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * HookManager - Central coordinator for the in-app hooking framework
 * Manages HookEngine, BiometricProxy, TimingTracker, and LogStore
 */
public class HookManager {
    private static final String TAG = "BioShield.HookManager";
    private static HookManager instance;

    private Context context;
    private HookEngine hookEngine;
    private BiometricProxy biometricProxy;
    private TimingTracker timingTracker;
    private LogStore logStore;

    private boolean initialized = false;
    private boolean enabled = true;

    private HookManager(Context context) {
        this.context = context.getApplicationContext();
    }

    public static synchronized HookManager getInstance(Context context) {
        if (instance == null) {
            instance = new HookManager(context);
        }
        return instance;
    }

    /**
     * Initialize all hooking components
     */
    public void initialize() {
        if (initialized) {
            Log.d(TAG, "HookManager already initialized");
            return;
        }

        Log.d(TAG, "Initializing HookManager...");

        try {
            // Initialize components
            hookEngine = HookEngine.getInstance(context);
            biometricProxy = BiometricProxy.getInstance(context);
            timingTracker = TimingTracker.getInstance();
            logStore = LogStore.getInstance(context);

            initialized = true;

            // Log initialization
            Map<String, Object> initData = new HashMap<>();
            initData.put("event", "hook_manager_initialized");
            initData.put("packageName", context.getPackageName());
            initData.put("sdkInt", android.os.Build.VERSION.SDK_INT);
            logStore.log("SYSTEM", initData);

            Log.d(TAG, "✓ HookManager initialized successfully");
            logSystemInfo();

        } catch (Exception e) {
            Log.e(TAG, "Error initializing HookManager", e);
            logStore.logException("hook_manager_init_error", e);
        }
    }

    /**
     * Enable/disable hooking framework
     */
    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
        if (hookEngine != null) {
            hookEngine.setEnabled(enabled);
        }

        Map<String, Object> data = new HashMap<>();
        data.put("event", "hook_manager_toggled");
        data.put("enabled", enabled);
        logStore.log("SYSTEM", data);

        Log.d(TAG, "HookManager " + (enabled ? "enabled" : "disabled"));
    }

    public boolean isEnabled() {
        return enabled;
    }

    /**
     * Get HookEngine instance
     */
    public HookEngine getHookEngine() {
        ensureInitialized();
        return hookEngine;
    }

    /**
     * Get BiometricProxy instance
     */
    public BiometricProxy getBiometricProxy() {
        ensureInitialized();
        return biometricProxy;
    }

    /**
     * Get TimingTracker instance
     */
    public TimingTracker getTimingTracker() {
        ensureInitialized();
        return timingTracker;
    }

    /**
     * Get LogStore instance
     */
    public LogStore getLogStore() {
        ensureInitialized();
        return logStore;
    }

    /**
     * Get comprehensive statistics
     */
    public Map<String, Object> getStats() {
        ensureInitialized();

        Map<String, Object> stats = new HashMap<>();
        stats.put("initialized", initialized);
        stats.put("enabled", enabled);

        // Component stats
        stats.put("hookEngine", hookEngine.getStats());
        stats.put("biometricProxy", biometricProxy.getStats());
        stats.put("timingTracker", timingTracker.getStats());
        stats.put("logStore", logStore.getStats());

        return stats;
    }

    /**
     * Get all logged events
     */
    public List<LogStore.LogEntry> getAllLogs() {
        ensureInitialized();
        return logStore.readAllLogs();
    }

    /**
     * Get logs by category
     */
    public List<LogStore.LogEntry> getLogsByCategory(String category) {
        ensureInitialized();
        return logStore.readLogsByCategory(category);
    }

    /**
     * Export logs for ML analysis
     */
    public File exportLogsForML() {
        ensureInitialized();
        return logStore.exportLogsForML();
    }

    /**
     * Get scan report with analysis
     */
    public Map<String, Object> generateScanReport() {
        ensureInitialized();

        Map<String, Object> report = new HashMap<>();
        report.put("timestamp", System.currentTimeMillis());
        report.put("packageName", context.getPackageName());

        // Get all biometric auth logs
        List<LogStore.LogEntry> authLogs = logStore.readLogsByCategory("BIOMETRIC_AUTH");
        report.put("authEventCount", authLogs.size());

        // Analyze auth events
        int successCount = 0;
        int failureCount = 0;
        int errorCount = 0;

        for (LogStore.LogEntry entry : authLogs) {
            String event = (String) entry.data.get("event");
            if (event != null) {
                if (event.equals("onAuthenticationSucceeded")) successCount++;
                else if (event.equals("onAuthenticationFailed")) failureCount++;
                else if (event.equals("onAuthenticationError")) errorCount++;
            }
        }

        report.put("successCount", successCount);
        report.put("failureCount", failureCount);
        report.put("errorCount", errorCount);

        // Get timing analysis
        Map<String, Object> timingStats = timingTracker.getStats();
        report.put("timingStats", timingStats);

        // Check for anomalies
        boolean hasAnomalies = timingTracker.hasSessionAnomalies();
        report.put("hasAnomalies", hasAnomalies);

        if (hasAnomalies) {
            report.put("anomalyReport", timingTracker.getSessionAnomalyReport());
        }

        // Risk assessment
        String riskLevel = assessRiskLevel(
            (Integer) timingStats.get("suspiciousTimings"),
            (Integer) timingStats.get("rapidRetries"),
            hasAnomalies
        );
        report.put("riskLevel", riskLevel);

        Log.d(TAG, "Generated scan report: " + report);
        return report;
    }

    /**
     * Assess risk level based on collected data
     */
    private String assessRiskLevel(int suspiciousTimings, int rapidRetries, boolean hasAnomalies) {
        if (suspiciousTimings > 3 || rapidRetries > 5) {
            return "HIGH";
        } else if (suspiciousTimings > 1 || rapidRetries > 2 || hasAnomalies) {
            return "MEDIUM";
        } else if (suspiciousTimings > 0 || rapidRetries > 0) {
            return "LOW";
        }
        return "SAFE";
    }

    /**
     * Clear all logs and reset state
     */
    public void clearAllData() {
        ensureInitialized();

        hookEngine.clearHooks();
        timingTracker.clear();
        logStore.clearLogs();

        Log.d(TAG, "All hooking data cleared");
    }

    /**
     * Log system information
     */
    private void logSystemInfo() {
        Map<String, Object> systemInfo = new HashMap<>();
        systemInfo.put("event", "system_info");
        systemInfo.put("manufacturer", android.os.Build.MANUFACTURER);
        systemInfo.put("model", android.os.Build.MODEL);
        systemInfo.put("sdkInt", android.os.Build.VERSION.SDK_INT);
        systemInfo.put("release", android.os.Build.VERSION.RELEASE);
        systemInfo.put("packageName", context.getPackageName());

        // Check biometric availability
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
            android.hardware.fingerprint.FingerprintManager fpManager =
                (android.hardware.fingerprint.FingerprintManager)
                    context.getSystemService(Context.FINGERPRINT_SERVICE);
            if (fpManager != null) {
                systemInfo.put("hasFingerprint", fpManager.isHardwareDetected());
            }
        }

        logStore.log("SYSTEM", systemInfo);
        Log.d(TAG, "System info logged: " + systemInfo);
    }

    /**
     * Get status message for display
     */
    public String getStatusMessage() {
        if (!initialized) {
            return "HookManager not initialized";
        }

        Map<String, Object> stats = getStats();
        int logCount = (int) ((Map<String, Object>) stats.get("logStore")).get("totalLogs");
        int sessions = (int) ((Map<String, Object>) stats.get("timingTracker")).get("totalSessions");

        return String.format("✓ Active | Logs: %d | Sessions: %d | Status: %s",
            logCount, sessions, enabled ? "Enabled" : "Disabled");
    }

    /**
     * Export comprehensive report as JSON
     */
    public String exportReportAsJson() {
        try {
            Map<String, Object> report = generateScanReport();
            JSONObject json = new JSONObject(report);
            return json.toString(2); // Pretty print with indent
        } catch (Exception e) {
            Log.e(TAG, "Error exporting report", e);
            return "{}";
        }
    }

    /**
     * Ensure HookManager is initialized
     */
    private void ensureInitialized() {
        if (!initialized) {
            throw new IllegalStateException(
                "HookManager not initialized. Call initialize() first.");
        }
    }

    /**
     * Shutdown hook manager
     */
    public void shutdown() {
        if (logStore != null) {
            logStore.shutdown();
        }

        initialized = false;
        Log.d(TAG, "HookManager shut down");
    }

    /**
     * Quick check if hooking is working
     */
    public boolean isHookingActive() {
        return initialized && enabled && hookEngine != null && hookEngine.isEnabled();
    }

    /**
     * Get hook status for debugging
     */
    public Map<String, Object> getDebugInfo() {
        Map<String, Object> debug = new HashMap<>();
        debug.put("initialized", initialized);
        debug.put("enabled", enabled);
        debug.put("hookEngine", hookEngine != null);
        debug.put("biometricProxy", biometricProxy != null);
        debug.put("timingTracker", timingTracker != null);
        debug.put("logStore", logStore != null);

        if (initialized) {
            debug.put("stats", getStats());
        }

        return debug;
    }
}
