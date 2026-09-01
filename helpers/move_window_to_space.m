// Move one macOS window to a user Space and verify the result.
//
// Hammerspoon 1.0.0's hs.spaces.moveWindowToSpace uses a compatibility-ID
// workaround which macOS 15+ accepts but ignores. macOS 26.4 added the bridged
// WindowServer operation used here. The symbols are resolved at runtime because
// SkyLight is a private framework with no public SDK headers.
// The macOS 26 invocation pattern follows yabai 7.1.25 (MIT licensed):
// https://github.com/asmvik/yabai/blob/v7.1.25/src/space_manager.c

#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>
#import <dlfcn.h>
#import <objc/message.h>
#import <objc/runtime.h>

#include <errno.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

typedef int (*SLSMainConnectionIDFn)(void);
typedef CFArrayRef (*SLSCopySpacesForWindowsFn)(int, int, CFArrayRef);
static const char *SKYLIGHT_PATH =
    "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight";

static bool parse_u32(const char *value, uint32_t *result) {
    char *end = NULL;
    errno = 0;
    unsigned long parsed = strtoul(value, &end, 10);
    if (errno != 0 || end == value || *end != '\0' || parsed == 0 || parsed > UINT32_MAX) {
        return false;
    }
    *result = (uint32_t)parsed;
    return true;
}

static bool parse_u64(const char *value, uint64_t *result) {
    char *end = NULL;
    errno = 0;
    unsigned long long parsed = strtoull(value, &end, 10);
    if (errno != 0 || end == value || *end != '\0' || parsed == 0) return false;
    *result = (uint64_t)parsed;
    return true;
}

static bool window_is_on_space(
    int connection,
    SLSCopySpacesForWindowsFn copy_spaces,
    uint32_t window_id,
    uint64_t space_id
) {
    NSArray<NSNumber *> *windows = @[@(window_id)];
    CFArrayRef result = copy_spaces(connection, 0x7, (__bridge CFArrayRef)windows);
    if (!result) return false;

    bool found = [(__bridge NSArray<NSNumber *> *)result containsObject:@(space_id)];
    CFRelease(result);
    return found;
}

static uint32_t largest_window_for_bundle(NSString *bundle_id) {
    NSRunningApplication *app =
        [NSRunningApplication runningApplicationsWithBundleIdentifier:bundle_id].firstObject;
    if (!app) return 0;

    CFArrayRef raw_window_info =
        CGWindowListCopyWindowInfo(kCGWindowListOptionAll, kCGNullWindowID);
    if (!raw_window_info) return 0;

    NSArray<NSDictionary *> *window_info = CFBridgingRelease(raw_window_info);
    uint32_t best_window = 0;
    double best_area = 0;

    for (NSDictionary *entry in window_info) {
        if ([entry[(id)kCGWindowOwnerPID] intValue] != app.processIdentifier) continue;
        if ([entry[(id)kCGWindowLayer] intValue] != 0) continue;

        CGRect bounds = CGRectZero;
        NSDictionary *bounds_dictionary = entry[(id)kCGWindowBounds];
        if (!bounds_dictionary ||
            !CGRectMakeWithDictionaryRepresentation(
                (__bridge CFDictionaryRef)bounds_dictionary,
                &bounds
            )) continue;

        double area = bounds.size.width * bounds.size.height;
        if (area > best_area) {
            best_area = area;
            best_window = [entry[(id)kCGWindowNumber] unsignedIntValue];
        }
    }

    return best_window;
}

static int print_spaces(uint32_t window_id) {
    void *framework = dlopen(SKYLIGHT_PATH, RTLD_LAZY | RTLD_LOCAL);
    if (!framework) {
        fprintf(stderr, "could not load SkyLight: %s\n", dlerror());
        return 2;
    }

    SLSMainConnectionIDFn main_connection =
        (SLSMainConnectionIDFn)dlsym(framework, "SLSMainConnectionID");
    SLSCopySpacesForWindowsFn copy_spaces =
        (SLSCopySpacesForWindowsFn)dlsym(framework, "SLSCopySpacesForWindows");
    if (!main_connection || !copy_spaces) {
        fprintf(stderr, "required macOS Space query APIs are unavailable\n");
        dlclose(framework);
        return 3;
    }

    NSArray<NSNumber *> *windows = @[@(window_id)];
    CFArrayRef result = copy_spaces(
        main_connection(),
        0x7,
        (__bridge CFArrayRef)windows
    );
    if (!result) {
        fprintf(stderr, "could not query Spaces for window %u\n", window_id);
        dlclose(framework);
        return 4;
    }

    puts([[(NSArray *)CFBridgingRelease(result) description] UTF8String]);
    dlclose(framework);
    return 0;
}

static int run_probe(void) {
    void *framework = dlopen(SKYLIGHT_PATH, RTLD_LAZY | RTLD_LOCAL);
    if (!framework) {
        fprintf(stderr, "could not load SkyLight: %s\n", dlerror());
        return 2;
    }

    Class operation_class = objc_getClass("SLSBridgedMoveWindowsToManagedSpaceOperation");
    SEL perform_selector = sel_registerName("performWithWMBridgeDelegate");
    bool available = operation_class && [operation_class instancesRespondToSelector:perform_selector];
    dlclose(framework);

    if (!available) {
        fprintf(stderr, "macOS bridged window-to-Space operation is unavailable\n");
        return 3;
    }

    puts("bridged window-to-Space operation is available");
    return 0;
}

static int move_window(uint32_t window_id, uint64_t space_id) {
    void *framework = dlopen(SKYLIGHT_PATH, RTLD_LAZY | RTLD_LOCAL);
    if (!framework) {
        fprintf(stderr, "could not load SkyLight: %s\n", dlerror());
        return 2;
    }

    SLSMainConnectionIDFn main_connection =
        (SLSMainConnectionIDFn)dlsym(framework, "SLSMainConnectionID");
    SLSCopySpacesForWindowsFn copy_spaces =
        (SLSCopySpacesForWindowsFn)dlsym(framework, "SLSCopySpacesForWindows");
    Class operation_class = objc_getClass("SLSBridgedMoveWindowsToManagedSpaceOperation");
    SEL perform_selector = sel_registerName("performWithWMBridgeDelegate");

    if (!main_connection || !copy_spaces || !operation_class ||
        ![operation_class instancesRespondToSelector:perform_selector]) {
        fprintf(stderr, "required macOS window-to-Space APIs are unavailable\n");
        dlclose(framework);
        return 3;
    }

    int connection = main_connection();
    if (window_is_on_space(connection, copy_spaces, window_id, space_id)) {
        dlclose(framework);
        return 0;
    }

    NSArray<NSNumber *> *windows = @[@(window_id)];
    SEL alloc_selector = sel_registerName("alloc");
    SEL init_selector = sel_registerName("initWithWindows:spaceID:");
    id allocated = ((id (*)(id, SEL))objc_msgSend)((id)operation_class, alloc_selector);
    id operation = ((id (*)(id, SEL, id, uint64_t))objc_msgSend)(
        allocated,
        init_selector,
        windows,
        space_id
    );

    if (!operation) {
        fprintf(stderr, "could not create the macOS window-to-Space operation\n");
        dlclose(framework);
        return 4;
    }

    ((void (*)(id, SEL))objc_msgSend)(operation, perform_selector);

    // The operation is asynchronous. Do not report success until WindowServer
    // confirms that the window is actually attached to the requested Space.
    for (int attempt = 0; attempt < 40; attempt++) {
        if (window_is_on_space(connection, copy_spaces, window_id, space_id)) {
            printf("window %u moved to Space %" PRIu64 "\n", window_id, space_id);
            dlclose(framework);
            return 0;
        }
        usleep(100000);
    }

    fprintf(
        stderr,
        "WindowServer did not attach window %u to Space %" PRIu64 "\n",
        window_id,
        space_id
    );
    dlclose(framework);
    return 5;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc == 2 && strcmp(argv[1], "--probe") == 0) return run_probe();

        if (argc == 3 && strcmp(argv[1], "--find-bundle") == 0) {
            uint32_t window_id = largest_window_for_bundle(
                [NSString stringWithUTF8String:argv[2]]
            );
            if (!window_id) {
                fprintf(stderr, "no standard-sized window found for bundle %s\n", argv[2]);
                return 1;
            }
            printf("%u\n", window_id);
            return 0;
        }

        if (argc == 3 && strcmp(argv[1], "--spaces") == 0) {
            uint32_t window_id = 0;
            if (!parse_u32(argv[2], &window_id)) {
                fprintf(stderr, "window ID must be a positive integer\n");
                return 64;
            }
            return print_spaces(window_id);
        }

        if (argc != 3) {
            fprintf(stderr, "usage: %s WINDOW_ID SPACE_ID\n", argv[0]);
            return 64;
        }

        uint32_t window_id = 0;
        uint64_t space_id = 0;
        if (!parse_u32(argv[1], &window_id) || !parse_u64(argv[2], &space_id)) {
            fprintf(stderr, "window and Space IDs must be positive integers\n");
            return 64;
        }

        return move_window(window_id, space_id);
    }
}
