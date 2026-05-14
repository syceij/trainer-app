#import <Foundation/Foundation.h>
#import <Capacitor/CAPBridgedPlugin.h>
#import <Capacitor/CAPPluginMethod.h>

CAP_PLUGIN(LiveActivityPlugin, "LiveActivityPlugin",
    CAP_PLUGIN_METHOD(start,       CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(update,      CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(end,         CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(isSupported, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(diagnostics, CAPPluginReturnPromise);
)
