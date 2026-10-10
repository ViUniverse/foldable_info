#import "FoldableInfoPlugin.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

// New public UIKit APIs are looked up by their public Objective-C selectors.
// No iOS 27 type is referenced by the compiler. Struct getters use KVC boxes.
static id FIObject(id object, NSString *name) {
  SEL selector = NSSelectorFromString(name);
  return [object respondsToSelector:selector] ? ((id (*)(id, SEL))objc_msgSend)(object, selector) : nil;
}
static NSInteger FIInteger(id object, NSString *name) {
  SEL selector = NSSelectorFromString(name);
  return [object respondsToSelector:selector] ? ((NSInteger (*)(id, SEL))objc_msgSend)(object, selector) : 0;
}
static NSDictionary *FIRect(CGRect r) {
  return @{ @"x": @(r.origin.x), @"y": @(r.origin.y), @"width": @(r.size.width), @"height": @(r.size.height) };
}
static NSDictionary *FIInsets(UIEdgeInsets e) {
  return @{ @"left": @(e.left), @"top": @(e.top), @"right": @(e.right), @"bottom": @(e.bottom) };
}
@interface FIProbe : UIView
@property(nonatomic, copy) void (^changed)(void);
@end
@implementation FIProbe
- (void)layoutSubviews { [super layoutSubviews]; if (_changed) _changed(); }
- (void)safeAreaInsetsDidChange { [super safeAreaInsetsDidChange]; [self setNeedsLayout]; }
- (void)didMoveToWindow { [super didMoveToWindow]; [self setNeedsLayout]; }
- (void)traitCollectionDidChange:(UITraitCollection *)old { [super traitCollectionDidChange:old]; [self setNeedsLayout]; }
@end

@class FoldableInfoPlugin;
@interface FIStream : NSObject <FlutterStreamHandler>
@property(nonatomic, weak) FoldableInfoPlugin *owner;
@property(nonatomic) BOOL angles;
@end
@interface FoldableInfoPlugin ()
@property(nonatomic, strong) NSObject<FlutterPluginRegistrar> *registrar;
@property(nonatomic, strong) FIProbe *probe;
@property(nonatomic, strong) id interaction;
@property(nonatomic, strong) id hinge;
@property(nonatomic) BOOL hingeRead;
@property(nonatomic, copy) NSString *session;
@property(nonatomic) NSInteger revision;
@property(nonatomic) NSInteger sequence;
@property(nonatomic) NSInteger epoch;
@property(nonatomic) NSInteger reads;
@property(nonatomic, strong) NSTimer *attachTimer;
@property(nonatomic) NSTimeInterval attachDeadline;
@property(nonatomic, strong) NSMapTable *ids;
@property(nonatomic, copy) FlutterEventSink layoutSink;
@property(nonatomic, copy) FlutterEventSink angleSink;
@property(nonatomic, strong) NSDictionary *lastLayout;
@property(nonatomic, strong) NSDictionary *lastAngle;
@property(nonatomic, strong) FIStream *layoutHandler;
@property(nonatomic, strong) FIStream *angleHandler;
- (FlutterError *)listen:(BOOL)angles args:(id)args sink:(FlutterEventSink)sink;
- (void)cancel:(BOOL)angles;
@end
@implementation FIStream
- (FlutterError *)onListenWithArguments:(id)args eventSink:(FlutterEventSink)sink { return [_owner listen:_angles args:args sink:sink]; }
- (FlutterError *)onCancelWithArguments:(id)args { [_owner cancel:_angles]; return nil; }
@end
@implementation FoldableInfoPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FoldableInfoPlugin *p = [FoldableInfoPlugin new]; p.registrar = registrar;
  FlutterMethodChannel *methods = [FlutterMethodChannel methodChannelWithName:@"foldable_info/methods" binaryMessenger:registrar.messenger];
  [registrar addMethodCallDelegate:p channel:methods];
  p.layoutHandler = [FIStream new]; p.layoutHandler.owner = p;
  p.angleHandler = [FIStream new]; p.angleHandler.owner = p; p.angleHandler.angles = YES;
  [[FlutterEventChannel eventChannelWithName:@"foldable_info/layout" binaryMessenger:registrar.messenger] setStreamHandler:p.layoutHandler];
  [[FlutterEventChannel eventChannelWithName:@"foldable_info/angles" binaryMessenger:registrar.messenger] setStreamHandler:p.angleHandler];
  [registrar publish:p];
  [NSNotificationCenter.defaultCenter addObserver:p selector:@selector(lifecycle:) name:UIApplicationDidEnterBackgroundNotification object:nil];
  [NSNotificationCenter.defaultCenter addObserver:p selector:@selector(lifecycle:) name:UIApplicationDidBecomeActiveNotification object:nil];
}
- (void)detachFromEngineForRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  _layoutSink = nil; _angleSink = nil; _reads = 0; [self cleanup];
  [NSNotificationCenter.defaultCenter removeObserver:self];
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (BOOL)validArgs:(id)args { return [args isKindOfClass:NSDictionary.class] && [args[@"viewId"] isKindOfClass:NSNumber.class] && [args[@"viewId"] integerValue] == 0; }
- (FlutterError *)noView { return [FlutterError errorWithCode:@"noView" message:@"This engine exposes only its registrar view (Flutter view 0)." details:nil]; }
- (FlutterError *)listen:(BOOL)angles args:(id)args sink:(FlutterEventSink)sink {
  if (![self validArgs:args]) return [self noView];
  if (angles) { self.angleSink = sink; self.lastAngle = nil; } else { self.layoutSink = sink; self.lastLayout = nil; }
  [self attach]; [self publish]; return nil;
}
- (void)cancel:(BOOL)angles {
  if (angles) { self.angleSink = nil; self.lastAngle = nil; } else { self.layoutSink = nil; self.lastLayout = nil; }
  [self cleanup];
}
- (void)lifecycle:(NSNotification *)note {
  if (_interaction && [_interaction respondsToSelector:NSSelectorFromString(@"setEnabled:")]) {
    ((void (*)(id, SEL, BOOL))objc_msgSend)(_interaction, NSSelectorFromString(@"setEnabled:"), ![note.name isEqual:UIApplicationDidEnterBackgroundNotification]);
  }
  if (_layoutSink || _angleSink || _reads) { [self attach]; [self publish]; [_probe setNeedsLayout]; }
}
- (void)attach {
  UIView *host = self.registrar.viewController.view;
  if (_probe && _probe.superview == host) return;
  if (_probe) {
    _probe.changed = nil; if (_interaction) [_probe removeInteraction:_interaction];
    [_probe removeFromSuperview]; self.probe = nil; self.interaction = nil;
  }
  if (!host.window) {
    if (!self.attachTimer && (self.layoutSink || self.angleSink || self.reads)) {
      self.attachDeadline = NSDate.timeIntervalSinceReferenceDate + 5;
      __weak FoldableInfoPlugin *weak = self;
      self.attachTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 repeats:YES block:^(NSTimer *timer) {
        FoldableInfoPlugin *p = weak;
        if (!p || NSDate.timeIntervalSinceReferenceDate >= p.attachDeadline) {
          [timer invalidate]; p.attachTimer = nil;
          FlutterError *error = [p noView]; if (p.layoutSink) p.layoutSink(error); if (p.angleSink) p.angleSink(error);
          return;
        }
        [p attach]; [p publish];
      }];
    }
    return;
  }
  [self.attachTimer invalidate]; self.attachTimer = nil;
  self.session = NSUUID.UUID.UUIDString; self.epoch++; self.revision = 0; self.sequence = 0;
  self.ids = [NSMapTable strongToStrongObjectsMapTable]; self.hinge = nil; self.hingeRead = NO;
  FIProbe *probe = [[FIProbe alloc] initWithFrame:host.bounds];
  probe.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  probe.userInteractionEnabled = NO; probe.accessibilityElementsHidden = YES;
  __weak FoldableInfoPlugin *weak = self;
  probe.changed = ^{ [weak publish]; };
  self.probe = probe; [host insertSubview:probe atIndex:0];
  Class interactionClass = NSClassFromString(@"UIHingeInteraction");
  SEL init = NSSelectorFromString(@"initWithUpdateHandler:");
  if (interactionClass && class_conformsToProtocol(interactionClass, @protocol(UIInteraction)) && [interactionClass instancesRespondToSelector:init]) {
    NSInteger epoch = _epoch;
    id handler = ^(id interaction, id update) {
      FoldableInfoPlugin *p = weak; if (!p || p.epoch != epoch) return;
      p.hinge = FIObject(update, @"hinge"); p.hingeRead = YES;
      [p publish]; [p.probe setNeedsLayout];
    };
    self.interaction = ((id (*)(id, SEL, id))objc_msgSend)([interactionClass alloc], init, handler);
    [probe addInteraction:self.interaction];
  }
  SEL traits = NSSelectorFromString(@"systemTraitsAffectingVerticalBarEdge");
  SEL registerTraits = NSSelectorFromString(@"registerForTraitChanges:withHandler:");
  if ([UITraitCollection.class respondsToSelector:traits] && [probe respondsToSelector:registerTraits]) {
    NSArray *values = FIObject(UITraitCollection.class, @"systemTraitsAffectingVerticalBarEdge");
    id handler = ^(UIView *v, UITraitCollection *old) { [v setNeedsLayout]; };
    ((id (*)(id, SEL, id, id))objc_msgSend)(probe, registerTraits, values, handler);
  }
  [probe setNeedsLayout];
}
- (void)cleanup {
  if (_layoutSink || _angleSink || _reads) return;
  [self.attachTimer invalidate]; self.attachTimer = nil;
  self.epoch++; _probe.changed = nil;
  if (_interaction) [_probe removeInteraction:_interaction];
  [_probe removeFromSuperview]; self.probe = nil; self.interaction = nil; self.hinge = nil;
  self.ids = nil; self.lastLayout = nil; self.lastAngle = nil;
}
- (NSDictionary *)base {
  UIView *view = self.registrar.viewController.view;
  return @{ @"version": @1, @"viewId": @0, @"sessionId": _session ?: @"unattached",
            @"attached": @((BOOL)(view.window != nil)), @"paused": @((BOOL)(UIApplication.sharedApplication.applicationState == UIApplicationStateBackground)),
            @"size": @{ @"width": @(view.bounds.size.width), @"height": @(view.bounds.size.height) },
            @"geometryValid": @((BOOL)(view && CGAffineTransformIsIdentity(view.transform) && self.probe && self.probe.superview == view && self.probe.window == view.window && CGSizeEqualToSize(self.probe.bounds.size, view.bounds.size))) };
}
- (NSDictionary *)layout {
  UIView *view = self.probe ?: self.registrar.viewController.view;
  NSMutableDictionary *data = [[self base] mutableCopy]; NSMutableArray *areas = [NSMutableArray new];
  SEL query = NSSelectorFromString(@"reservedRegionsOfKind:options:");
  Class kindClass = NSClassFromString(@"UIViewReservedRegionKind");
  BOOL supported = kindClass && [view respondsToSelector:query];
  if (supported) {
    for (NSString *label in @[@"occlusion", @"division"]) {
      id kind = FIObject(kindClass, [label isEqual:@"division"] ? @"divisionRegionKind" : @"occlusionRegionKind");
      if (!kind) continue;
      NSArray *values = ((id (*)(id, SEL, id, NSUInteger))objc_msgSend)(view, query, kind, 1);
      for (id region in values) {
        id identifier = FIObject(region, @"identifier"); NSString *key = identifier ? [_ids objectForKey:identifier] : nil;
        if (!key && identifier) { key = NSUUID.UUID.UUIDString; [_ids setObject:key forKey:identifier]; }
        NSValue *frame = [region valueForKey:@"frame"]; NSValue *margins = [region valueForKey:@"margins"];
        CGRect r = frame.CGRectValue; r.origin.x -= view.bounds.origin.x; r.origin.y -= view.bounds.origin.y;
        [areas addObject:@{ @"id": key ?: NSNull.null, @"nativeType": label, @"rect": FIRect(r), @"extraSpace": FIInsets(margins.UIEdgeInsetsValue), @"active": @((BOOL)(FIInteger(region, @"isActive") != 0)) }];
      }
    }
  }
  data[@"regionsSupported"] = @(supported); data[@"areas"] = areas;
  data[@"hingeSupported"] = @((BOOL)(_interaction != nil)); data[@"hingeRead"] = @(_hingeRead);
  data[@"hingeState"] = _hinge ? @(FIInteger(_hinge, @"status")) : NSNull.null;
  data[@"ios"] = @{ @"widthClass": @(view.traitCollection.horizontalSizeClass), @"heightClass": @(view.traitCollection.verticalSizeClass),
    @"barSupported": @([view.traitCollection respondsToSelector:NSSelectorFromString(@"verticalBarEdge")]), @"barSide": @(FIInteger(view.traitCollection, @"verticalBarEdge")), @"safeArea": FIInsets(view.safeAreaInsets) };
  return data;
}
- (NSDictionary *)angles {
  NSMutableDictionary *data = [[self base] mutableCopy];
  NSString *state = !_interaction ? @"notSupported" : (_hinge ? @"ready" : (_hingeRead ? @"notAvailable" : @"loading"));
  data[@"state"] = state;
  if (_hinge && [_hinge respondsToSelector:NSSelectorFromString(@"angle")]) {
    double radians = ((CGFloat (*)(id, SEL))objc_msgSend)(_hinge, NSSelectorFromString(@"angle"));
    data[@"degrees"] = @(radians * 180.0 / M_PI);
  }
  return data;
}
- (void)publish {
  if (_layoutSink) {
    NSDictionary *value = [self layout];
    if (![value isEqual:_lastLayout]) {
      self.lastLayout = value; NSMutableDictionary *event = [value mutableCopy]; event[@"revision"] = @(++_revision);
      FlutterEventSink sink = _layoutSink; NSInteger epoch = _epoch;
      dispatch_async(dispatch_get_main_queue(), ^{ if (self.epoch == epoch && self.layoutSink == sink) sink(event); });
    }
  }
  if (_angleSink) {
    NSDictionary *value = [self angles];
    if (![value isEqual:_lastAngle]) {
      self.lastAngle = value; NSMutableDictionary *event = [value mutableCopy]; event[@"sequence"] = @(++_sequence);
      FlutterEventSink sink = _angleSink; NSInteger epoch = _epoch;
      dispatch_async(dispatch_get_main_queue(), ^{ if (self.epoch == epoch && self.angleSink == sink) sink(event); });
    }
  }
}
- (void)finishRead:(BOOL)angles epoch:(NSInteger)epoch deadline:(NSTimeInterval)deadline result:(FlutterResult)result {
  if ((epoch && epoch != self.epoch) || !self.reads) {
    self.reads = MAX(0, self.reads - 1); result([self noView]); [self cleanup]; return;
  }
  [self attach];
  BOOL pending = angles && (!self.probe || (self.interaction && !self.hingeRead));
  if (pending && NSDate.timeIntervalSinceReferenceDate < deadline) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.02 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      [self finishRead:angles epoch:epoch deadline:deadline result:result];
    });
    return;
  }
  if (pending) {
    result([FlutterError errorWithCode:@"timeout" message:@"No hinge observation arrived before the timeout." details:nil]);
  } else {
    NSMutableDictionary *value = [(angles ? [self angles] : [self layout]) mutableCopy];
    value[angles ? @"sequence" : @"revision"] = @(angles ? self.sequence : self.revision); result(value);
  }
  self.reads = MAX(0, self.reads - 1); [self cleanup];
}
- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  if (![@[@"read", @"readAngles"] containsObject:call.method]) { result(FlutterMethodNotImplemented); return; }
  if (![self validArgs:call.arguments]) { result([self noView]); return; }
  self.reads++; [self attach];
  NSInteger epoch = _probe ? _epoch : 0; BOOL angles = [call.method isEqual:@"readAngles"];
  NSNumber *milliseconds = call.arguments[@"timeoutMillis"];
  NSTimeInterval wait = [milliseconds isKindOfClass:NSNumber.class] ? MAX(0.001, MIN(300, milliseconds.doubleValue / 1000.0)) : 5;
  NSTimeInterval deadline = NSDate.timeIntervalSinceReferenceDate + wait;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.02 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [self finishRead:angles epoch:epoch deadline:deadline result:result];
  });
}
@end
