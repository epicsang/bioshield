package com.fyp.bioshield.bioshield;

import android.content.Context;
import android.util.Log;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * LogStore - Persists hook logs to internal app storage
 * Provides structured logging for ML analysis
 */
public class LogStore {
    private static final String TAG = "BioShield.LogStore";
    private static LogStore instance;

    private static final String LOG_DIR = "bioshield_logs";
    private static final String LOG_FILE_PREFIX = "hook_log_";
    private static final int MAX_LOG_SIZE = 1024 * 1024; // 1MB per file
    private static final int MAX_LOG_FILES = 10;

    private Context context;
    private File logDirectory;
    private File currentLogFile;
    private ConcurrentLinkedQueue<LogEntry> logQueue;
    private ExecutorService logExecutor;
    private int logCount;
    private SimpleDateFormat dateFormat;

    private LogStore(Context context) {
        this.context = context.getApplicationContext();
        this.logQueue = new ConcurrentLinkedQueue<>();
        this.logExecutor = Executors.newSingleThreadExecutor();
        this.dateFormat = new SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.US);

        initializeLogDirectory();
        Log.d(TAG, "LogStore initialized at: " + logDirectory.getAbsolutePath());
    }

    public static synchronized LogStore getInstance(Context context) {
        if (instance == null) {
            instance = new LogStore(context);
        }
        return instance;
    }

    /**
     * Initialize log directory
     */
    private void initializeLogDirectory() {
        logDirectory = new File(context.getFilesDir(), LOG_DIR);
        if (!logDirectory.exists()) {
            boolean created = logDirectory.mkdirs();
            Log.d(TAG, "Log directory created: " + created);
        }

        // Create or rotate log file
        rotateLogFileIfNeeded();
    }

    /**
     * Log an event
     */
    public void log(String category, Map<String, Object> data) {
        LogEntry entry = new LogEntry(category, data);
        logQueue.offer(entry);
        logCount++;

        // Async write
        logExecutor.execute(() -> writeLogEntry(entry));
    }

    /**
     * Log an exception
     */
    public void logException(String context, Exception exception) {
        Map<String, Object> data = new HashMap<>();
        data.put("context", context);
        data.put("exception", exception.getClass().getName());
        data.put("message", exception.getMessage());
        data.put("stackTrace", getStackTraceString(exception));

        log("EXCEPTION", data);
    }

    /**
     * Write log entry to file
     */
    private synchronized void writeLogEntry(LogEntry entry) {
        try {
            // Check if rotation needed
            rotateLogFileIfNeeded();

            // Convert to JSON
            JSONObject json = entryToJson(entry);

            // Append to file
            FileOutputStream fos = new FileOutputStream(currentLogFile, true);
            OutputStreamWriter writer = new OutputStreamWriter(fos, StandardCharsets.UTF_8);

            writer.write(json.toString());
            writer.write("\n");
            writer.flush();
            writer.close();

        } catch (Exception e) {
            Log.e(TAG, "Error writing log entry", e);
        }
    }

    /**
     * Rotate log file if needed
     */
    private void rotateLogFileIfNeeded() {
        if (currentLogFile == null || currentLogFile.length() > MAX_LOG_SIZE) {
            String timestamp = dateFormat.format(new Date());
            currentLogFile = new File(logDirectory, LOG_FILE_PREFIX + timestamp + ".jsonl");

            Log.d(TAG, "Rotating to new log file: " + currentLogFile.getName());

            // Clean up old files
            cleanupOldLogFiles();
        }
    }

    /**
     * Clean up old log files
     */
    private void cleanupOldLogFiles() {
        File[] files = logDirectory.listFiles((dir, name) ->
            name.startsWith(LOG_FILE_PREFIX) && name.endsWith(".jsonl"));

        if (files != null && files.length > MAX_LOG_FILES) {
            // Sort by last modified
            java.util.Arrays.sort(files, (a, b) ->
                Long.compare(a.lastModified(), b.lastModified()));

            // Delete oldest files
            int toDelete = files.length - MAX_LOG_FILES;
            for (int i = 0; i < toDelete; i++) {
                boolean deleted = files[i].delete();
                Log.d(TAG, "Deleted old log file: " + files[i].getName() + " = " + deleted);
            }
        }
    }

    /**
     * Read all logs
     */
    public List<LogEntry> readAllLogs() {
        List<LogEntry> logs = new ArrayList<>();

        File[] files = logDirectory.listFiles((dir, name) ->
            name.startsWith(LOG_FILE_PREFIX) && name.endsWith(".jsonl"));

        if (files != null) {
            // Sort by last modified (oldest first)
            java.util.Arrays.sort(files, (a, b) ->
                Long.compare(a.lastModified(), b.lastModified()));

            for (File file : files) {
                logs.addAll(readLogsFromFile(file));
            }
        }

        return logs;
    }

    /**
     * Read logs from specific file
     */
    private List<LogEntry> readLogsFromFile(File file) {
        List<LogEntry> logs = new ArrayList<>();

        try {
            FileInputStream fis = new FileInputStream(file);
            InputStreamReader isr = new InputStreamReader(fis, StandardCharsets.UTF_8);
            BufferedReader reader = new BufferedReader(isr);

            String line;
            while ((line = reader.readLine()) != null) {
                try {
                    JSONObject json = new JSONObject(line);
                    LogEntry entry = jsonToEntry(json);
                    logs.add(entry);
                } catch (JSONException e) {
                    Log.e(TAG, "Error parsing log line", e);
                }
            }

            reader.close();

        } catch (Exception e) {
            Log.e(TAG, "Error reading log file: " + file.getName(), e);
        }

        return logs;
    }

    /**
     * Read logs by category
     */
    public List<LogEntry> readLogsByCategory(String category) {
        List<LogEntry> allLogs = readAllLogs();
        List<LogEntry> filtered = new ArrayList<>();

        for (LogEntry entry : allLogs) {
            if (entry.category.equals(category)) {
                filtered.add(entry);
            }
        }

        return filtered;
    }

    /**
     * Export logs as JSON array
     */
    public String exportLogsAsJson() {
        List<LogEntry> logs = readAllLogs();
        JSONArray jsonArray = new JSONArray();

        for (LogEntry entry : logs) {
            try {
                jsonArray.put(entryToJson(entry));
            } catch (Exception e) {
                Log.e(TAG, "Error converting log to JSON", e);
            }
        }

        return jsonArray.toString();
    }

    /**
     * Export logs to file for ML processing
     */
    public File exportLogsForML() {
        try {
            File exportFile = new File(context.getFilesDir(), "bioshield_export.json");
            FileOutputStream fos = new FileOutputStream(exportFile);
            OutputStreamWriter writer = new OutputStreamWriter(fos, StandardCharsets.UTF_8);

            writer.write(exportLogsAsJson());
            writer.flush();
            writer.close();

            Log.d(TAG, "Logs exported to: " + exportFile.getAbsolutePath());
            return exportFile;

        } catch (Exception e) {
            Log.e(TAG, "Error exporting logs", e);
            return null;
        }
    }

    /**
     * Get log statistics
     */
    public Map<String, Object> getStats() {
        Map<String, Object> stats = new HashMap<>();
        stats.put("totalLogs", logCount);
        stats.put("queueSize", logQueue.size());
        stats.put("logDirectory", logDirectory.getAbsolutePath());
        stats.put("currentLogFile", currentLogFile != null ? currentLogFile.getName() : "none");

        // Count files
        File[] files = logDirectory.listFiles();
        stats.put("logFileCount", files != null ? files.length : 0);

        // Count by category
        Map<String, Integer> categoryCounts = new HashMap<>();
        List<LogEntry> allLogs = readAllLogs();
        for (LogEntry entry : allLogs) {
            categoryCounts.put(entry.category,
                categoryCounts.getOrDefault(entry.category, 0) + 1);
        }
        stats.put("categoryCounts", categoryCounts);

        return stats;
    }

    /**
     * Get log count
     */
    public int getLogCount() {
        return logCount;
    }

    /**
     * Get log directory
     */
    public File getLogDirectory() {
        return logDirectory;
    }

    /**
     * Clear all logs
     */
    public void clearLogs() {
        File[] files = logDirectory.listFiles();
        if (files != null) {
            for (File file : files) {
                boolean deleted = file.delete();
                Log.d(TAG, "Deleted: " + file.getName() + " = " + deleted);
            }
        }

        logQueue.clear();
        logCount = 0;
        currentLogFile = null;

        Log.d(TAG, "All logs cleared");
    }

    /**
     * Convert LogEntry to JSON
     */
    private JSONObject entryToJson(LogEntry entry) throws JSONException {
        JSONObject json = new JSONObject();
        json.put("timestamp", entry.timestamp);
        json.put("category", entry.category);

        // Convert data map to JSON
        JSONObject dataJson = new JSONObject();
        for (Map.Entry<String, Object> item : entry.data.entrySet()) {
            dataJson.put(item.getKey(), item.getValue());
        }
        json.put("data", dataJson);

        return json;
    }

    /**
     * Convert JSON to LogEntry
     */
    private LogEntry jsonToEntry(JSONObject json) throws JSONException {
        long timestamp = json.getLong("timestamp");
        String category = json.getString("category");

        Map<String, Object> data = new HashMap<>();
        JSONObject dataJson = json.getJSONObject("data");
        Iterator<String> keys = dataJson.keys();
        while (keys.hasNext()) {
            String key = keys.next();
            data.put(key, dataJson.get(key));
        }

        return new LogEntry(timestamp, category, data);
    }

    /**
     * Get stack trace as string
     */
    private String getStackTraceString(Exception e) {
        StringBuilder sb = new StringBuilder();
        for (StackTraceElement element : e.getStackTrace()) {
            sb.append(element.toString()).append("\n");
        }
        return sb.toString();
    }

    /**
     * Shutdown executor
     */
    public void shutdown() {
        logExecutor.shutdown();
        Log.d(TAG, "LogStore shut down");
    }

    /**
     * LogEntry - Represents a single log entry
     */
    public static class LogEntry {
        public final long timestamp;
        public final String category;
        public final Map<String, Object> data;

        public LogEntry(String category, Map<String, Object> data) {
            this.timestamp = System.currentTimeMillis();
            this.category = category;
            this.data = new HashMap<>(data);
        }

        public LogEntry(long timestamp, String category, Map<String, Object> data) {
            this.timestamp = timestamp;
            this.category = category;
            this.data = new HashMap<>(data);
        }

        @Override
        public String toString() {
            return String.format("LogEntry{ts=%d, category=%s, data=%s}",
                timestamp, category, data);
        }
    }
}
