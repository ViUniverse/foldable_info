package dev.viuniverse.foldable_info;

import android.graphics.Rect;
import androidx.window.layout.FoldingFeature;
import org.junit.Test;
import java.util.Map;
import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

public class AndroidGeometryTest {
  private FoldingFeature fold(int l, int t, int r, int b, boolean full, boolean half) {
    Rect rect = mock(Rect.class); rect.left = l; rect.top = t; rect.right = r; rect.bottom = b;
    FoldingFeature f = mock(FoldingFeature.class);
    when(f.getBounds()).thenReturn(rect);
    when(f.getOrientation()).thenReturn(FoldingFeature.Orientation.VERTICAL);
    when(f.getOcclusionType()).thenReturn(full ? FoldingFeature.OcclusionType.FULL : FoldingFeature.OcclusionType.NONE);
    when(f.getState()).thenReturn(half ? FoldingFeature.State.HALF_OPENED : FoldingFeature.State.FLAT);
    when(f.isSeparating()).thenReturn(full || half);
    return f;
  }
  @SuppressWarnings("unchecked") private Map<String, Object> rect(Map<String, Object> area) {
    return (Map<String, Object>) area.get("rect");
  }
  @Test public void zeroWidthLineSurvivesWindowOffsetAndDensity() {
    Map<String, Object> a = AndroidGeometry.area(fold(300, 20, 300, 820, false, true), 0, 100, 20, 600, 800, 2);
    assertEquals(100.0, rect(a).get("x")); assertEquals(0.0, rect(a).get("width"));
    assertEquals(400.0, rect(a).get("height")); assertEquals("partlyOpen", a.get("openState"));
    assertEquals(true, a.get("splitsView")); assertEquals("none", a.get("cover"));
  }
  @Test public void occludingGapIsClippedToEngineView() {
    Map<String, Object> a = AndroidGeometry.area(fold(90, 0, 140, 1000, true, false), 1, 100, 20, 600, 800, 2);
    assertEquals(0.0, rect(a).get("x")); assertEquals(20.0, rect(a).get("width"));
    assertEquals("hinge", a.get("type")); assertEquals("full", a.get("cover"));
    assertEquals("open", a.get("openState"));
  }
  @Test public void featuresOutsideViewAndOnItsBoundaryAreExcluded() {
    assertNull(AndroidGeometry.area(fold(100, 0, 100, 800, false, true), 0, 100, 0, 600, 800, 1));
    assertNull(AndroidGeometry.area(fold(900, 0, 920, 800, true, false), 0, 100, 0, 600, 800, 1));
  }
  @Test public void horizontalFoldUsesItsNativeOrientation() {
    FoldingFeature f = fold(0, 420, 600, 420, false, false);
    when(f.getOrientation()).thenReturn(FoldingFeature.Orientation.HORIZONTAL);
    Map<String, Object> a = AndroidGeometry.area(f, 0, 0, 20, 600, 800, 2);
    assertEquals(200.0, rect(a).get("y")); assertEquals(0.0, rect(a).get("height"));
    assertEquals("leftToRight", a.get("direction")); assertEquals(false, a.get("splitsView"));
  }
}
