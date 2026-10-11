package dev.viuniverse.foldable_info;

import android.app.Activity;
import android.app.Application;
import android.content.Context;
import android.content.res.Resources;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.os.Handler;
import android.util.DisplayMetrics;
import android.view.Window;
import io.flutter.embedding.android.FlutterView;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import org.junit.Before;
import org.junit.Test;
import org.mockito.ArgumentCaptor;
import java.lang.reflect.Field;
import java.util.Map;
import static org.junit.Assert.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

public class AndroidLifetimeTest {
  private FoldableInfoPlugin plugin;
  private SensorManager sensors;
  private Sensor sensor;
  private Activity activity;
  private Handler handler;
  private void field(Object object, String name, Object value) throws Exception {
    Class<?> type = object.getClass();
    while (type != null) {
      try { Field f = type.getDeclaredField(name); f.setAccessible(true); f.set(object, value); return; }
      catch (NoSuchFieldException e) { type = type.getSuperclass(); }
    }
    throw new NoSuchFieldException(name);
  }
  @Before public void setup() throws Exception {
    plugin = new FoldableInfoPlugin(); handler = mock(Handler.class); field(plugin, "main", handler);
    FlutterEngine engine = mock(FlutterEngine.class);
    Application application = mock(Application.class);
    sensors = mock(SensorManager.class); sensor = mock(Sensor.class);
    when(application.getSystemService(Context.SENSOR_SERVICE)).thenReturn(sensors);
    FlutterPlugin.FlutterPluginBinding binding = mock(FlutterPlugin.FlutterPluginBinding.class);
    when(binding.getApplicationContext()).thenReturn(application);
    when(binding.getFlutterEngine()).thenReturn(engine);
    when(binding.getBinaryMessenger()).thenReturn(mock(BinaryMessenger.class));
    plugin.onAttachedToEngine(binding); field(plugin, "hinge", sensor);
    activity = mock(Activity.class); Window window = mock(Window.class);
    FlutterView view = mock(FlutterView.class);
    when(activity.getWindow()).thenReturn(window); when(window.getDecorView()).thenReturn(view);
    when(view.getAttachedFlutterEngine()).thenReturn(engine);
    Resources resources = mock(Resources.class); DisplayMetrics metrics = mock(DisplayMetrics.class);
    metrics.density = 2;
    when(activity.getResources()).thenReturn(resources); when(resources.getDisplayMetrics()).thenReturn(metrics);
    ActivityPluginBinding activityBinding = mock(ActivityPluginBinding.class);
    when(activityBinding.getActivity()).thenReturn(activity);
    plugin.onAttachedToActivity(activityBinding);
    when(sensors.registerListener(any(SensorEventListener.class), eq(sensor), anyInt(), eq(handler))).thenReturn(true);
  }
  private void read(MethodChannel.Result result) {
    plugin.onMethodCall(new MethodCall("readAngles", Map.of("viewId", 0, "timeoutMillis", 100)), result);
  }
  private SensorEvent event(float angle) throws Exception {
    SensorEvent event = mock(SensorEvent.class); event.sensor = sensor;
    field(event, "values", new float[] {angle}); return event;
  }
  @Test public void stoppingActivityReleasesSensorAndRejectsLateCallbacks() throws Exception {
    MethodChannel.Result first = mock(MethodChannel.Result.class); read(first);
    ArgumentCaptor<SensorEventListener> listeners = ArgumentCaptor.forClass(SensorEventListener.class);
    verify(sensors).registerListener(listeners.capture(), eq(sensor), anyInt(), eq(handler));
    SensorEventListener old = listeners.getValue();
    plugin.onActivityStopped(activity);
    verify(sensors).unregisterListener(old);
    ArgumentCaptor<Object> paused = ArgumentCaptor.forClass(Object.class);
    verify(first).success(paused.capture());
    assertEquals("notAvailable", ((Map<?, ?>) paused.getValue()).get("state"));
    plugin.onActivityResumed(activity);
    MethodChannel.Result next = mock(MethodChannel.Result.class); read(next);
    verify(sensors, times(2)).registerListener(listeners.capture(), eq(sensor), anyInt(), eq(handler));
    old.onSensorChanged(event(10)); verify(next, never()).success(any());
    listeners.getValue().onSensorChanged(event(90));
    ArgumentCaptor<Object> data = ArgumentCaptor.forClass(Object.class); verify(next).success(data.capture());
    assertEquals(90.0, ((Map<?, ?>) data.getValue()).get("degrees"));
    verify(sensors).unregisterListener(listeners.getValue());
  }
  @Test public void nativeTimeoutReleasesOneShotSensorDemand() {
    MethodChannel.Result result = mock(MethodChannel.Result.class); read(result);
    ArgumentCaptor<Runnable> timeout = ArgumentCaptor.forClass(Runnable.class);
    verify(handler).postDelayed(timeout.capture(), eq(100L));
    timeout.getValue().run();
    verify(result).error(eq("timeout"), anyString(), isNull());
    verify(sensors).unregisterListener(any(SensorEventListener.class));
    verify(handler).removeCallbacks(timeout.getValue());
  }
  @Test public void deviceWithoutHingeSensorIsUnsupportedWithoutRegistration() throws Exception {
    field(plugin, "hinge", null);
    MethodChannel.Result result = mock(MethodChannel.Result.class); read(result);
    ArgumentCaptor<Object> data = ArgumentCaptor.forClass(Object.class); verify(result).success(data.capture());
    assertEquals("notSupported", ((Map<?, ?>) data.getValue()).get("state"));
    verify(sensors, never()).registerListener(any(SensorEventListener.class), any(Sensor.class), anyInt(), any(Handler.class));
  }
  @Test public void failedSensorRegistrationIsUnavailable() {
    when(sensors.registerListener(any(SensorEventListener.class), eq(sensor), anyInt(), eq(handler))).thenReturn(false);
    MethodChannel.Result result = mock(MethodChannel.Result.class); read(result);
    ArgumentCaptor<Object> data = ArgumentCaptor.forClass(Object.class); verify(result).success(data.capture());
    assertEquals("notAvailable", ((Map<?, ?>) data.getValue()).get("state"));
    verify(sensors, never()).unregisterListener(any(SensorEventListener.class));
  }
  @Test public void detachFailsPendingReadAndRemovesSensor() {
    MethodChannel.Result result = mock(MethodChannel.Result.class); read(result);
    plugin.onDetachedFromActivityForConfigChanges();
    verify(result).error(eq("noView"), anyString(), isNull());
    verify(sensors).unregisterListener(any(SensorEventListener.class));
  }
}
