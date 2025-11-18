package com.fyp.bioshield.bioshield;

import android.util.Log;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * TimingTracker - Detects side-channel timing anomalies in biometric authentication
 * Tracks timestamps, durations, and patterns that may indicate bypass attempts
 */
public class TimingTracker {
    private static final String TAG = "BioShield.TimingTracker";
    private static TimingTracker instance;

    // Timing thresholds (in milliseconds)
    private static final long MIN_REALISTIC_AUTH_TIME = 200;  // Too fast = suspicious
    private static final long MAX_REALISTIC_AUTH_TIME = 30000; // Too slow = suspicious
    private static final long RAPID_RETRY_THRESHOLD = 500;     // Multiple attempts too quickly

    // Session tracking
    private String currentSessionId;
    private long sessionStartTime;
    private int sessionEventCount;
    private Map<String, Long> lastEventTimes;
    private List<TimingEvent> eventHistory;
    private Map<String, Integer> eventCounts;

    // Statistics
    private int totalSessions;
    private int suspiciousTimings;
    private int rapidRetries;

    private TimingTracker() {
        this.lastEventTimes = new ConcurrentHashMap<>();
        this.eventHistory = new ArrayList<>();
        this.eventCounts = new ConcurrentHashMap<>();
        Log.d(TAG, "TimingTracker initialized");
    }

    public static synchronized TimingTracker getInstance() {
        if (instance == null) {
            instance = new TimingTracker();
        }
        return instance;
    }

    /**
     * Start a new timing session
     */
    public void startSession() {
        currentSessionId = "timing_session_" + System.currentTimeMillis();
        sessionStartTime = System.currentTimeMillis();
        sessionEventCount = 0;
        totalSessions++;

        Log.d(TAG, String.format("Started timing session: %s", currentSessionId));
    }

    /**
     * Record an event and return the duration since last similar event
     */
    public long recordEvent(String eventType, int eventCode) {
        long timestamp = System.currentTimeMillis();
        long duration = 0;

        // Calculate duration
        Long lastTime = lastEventTimes.get(eventType);
        if (lastTime != null) {
            duration = timestamp - lastTime;
        } else if (sessionStartTime > 0) {
            duration = timestamp - sessionStartTime;
        }

        // Store timing event
        TimingEvent event = new TimingEvent(
            eventType,
            eventCode,
            timestamp,
            duration,
            currentSessionId
        );
        eventHistory.add(event);

        // Update counters
        lastEventTimes.put(eventType, timestamp);
        sessionEventCount++;
        eventCounts.put(eventType, eventCounts.getOrDefault(eventType, 0) + 1);

        // Analyze for anomalies
        analyzeTimingAnomaly(event);

        Log.d(TAG, String.format("Event: %s, Code: %d, Duration: %dms",
            eventType, eventCode, duration));

        return duration;
    }

    /**
     * Analyze timing event for anomalies
     */
    private void analyzeTimingAnomaly(TimingEvent event) {
        // Check for suspiciously fast authentication
        if (event.eventType.equals("auth_success") &&
            event.duration < MIN_REALISTIC_AUTH_TIME) {

            suspiciousTimings++;
            event.addAnomaly("SUSPICIOUSLY_FAST_AUTH");

            Log.w(TAG, String.format("⚠️ ANOMALY: Auth too fast (%dms < %dms)",
                event.duration, MIN_REALISTIC_AUTH_TIME));
        }

        // Check for suspiciously slow authentication
        if (event.eventType.equals("auth_success") &&
            event.duration > MAX_REALISTIC_AUTH_TIME) {

            suspiciousTimings++;
            event.addAnomaly("SUSPICIOUSLY_SLOW_AUTH");

            Log.w(TAG, String.format("⚠️ ANOMALY: Auth too slow (%dms > %dms)",
                event.duration, MAX_REALISTIC_AUTH_TIME));
        }

        // Check for rapid retries (bypass attempt pattern)
        if (event.duration < RAPID_RETRY_THRESHOLD && sessionEventCount > 1) {
            rapidRetries++;
            event.addAnomaly("RAPID_RETRY");

            Log.w(TAG, String.format("⚠️ ANOMALY: Rapid retry detected (%dms)",
                event.duration));
        }

        // Check for instant success after error (suspicious pattern)
        if (event.eventType.equals("auth_success")) {
            TimingEvent previousEvent = getPreviousEvent();
            if (previousEvent != null &&
                previousEvent.eventType.equals("auth_error") &&
                (event.timestamp - previousEvent.timestamp) < MIN_REALISTIC_AUTH_TIME) {

                suspiciousTimings++;
                event.addAnomaly("INSTANT_SUCCESS_AFTER_ERROR");

                Log.w(TAG, "⚠️ ANOMALY: Instant success after error");
            }
        }

        // Check for zero-duration events (hooking/patching indicator)
        if (event.duration == 0 && sessionEventCount > 1) {
            event.addAnomaly("ZERO_DURATION_EVENT");
            Log.w(TAG, "⚠️ ANOMALY: Zero-duration event detected");
        }
    }

    /**
     * Get timing statistics
     */
    public Map<String, Object> getStats() {
        Map<String, Object> stats = new HashMap<>();
        stats.put("totalSessions", totalSessions);
        stats.put("totalEvents", eventHistory.size());
        stats.put("suspiciousTimings", suspiciousTimings);
        stats.put("rapidRetries", rapidRetries);
        stats.put("currentSessionId", currentSessionId);
        stats.put("sessionEventCount", sessionEventCount);
        stats.put("eventCounts", new HashMap<>(eventCounts));

        // Calculate average durations
        Map<String, Long> avgDurations = new HashMap<>();
        Map<String, Integer> counts = new HashMap<>();

        for (TimingEvent event : eventHistory) {
            long sum = avgDurations.getOrDefault(event.eventType, 0L);
            int count = counts.getOrDefault(event.eventType, 0);
            avgDurations.put(event.eventType, sum + event.duration);
            counts.put(event.eventType, count + 1);
        }

        Map<String, Long> averages = new HashMap<>();
        for (String type : avgDurations.keySet()) {
            averages.put(type, avgDurations.get(type) / counts.get(type));
        }
        stats.put("averageDurations", averages);

        return stats;
    }

    /**
     * Get all timing events
     */
    public List<TimingEvent> getAllEvents() {
        return new ArrayList<>(eventHistory);
    }

    /**
     * Get events for current session
     */
    public List<TimingEvent> getSessionEvents() {
        List<TimingEvent> sessionEvents = new ArrayList<>();
        for (TimingEvent event : eventHistory) {
            if (event.sessionId != null && event.sessionId.equals(currentSessionId)) {
                sessionEvents.add(event);
            }
        }
        return sessionEvents;
    }

    /**
     * Get previous event
     */
    private TimingEvent getPreviousEvent() {
        if (eventHistory.size() < 2) return null;
        return eventHistory.get(eventHistory.size() - 2);
    }

    /**
     * Get event count
     */
    public int getEventCount() {
        return eventHistory.size();
    }

    /**
     * Get session count
     */
    public int getSessionCount() {
        return totalSessions;
    }

    /**
     * Check if current session has anomalies
     */
    public boolean hasSessionAnomalies() {
        List<TimingEvent> sessionEvents = getSessionEvents();
        for (TimingEvent event : sessionEvents) {
            if (event.hasAnomalies()) {
                return true;
            }
        }
        return false;
    }

    /**
     * Get session anomaly report
     */
    public Map<String, Object> getSessionAnomalyReport() {
        Map<String, Object> report = new HashMap<>();
        List<TimingEvent> sessionEvents = getSessionEvents();

        int anomalyCount = 0;
        List<String> anomalies = new ArrayList<>();

        for (TimingEvent event : sessionEvents) {
            if (event.hasAnomalies()) {
                anomalyCount++;
                anomalies.addAll(event.anomalies);
            }
        }

        report.put("sessionId", currentSessionId);
        report.put("eventCount", sessionEvents.size());
        report.put("anomalyCount", anomalyCount);
        report.put("anomalies", anomalies);
        report.put("hasAnomalies", anomalyCount > 0);

        return report;
    }

    /**
     * Clear all timing data
     */
    public void clear() {
        lastEventTimes.clear();
        eventHistory.clear();
        eventCounts.clear();
        currentSessionId = null;
        sessionStartTime = 0;
        sessionEventCount = 0;
        totalSessions = 0;
        suspiciousTimings = 0;
        rapidRetries = 0;
        Log.d(TAG, "TimingTracker cleared");
    }

    /**
     * TimingEvent - Represents a single timing event
     */
    public static class TimingEvent {
        public final String eventType;
        public final int eventCode;
        public final long timestamp;
        public final long duration;
        public final String sessionId;
        public final List<String> anomalies;

        public TimingEvent(String eventType, int eventCode, long timestamp,
                          long duration, String sessionId) {
            this.eventType = eventType;
            this.eventCode = eventCode;
            this.timestamp = timestamp;
            this.duration = duration;
            this.sessionId = sessionId;
            this.anomalies = new ArrayList<>();
        }

        public void addAnomaly(String anomaly) {
            anomalies.add(anomaly);
        }

        public boolean hasAnomalies() {
            return !anomalies.isEmpty();
        }

        public Map<String, Object> toMap() {
            Map<String, Object> map = new HashMap<>();
            map.put("eventType", eventType);
            map.put("eventCode", eventCode);
            map.put("timestamp", timestamp);
            map.put("duration", duration);
            map.put("sessionId", sessionId);
            map.put("anomalies", new ArrayList<>(anomalies));
            map.put("hasAnomalies", hasAnomalies());
            return map;
        }

        @Override
        public String toString() {
            return String.format("TimingEvent{type=%s, code=%d, duration=%dms, anomalies=%s}",
                eventType, eventCode, duration, anomalies);
        }
    }
}
