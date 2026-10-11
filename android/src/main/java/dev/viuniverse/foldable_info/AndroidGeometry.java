package dev.viuniverse.foldable_info;

import android.graphics.Rect;
import androidx.window.layout.FoldingFeature;
import java.util.LinkedHashMap;
import java.util.Map;

/** Window pixels are translated to the engine view, then converted to logical pixels. */
final class AndroidGeometry {
  static Map<String, Object> area(FoldingFeature feature, int index,
      int offsetX, int offsetY, int width, int height, double density) {
    Rect r = feature.getBounds();
    double left = r.left - offsetX, top = r.top - offsetY;
    double right = r.right - offsetX, bottom = r.bottom - offsetY;
    // Rect.intersect treats zero-width folds as empty. Preserve those lines explicitly.
    if (right == left) {
      if (left <= 0 || left >= width || bottom <= 0 || top >= height) return null;
    } else if (bottom == top) {
      if (top <= 0 || top >= height || right <= 0 || left >= width) return null;
    } else if (right <= 0 || bottom <= 0 || left >= width || top >= height) return null;
    left = Math.max(0, left); top = Math.max(0, top);
    right = Math.min(width, right); bottom = Math.min(height, bottom);
    Map<String, Object> rect = new LinkedHashMap<>();
    rect.put("x", left / density); rect.put("y", top / density);
    rect.put("width", (right - left) / density); rect.put("height", (bottom - top) / density);
    boolean full = feature.getOcclusionType() == FoldingFeature.OcclusionType.FULL;
    Map<String, Object> result = new LinkedHashMap<>();
    result.put("id", "fold-" + index);
    result.put("rect", rect);
    result.put("cover", full ? "full" : "none");
    // FoldingFeature has no public fold-versus-hinge type getter.
    result.put("type", full ? "hinge" : "fold");
    result.put("direction", feature.getOrientation() == FoldingFeature.Orientation.VERTICAL
        ? "topToBottom" : "leftToRight");
    result.put("splitsView", feature.isSeparating());
    result.put("nativeState", feature.getState().toString());
    result.put("openState", feature.getState() == FoldingFeature.State.FLAT ? "open"
        : feature.getState() == FoldingFeature.State.HALF_OPENED ? "partlyOpen" : "unknown");
    return result;
  }
  private AndroidGeometry() {}
}
