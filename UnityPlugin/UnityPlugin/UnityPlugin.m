/*
 * UnityPlugin.m
 *
 * for pre-Unity5 compatibility, you have to make a 32-bit bundle (or a universal bundle), so
 * compile with -fno-objc-arc (or turn the Build Settings / Use Objective-C ARC to "No")
 *
 * use -fvisibility=hidden to ensure that only the functions you intentionally mark with the
 * EXPORT #define will have visibility
 *
 * initializer/finalizer are not required but optional but most real plugins will use these
 * to initialize other libraries or data structures when the bundle is loaded and unloaded.
 * these are called by the system and not by Unity, so you can't assume these are called on
 * the main Unity thread (though in practice I've always found that you are).
 *
 * note that
 */
#import <Foundation/Foundation.h>
#include "UnityPlugin.h"

#define EXPORT __attribute__((visibility("default")))

NSMutableDictionary *_recurring_callbacks;
NSTimer *_recurring_timer;

 __attribute__((constructor))
static void initializer(void)
{
  NSLog(@"UnityPlugin: initializer");
  _recurring_callbacks = [[NSMutableDictionary alloc] initWithCapacity:5];
  // establish any other global resources here
}

 __attribute__((destructor))
static void finalizer(void)
{
  NSLog(@"UnityPlugin: finalizer");
  [_recurring_callbacks release];
  _recurring_callbacks = nil;
  [_recurring_timer release];
  _recurring_timer = nil;
  // free up any other global resources here
}

@interface RecurringInvocation : NSObject
+ (void)invocation;
@end

@implementation RecurringInvocation

+ (void)start {
  if (!_recurring_timer) {
    _recurring_timer = [[NSTimer scheduledTimerWithTimeInterval:2.0
                                                         target:[RecurringInvocation class]
                                                       selector:@selector(invocation)
                                                       userInfo:nil
                                                        repeats:false] retain];
  }
}

+ (void)invocation {
  NSLog(@"UnityPlugin: recurring invocation loop");
  for (id key in _recurring_callbacks) {
    void (^block)() = [_recurring_callbacks objectForKey:key];
    if (block) {
      NSLog(@"UnityPlugin: block is %@", block);
      block();
    }
  }
  if (_recurring_callbacks && _recurring_callbacks.count > 0) {
    _recurring_timer = [[NSTimer scheduledTimerWithTimeInterval:2.0
                                                         target:[RecurringInvocation class]
                                                       selector:@selector(invocation)
                                                       userInfo:nil
                                                        repeats:false] retain];
  } else {
    [_recurring_timer release];
    _recurring_timer = nil;
  }
}
@end

// reply_during_call calls back a C# delegate during the call itself, it does not attempt
// to call the callback/delegate past the function call. this means the object lifetime is
// being safely held by the caller's marshaling layer and won't disappear
// (be garbage collected), so it's quite simple to pass just a new'd delegate
 EXPORT
void reply_during_call(SIMPLE_CALLBACK callback) {
  NSLog(@"UnityPlugin: reply_during_call (%p)", callback);
  if (callback) {
    callback();
  }
}

// set_recurring_reply calls back the C# delegate at a later time. because it uses
// the callback/delegate pointer after returning and it has no way to retain or hold
// the C# object side of the delegate, the C# caller must themselves retain the delegate
// in a private member/ivar and must clear the reply from the recurring list manually. script
// errors on the Unity side may prevent the clearing from happening, in which case
// crashes or hangs may occur. this could be somewhat mitigated by adding an additional
// entry point to clear _recurring_callbacks during Awake(), but not perfectly in the
// case of this form of timers, which is why these sorts of timed callbacks are less
// preferred to having the unity/C# side poll for complex data in Update/FixedUpdate/etc.
// see the UnityPlugin.cs side of the call for more details and gotchas.
 EXPORT
void set_recurring_reply(UInt32 hashCode, SIMPLE_CALLBACK callback)
{
  NSLog(@"UnityPlugin: set_recurring_reply(%d,%p)", (unsigned int)hashCode, callback);
  NSString *hash = [NSString stringWithFormat:@"s:%d", (unsigned int)hashCode];
  
  if (callback) {
    void (^block)() = ^{ callback(); };
    [_recurring_callbacks setObject:[block copy] forKey:hash];
    [RecurringInvocation start];
  } else {
    [_recurring_callbacks removeObjectForKey:hash];
  }
}

// poll_data returns data immediately, demonstrating how to pass raw byte buffers
// between Unity/C# and a native plugin. this example doesn't pass back object-
// specific data, but a real application would probably be keeping a map of per-
// object data that it is accumulating which it would pass back when polled.
// the difficulty of polling APIs is how the plugin knows when the poller
// has finished copying or using the data. consider if network data were coming
// in on a separate thread, updating a buffer containing data for an object:
// when polled, it can not safely just point into the network buffer to the
// object's data location, since it doesn't know when the poller will complete
// reading the data, so it might copy the data for the poller and give the poller
// an API to release the data later. in a mixed-language managed/un-managed
// environment this is probably a bad API design that will maximize
// the total number of data copies. still, it's useful to see an example of *how*
// to marshal data between Unity/C# and a native plugin, since there are few
// decent examples.
 EXPORT
void poll_data(UInt32 hashCode, void **buffer, size_t *length)
{
  NSLog(@"UnityPlugin: poll_data(%d,%p,%p)", (unsigned int)hashCode, buffer, length);
  static char *fixed_data[1024];

  if (buffer && length) {
    *buffer = fixed_data;
    *length = 16 + (arc4random() % (1024-16));
  }
}

// set_recurring_data_push calls back the C# delegate at a later time - see details of
// callback/delegate lifetime ownership rules in set_recurring_reply, above.
// unlike the simple parameter-less callback, this callback pushes bytes back into
// C#. this gives you an example of how to periodically push data from an outside source
// (say a background network queue) into Unity/C# code if you don't want to implement
// polling for data from unity into your plugin. note that data-push callbacks
// use a different key ("d:<hash>" vs "s:<hash>") in the callback dictionary to
// allow the same object to have both simple and data-push callbacks.
// the memory-management lifecycle of the data you want to give back to C# may
// influence whether you choose to push or poll for data as well - the goal for
// most real-time data flow is to minimize the number of copies going from the
// source (like the network) to the consuming application. when dealing with a
// mixed-language/managed-unmanaged environment a structure where both sides
// keep copies of relevant data and push changes to each other is not horribly
// inefficient, since they each know their data timespan/lifespan needs.
// ideal world, no data copies are happening, but that's almost impossible in
// the managed/unmanaged interop world of Unty/C#.
 EXPORT
void set_recurring_data_push(UInt32 hashCode, DATA_CALLBACK callback)
{
  NSLog(@"UnityPlugin: set_recurring_reply(%d,%p)", (unsigned int)hashCode, callback);
  NSString *hash = [NSString stringWithFormat:@"d:%d", (unsigned int)hashCode];
  
  if (callback) {
    void (^block)() = ^{
      // here we just create a 16-1024byte block of random data to push over
      // to the object. in the Real World we would probably check the status
      // of a larger data structure to see what data we have available for
      // this particular object and not bother calling it back if we don't.
      size_t length = 16 + (arc4random() % (1024-16));
      void *data = malloc(length);
      callback(data, length);
      free(data);
    };
    [_recurring_callbacks setObject:[block copy] forKey:hash];
    [RecurringInvocation start];
  } else {
    [_recurring_callbacks removeObjectForKey:hash];
  }
}
