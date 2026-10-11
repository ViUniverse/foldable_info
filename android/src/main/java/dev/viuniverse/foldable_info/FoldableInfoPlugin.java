package dev.viuniverse.foldable_info;

import android.app.Activity;
import android.app.Application;
import android.content.Context;
import android.graphics.Rect;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.view.ViewGroup;
import androidx.core.util.Consumer;
import androidx.window.java.layout.WindowInfoTrackerCallbackAdapter;
import androidx.window.layout.DisplayFeature;
import androidx.window.layout.FoldingFeature;
import androidx.window.layout.WindowInfoTracker;
import androidx.window.layout.WindowLayoutInfo;
import androidx.window.layout.WindowMetricsCalculator;
import io.flutter.embedding.android.FlutterView;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/** Engine-local, demand-driven observations. No activity or sensor survives detachment. */
public final class FoldableInfoPlugin implements FlutterPlugin, ActivityAware,
    MethodChannel.MethodCallHandler, Application.ActivityLifecycleCallbacks, SensorEventListener {
  private final Handler main = new Handler(Looper.getMainLooper());
  private FlutterEngine engine;
  private Application application;
  private Activity activity;
  private MethodChannel methods;
  private EventChannel layouts, angles;
  private EventChannel.EventSink layoutSink, angleSink;
  private final List<Read> layoutReads = new ArrayList<>(), angleReads = new ArrayList<>();
  private WindowInfoTrackerCallbackAdapter tracker;
  private Consumer<WindowLayoutInfo> windowListener;
  private WindowLayoutInfo windowInfo;
  private View decor;
  private Rect measuredWindow;
  private int windowEpoch;
  private SensorManager sensors;
  private Sensor hinge;
  private boolean sensorOn, stopped;
  private int sensorEpoch;
  private SensorEventListener sensorListener;
  private String angleState = "loading", session;
  private Double degrees;
  private long revision, sequence;
  private final android.view.ViewTreeObserver.OnGlobalLayoutListener globalLayout = () -> {
    if (windowInfo != null && !windowBounds().equals(measuredWindow)) {
      stopWindow();
      updateDemand();
    }
    emitLayout();
  };

  @Override public void onAttachedToEngine(FlutterPluginBinding binding) {
    engine = binding.getFlutterEngine();
    application = (Application) binding.getApplicationContext();
    sensors = (SensorManager) application.getSystemService(Context.SENSOR_SERVICE);
    if (Build.VERSION.SDK_INT >= 30 && sensors != null) {
      hinge = sensors.getDefaultSensor(Sensor.TYPE_HINGE_ANGLE);
    }
    application.registerActivityLifecycleCallbacks(this);
    methods = new MethodChannel(binding.getBinaryMessenger(), "foldable_info/methods");
    layouts = new EventChannel(binding.getBinaryMessenger(), "foldable_info/layout");
    angles = new EventChannel(binding.getBinaryMessenger(), "foldable_info/angles");
    methods.setMethodCallHandler(this);
    layouts.setStreamHandler(stream(false));
    angles.setStreamHandler(stream(true));
  }

  private EventChannel.StreamHandler stream(boolean angle) {
    return new EventChannel.StreamHandler() {
      @Override public void onListen(Object arguments, EventChannel.EventSink sink) {
        if (!validView(arguments)) {
          sink.error("noView", "Only this engine's Flutter view 0 is supported.", null);
          return;
        }
        beginSession();
        if (angle) angleSink = sink; else layoutSink = sink;
        updateDemand();
        if (angle) emitAngles(); else emitLayout();
      }
      @Override public void onCancel(Object arguments) {
        if (angle) angleSink = null; else layoutSink = null;
        updateDemand();
      }
    };
  }

  private boolean validView(Object arguments) {
    if (!(arguments instanceof Map)) return false;
    Object id = ((Map<?, ?>) arguments).get("viewId");
    return id instanceof Number && ((Number) id).longValue() == 0;
  }

  @Override public void onMethodCall(MethodCall call, MethodChannel.Result result) {
    if (!call.method.equals("read") && !call.method.equals("readAngles")) {
      result.notImplemented(); return;
    }
    if (!validView(call.arguments) || activity == null) {
      result.error("noView", "No attached Activity for this engine's Flutter view 0.", null);
      return;
    }
    beginSession();
    boolean angle = call.method.equals("readAngles");
    Read read = new Read(result, angle);
    (angle ? angleReads : layoutReads).add(read);
    Number timeout = call.argument("timeoutMillis");
    main.postDelayed(read.timeout, timeout == null ? 5000 : Math.max(1, timeout.longValue()));
    updateDemand();
    if (angle) emitAngles(); else emitLayout();
  }

  private final class Read {
    final MethodChannel.Result result;
    final boolean angle;
    final Runnable timeout;
    Read(MethodChannel.Result result, boolean angle) {
      this.result = result; this.angle = angle;
      timeout = () -> finish(null, "timeout", "No native measurement arrived before the deadline.");
    }
    void finish(Map<String, Object> data, String error, String message) {
      if (!(angle ? angleReads : layoutReads).remove(this)) return;
      main.removeCallbacks(timeout);
      if (error == null) result.success(data); else result.error(error, message, null);
      updateDemand();
    }
  }

  private void beginSession() {
    if (session != null) return;
    session = UUID.randomUUID().toString(); revision = 0; sequence = 0;
  }

  private void updateDemand() {
    boolean wantLayout = layoutSink != null || !layoutReads.isEmpty();
    boolean wantAngle = angleSink != null || !angleReads.isEmpty();
    if (activity != null && !stopped && wantLayout) startWindow(); else stopWindow();
    if (activity != null && !stopped && wantAngle) startSensor(); else stopSensor();
    if (!wantLayout && !wantAngle) session = null;
  }

  private void startWindow() {
    if (windowListener != null) return;
    final Activity owner = activity;
    final int epoch = ++windowEpoch;
    decor = owner.getWindow().getDecorView();
    decor.getViewTreeObserver().addOnGlobalLayoutListener(globalLayout);
    tracker = new WindowInfoTrackerCallbackAdapter(WindowInfoTracker.getOrCreate(owner));
    windowListener = info -> {
      if (owner != activity || epoch != windowEpoch) return;
      windowInfo = info; measuredWindow = windowBounds();
      emitLayout();
    };
    try {
      tracker.addWindowLayoutInfoListener(owner, main::post, windowListener);
    } catch (RuntimeException e) {
      if (layoutSink != null) layoutSink.error("nativeError", "Could not observe WindowManager.", null);
      for (Read r : new ArrayList<>(layoutReads)) {
        r.finish(null, "nativeError", "Could not observe WindowManager.");
      }
      stopWindow();
    }
  }

  private void stopWindow() {
    ++windowEpoch;
    if (tracker != null && windowListener != null) tracker.removeWindowLayoutInfoListener(windowListener);
    if (decor != null && decor.getViewTreeObserver().isAlive()) {
      decor.getViewTreeObserver().removeOnGlobalLayoutListener(globalLayout);
    }
    windowListener = null; tracker = null; decor = null;
    windowInfo = null; measuredWindow = null;
  }

  private void startSensor() {
    if (sensorOn || !angleState.equals("loading")) return;
    if (hinge == null) { angleState = "notSupported"; return; }
    final int epoch = ++sensorEpoch;
    sensorListener = new SensorEventListener() {
      @Override public void onSensorChanged(SensorEvent event) {
        if (epoch == sensorEpoch) FoldableInfoPlugin.this.onSensorChanged(event);
      }
      @Override public void onAccuracyChanged(Sensor sensor, int accuracy) {}
    };
    sensorOn = sensors.registerListener(sensorListener, hinge, SensorManager.SENSOR_DELAY_NORMAL, main);
    if (!sensorOn) angleState = "notAvailable";
  }
  private void stopSensor() {
    ++sensorEpoch;
    if (sensorOn) sensors.unregisterListener(sensorListener);
    sensorListener = null;
    sensorOn = false; degrees = null; angleState = "loading";
  }
  @Override public void onSensorChanged(SensorEvent event) {
    if (!sensorOn || stopped || event.sensor != hinge || event.values.length == 0) return;
    double value = event.values[0];
    if (!Double.isFinite(value) || value < 0 || value > 360) return;
    degrees = value; angleState = "ready"; emitAngles();
  }
  @Override public void onAccuracyChanged(Sensor sensor, int accuracy) {}

  private FlutterView flutterView(View root) {
    if (root instanceof FlutterView && ((FlutterView) root).getAttachedFlutterEngine() == engine) {
      return (FlutterView) root;
    }
    if (root instanceof ViewGroup) {
      ViewGroup group = (ViewGroup) root;
      for (int i = 0; i < group.getChildCount(); i++) {
        FlutterView found = flutterView(group.getChildAt(i));
        if (found != null) return found;
      }
    }
    return null;
  }
  private FlutterView flutterView() {
    return activity == null ? null : flutterView(activity.getWindow().getDecorView());
  }
  private Rect windowBounds() {
    return WindowMetricsCalculator.getOrCreate().computeCurrentWindowMetrics(activity).getBounds();
  }
  private boolean validGeometry(FlutterView view) {
    if (view == null || !view.isAttachedToWindow() || view.getWidth() <= 0 || view.getHeight() <= 0) return false;
    View node = view;
    while (true) {
      if (!node.getMatrix().isIdentity()) return false;
      if (!(node.getParent() instanceof View)) break;
      node = (View) node.getParent();
    }
    return true;
  }

  private Map<String, Object> base(boolean angle) {
    Map<String, Object> data = new LinkedHashMap<>();
    data.put("version", 1); data.put("platform", "android"); data.put("viewId", 0);
    data.put("sessionId", session); data.put(angle ? "sequence" : "revision", angle ? ++sequence : ++revision);
    data.put("attached", activity != null && flutterView() != null);
    data.put("paused", stopped);
    return data;
  }
  private Map<String, Object> layoutData() {
    Map<String, Object> data = base(false);
    FlutterView view = flutterView();
    double density = activity == null ? 1 : activity.getResources().getDisplayMetrics().density;
    Map<String, Object> size = new LinkedHashMap<>();
    size.put("width", view == null ? 0 : view.getWidth() / density);
    size.put("height", view == null ? 0 : view.getHeight() / density);
    data.put("size", size); data.put("pixelRatio", density);
    data.put("geometryValid", validGeometry(view));
    data.put("layoutRead", windowInfo != null);
    data.put("hasHingeSensor", hinge != null);
    List<Map<String, Object>> features = new ArrayList<>();
    if (windowInfo != null && validGeometry(view)) {
      int[] location = new int[2]; view.getLocationInWindow(location);
      int index = 0;
      for (DisplayFeature feature : windowInfo.getDisplayFeatures()) {
        if (!(feature instanceof FoldingFeature)) continue;
        Map<String, Object> area = AndroidGeometry.area((FoldingFeature) feature, index++,
            location[0], location[1], view.getWidth(), view.getHeight(), density);
        if (area != null) features.add(area);
      }
    }
    data.put("hasFoldFeature", windowInfo != null && windowInfo.getDisplayFeatures().stream()
        .anyMatch(feature -> feature instanceof FoldingFeature));
    data.put("features", features);
    return data;
  }
  private void emitLayout() {
    if (session == null) return;
    Map<String, Object> data = layoutData();
    if (layoutSink != null) layoutSink.success(data);
    boolean ready = stopped || (Boolean.TRUE.equals(data.get("attached"))
        && Boolean.TRUE.equals(data.get("layoutRead")) && Boolean.TRUE.equals(data.get("geometryValid")));
    if (ready) for (Read r : new ArrayList<>(layoutReads)) r.finish(data, null, null);
  }
  private void emitAngles() {
    if (session == null) return;
    Map<String, Object> data = base(true);
    String state = stopped || !Boolean.TRUE.equals(data.get("attached")) ? "notAvailable" : angleState;
    data.put("state", state);
    if (degrees != null && state.equals("ready")) data.put("degrees", degrees);
    if (angleSink != null) angleSink.success(data);
    if (!state.equals("loading")) for (Read r : new ArrayList<>(angleReads)) r.finish(data, null, null);
  }

  @Override public void onAttachedToActivity(ActivityPluginBinding binding) {
    activity = binding.getActivity(); stopped = false; session = null; beginSession();
    updateDemand(); emitLayout(); emitAngles();
    updateDemand();
  }
  private void detachActivity() {
    stopWindow(); stopSensor(); activity = null;
    for (Read r : new ArrayList<>(layoutReads)) r.finish(null, "noView", "Activity detached.");
    for (Read r : new ArrayList<>(angleReads)) r.finish(null, "noView", "Activity detached.");
    emitLayout(); emitAngles();
  }
  @Override public void onDetachedFromActivityForConfigChanges() { detachActivity(); }
  @Override public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) { onAttachedToActivity(binding); }
  @Override public void onDetachedFromActivity() { detachActivity(); }
  @Override public void onDetachedFromEngine(FlutterPluginBinding binding) {
    layoutSink = null; angleSink = null; detachActivity();
    methods.setMethodCallHandler(null); layouts.setStreamHandler(null); angles.setStreamHandler(null);
    application.unregisterActivityLifecycleCallbacks(this);
    engine = null; application = null; sensors = null; hinge = null; session = null;
  }
  @Override public void onActivityResumed(Activity value) {
    if (value != activity) return;
    stopped = false; updateDemand(); emitLayout(); emitAngles();
  }
  @Override public void onActivityStopped(Activity value) {
    if (value != activity) return;
    stopped = true; updateDemand(); emitLayout(); emitAngles();
  }
  @Override public void onActivityCreated(Activity value, Bundle state) {}
  @Override public void onActivityStarted(Activity value) {}
  @Override public void onActivityPaused(Activity value) {}
  @Override public void onActivitySaveInstanceState(Activity value, Bundle state) {}
  @Override public void onActivityDestroyed(Activity value) { if (value == activity) detachActivity(); }
}
