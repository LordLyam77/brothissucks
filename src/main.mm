#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <pthread.h>
#import <unistd.h>
#import <time.h>
#import <string.h>
#import <sys/mman.h>
#import "cheat_data.h"
#import "menu.h"
#import "overlay.h"
#import "esp.h"
#import "aimbot.h"
#import "recoil.h"
#import "tracelog.h"
#import "dumper.h"

IL2CPPResolver* g_resolver = nullptr;
void* g_localPlayer = nullptr;
void* g_mainCamera = nullptr;
bool g_firingDetected = true;
std::vector<PlayerData> g_players;
std::recursive_mutex g_playersMutex;
CheatConfig g_config;

static bool g_hooked = false;
static void* g_fwHandle = NULL;

#pragma mark - Process guard

static BOOL IsRunningInStandoff() {
    NSString* bundleId = [[NSBundle mainBundle] bundleIdentifier];
    return [bundleId isEqualToString:@"com.axlebolt.standoff2"] ||
           [[NSProcessInfo processInfo].processName isEqualToString:@"Standoff2"] ||
           [[NSProcessInfo processInfo].processName isEqualToString:@"UnityFramework"] ||
           [bundleId hasPrefix:@"com.axlebolt"];
}

#pragma mark - IL2CPP bootstrap

static void* LoadIL2CppFunctions() {
    NSString* fwPath = [[NSBundle mainBundle] pathForResource:@"UnityFramework" ofType:@"framework"];
    if (fwPath) {
        NSString* binPath = [fwPath stringByAppendingPathComponent:@"UnityFramework"];
        void* h = dlopen(binPath.UTF8String, RTLD_NOW | RTLD_GLOBAL);
        if (h) return h;
    }
    void* handle = dlopen("@executable_path/Frameworks/UnityFramework.framework/UnityFramework", RTLD_NOW | RTLD_GLOBAL);
    if (!handle) handle = dlopen("UnityFramework", RTLD_NOW | RTLD_GLOBAL);
    if (!handle) handle = dlopen(NULL, RTLD_LAZY);
    return handle;
}

static bool BindIL2CppFunctions(void* handle) {
    auto bind = [](void* h, const char* name) {
        void* ptr = dlsym(h, name);
        if (!ptr) ptr = dlsym(RTLD_DEFAULT, name);
        return ptr;
    };

    struct { const char* name; void** out; } binds[] = {
        {"il2cpp_domain_get", (void**)&il2cpp_domain_get},
        {"il2cpp_domain_get_assemblies", (void**)&il2cpp_domain_get_assemblies},
        {"il2cpp_assembly_get_image", (void**)&il2cpp_assembly_get_image},
        {"il2cpp_image_get_name", (void**)&il2cpp_image_get_name},
        {"il2cpp_image_get_class_count", (void**)&il2cpp_image_get_class_count},
        {"il2cpp_image_get_class", (void**)&il2cpp_image_get_class},
        {"il2cpp_class_get_parent", (void**)&il2cpp_class_get_parent},
        {"il2cpp_class_get_fields", (void**)&il2cpp_class_get_fields},
        {"il2cpp_field_get_type", (void**)&il2cpp_field_get_type},
        {"il2cpp_class_from_name", (void**)&il2cpp_class_from_name},
        {"il2cpp_class_get_field_from_name", (void**)&il2cpp_class_get_field_from_name},
        {"il2cpp_class_get_method_from_name", (void**)&il2cpp_class_get_method_from_name},
        {"il2cpp_class_get_methods", (void**)&il2cpp_class_get_methods},
        {"il2cpp_class_get_method_count", (void**)&il2cpp_class_get_method_count},
        {"il2cpp_class_get_name", (void**)&il2cpp_class_get_name},
        {"il2cpp_class_get_namespace", (void**)&il2cpp_class_get_namespace},
        {"il2cpp_field_get_offset", (void**)&il2cpp_field_get_offset},
        {"il2cpp_field_get_name", (void**)&il2cpp_field_get_name},
        {"il2cpp_field_get_value", (void**)&il2cpp_field_get_value},
        {"il2cpp_field_set_value", (void**)&il2cpp_field_set_value},
        {"il2cpp_field_static_get_value", (void**)&il2cpp_field_static_get_value},
        {"il2cpp_field_static_set_value", (void**)&il2cpp_field_static_set_value},
        {"il2cpp_runtime_invoke", (void**)&il2cpp_runtime_invoke},
        {"il2cpp_runtime_invoke_varargs", (void**)&il2cpp_runtime_invoke_varargs},
        {"il2cpp_method_get_name", (void**)&il2cpp_method_get_name},
        {"il2cpp_object_new", (void**)&il2cpp_object_new},
        {"il2cpp_object_unbox", (void**)&il2cpp_object_unbox},
        {"il2cpp_object_get_class", (void**)&il2cpp_object_get_class},
        {"il2cpp_class_from_il2cpp_type", (void**)&il2cpp_class_from_il2cpp_type},
        {"il2cpp_class_get_type", (void**)&il2cpp_class_get_type},
        {"il2cpp_type_get_type", (void**)&il2cpp_type_get_type},
        {"il2cpp_type_get_object", (void**)&il2cpp_type_get_object},
        {"il2cpp_string_new", (void**)&il2cpp_string_new},
        {"il2cpp_string_length", (void**)&il2cpp_string_length},
        {"il2cpp_string_chars", (void**)&il2cpp_string_chars},
        {"il2cpp_array_new", (void**)&il2cpp_array_new},
        {"il2cpp_array_new_specific", (void**)&il2cpp_array_new_specific},
        {"il2cpp_array_class_get", (void**)&il2cpp_array_class_get},
        {"il2cpp_array_get", (void**)&il2cpp_array_get},
        {"il2cpp_array_length", (void**)&il2cpp_array_length},
        {"il2cpp_thread_attach", (void**)&il2cpp_thread_attach},
        {"il2cpp_thread_current", (void**)&il2cpp_thread_current},
        {"il2cpp_thread_get_domain", (void**)&il2cpp_thread_get_domain},
    };

    int resolved = 0;
    for (auto& b : binds) {
        void* p = bind(handle, b.name);
        if (p) { *b.out = p; resolved++; }
    }

    if (resolved < 30) {
        CHEAT_LOG("t: IL2CPP binding failed %d/%d", resolved, 38);
        return false;
    }
    CHEAT_LOG("t: IL2CPP API bound, %d symbols", resolved);
    return true;
}

#pragma mark - Surgical anti-cheat neutralization

static void PatchReturnZero(void* addr) {
    if (!addr) return;
    uintptr_t page = (uintptr_t)addr & ~(uintptr_t)0x3FFF;
    size_t len = 0x4000;
    if (mprotect((void*)page, len, PROT_READ | PROT_WRITE) != 0) {
        CHEAT_LOG("ac: mprotect RW fail %p", addr);
        return;
    }
    const uint32_t insn[2] = { 0xD2800000, 0xD65F03C0 }; // MOV X0,#0; RET
    memcpy(addr, insn, 8);
    __builtin___clear_cache((char*)addr, (char*)addr + 8);
    mprotect((void*)page, len, PROT_READ | PROT_EXEC);
    CHEAT_LOG("ac: patched %p", addr);
}

static void* g_patchedAddrs[512];
static int g_patchedCount = 0;

static bool AlreadyPatched(void* addr) {
    for (int i = 0; i < g_patchedCount; i++)
        if (g_patchedAddrs[i] == addr) return true;
    return false;
}

static const char* g_skipPrefixes[] = {
    ".ctor", ".cctor", ".dtor", "Equals", "GetHashCode", "ToString",
    "GetType", "op_", "Finalize", "get_", "set_", nullptr
};

// methods that return Task<byte[]> / boxed objects the caller dereferences —
// zeroing those lands an NRE on the AC thread, which is itself a detection
// signal. preserved per 0.39.x Warden layout.
static const char* g_preserveExact[] = {
    "GetShort", "GetFull", "Get", nullptr
};

static void NukeACClass(const Il2CppClass* klass, const char* name) {
    if (!klass) { CHEAT_LOG("ac: class %s not found", name); return; }
    if (!il2cpp_class_get_methods || !il2cpp_method_get_name) return;
    int count = il2cpp_class_get_method_count ? il2cpp_class_get_method_count(klass) : -1;
    int patched = 0;
    int seen = 0;
    Il2CppIterator iter = 0;
    const Il2CppMethodInfo* m;
    while ((m = il2cpp_class_get_methods(klass, (Il2CppIterator*)&iter)) != nullptr) {
        if (!m) continue;
        const char* mn = il2cpp_method_get_name(m);
        if (!mn) continue;
        seen++;
        bool skip = false;
        for (int i = 0; g_skipPrefixes[i]; i++)
            if (strstr(mn, g_skipPrefixes[i])) { skip = true; break; }
        for (int i = 0; g_preserveExact[i]; i++)
            if (strcmp(mn, g_preserveExact[i]) == 0) { skip = true; break; }
        if (skip) { CHEAT_LOG("ac:  skip %s::%s", name, mn); continue; }
        // 0.38+ obfuscates detector member names — patch *everything* left in the
        // anticheat namespace instead of name-matching. detection shell is gone.
        void* target = (void*)((const void**)m)[0];
        if (target && !AlreadyPatched(target)) {
            PatchReturnZero(target);
            if (g_patchedCount < 512) g_patchedAddrs[g_patchedCount++] = target;
            patched++;
            if (patched <= 6) CHEAT_LOG("ac:  patch %s::%s", name, mn);
        }
    }
    CHEAT_LOG("ac: nuked %s (%d methods, %d patched)", name, count, patched);
}

// 0.38+ moved detector class names into the same obfuscation pass as gameplay
// members — the 0.37-era named list (InjectionCheatDetector, WardenIos, ...)
// resolves to nothing on current builds. Sweep every class whose namespace
// carries the anticheat families instead: names drift, namespaces don't.
static void NukeNamespace(const char* nsKey) {
    const Il2CppDomain* dom = il2cpp_domain_get();
    if (!dom || !il2cpp_domain_get_assemblies) { CHEAT_LOG("ac: domain not ready"); return; }
    size_t n = 0;
    const Il2CppAssembly** asmz = il2cpp_domain_get_assemblies(dom, &n);
    if (!asmz || n == 0) { CHEAT_LOG("ac: no assemblies"); return; }
    int classesFound = 0;
    for (size_t idx = 0; idx < n; idx++) {
        const Il2CppImage* img = il2cpp_assembly_get_image(asmz[idx]);
        if (!img || !il2cpp_image_get_class_count || !il2cpp_image_get_class) continue;
        uint32_t ccount = il2cpp_image_get_class_count(img);
        for (uint32_t c = 0; c < ccount; c++) {
            const Il2CppClass* k = il2cpp_image_get_class(img, c);
            if (!k) continue;
            const char* ns = il2cpp_class_get_namespace(k);
            if (!ns || !strstr(ns, nsKey)) continue;
            const char* cn = il2cpp_class_get_name(k);
            classesFound++;
            NukeACClass(k, cn ? cn : "?");
        }
    }
    CHEAT_LOG("ac: namespace '%s' sweep — %d classes", nsKey, classesFound);
}

static int g_acNuked = 0;

static void NukeAntiCheat() {
    if (g_acNuked) return;
    const int before = g_patchedCount;
    NukeNamespace("Anitcheat");                 // typo'd family name survives 0.39.2
    NukeNamespace("Axlebolt.Merger.Warden");    // native verify bridge, ns stem holds on iOS builds
    if (g_patchedCount > before) g_acNuked = 1;
    CHEAT_LOG("ac: total patched addrs=%d", g_patchedCount);
}

#pragma mark - Update loop (dedicated IL2CPP worker thread, never main)

static long g_workerTick = 0;

static void WorkerTick() {
    if (!g_hooked || !g_config.initialized) return;
    @autoreleasepool {
        GetRecoilControl()->Update();

        ESP* esp = (ESP*)GetESP();
        esp->Update();

        if (g_config.aimbotEnabled && !g_players.empty()) {
            Aimbot* aim = GetAimbot();
            aim->SetPlayerList(&g_players);
            aim->Update();
        }

        if ((g_workerTick++ % 300) == 0) {
            CHEAT_LOG("w: armed tick=%ld players=%zu", g_workerTick, g_players.size());
        }
    }
}

static void FinishInitialize() {
    CHEAT_LOG("w: FinishInitialize on worker thread");
    if (g_hooked) return;

    if (!il2cpp_domain_get || !il2cpp_domain_get()) { CHEAT_LOG("w: domain not ready"); return; }

    il2cpp_thread_attach(il2cpp_domain_get());

    IL2CPPResolver* r = new IL2CPPResolver();
    if (!r->Initialize()) {
        CHEAT_LOG("w: resolver Initialize FAILED — auto-dumping type system for 1.0.x derivation");
        delete r;
        static bool s_autoDumped = false;
        if (!s_autoDumped) {
            s_autoDumped = true;
            SO2_DumpAllTypes(true);
        }
        return;
    }

    g_resolver = r;
    g_config.initialized = true;
    g_hooked = true;

    if (SO2_DumpRequestedByUser()) SO2_DumpAllTypes(false);

    NukeAntiCheat();

    CHEAT_LOG("w: ready");
}

static void* cheatWorker(void* arg) {
    @autoreleasepool {
        CHEAT_LOG("w: worker start");

        int attempts = 0;
        while (attempts < 900) {
            if (!g_fwHandle) g_fwHandle = LoadIL2CppFunctions();
            if (g_fwHandle && BindIL2CppFunctions(g_fwHandle)) break;
            attempts++;
            usleep(100 * 1000);
        }
        if (!g_fwHandle || !il2cpp_domain_get) { CHEAT_LOG("w: gave up binding"); return NULL; }

        struct timespec ts;
        clock_gettime(CLOCK_MONOTONIC, &ts);
        double bootStart = (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;

        int idle = 0;
        bool acAttempted = false;
        while (idle < 400) {
            usleep(200 * 1000);
            idle++;
            if (!acAttempted && il2cpp_domain_get && il2cpp_domain_get()) {
                acAttempted = true;
                CHEAT_LOG("w: attempting early AC sweep");
                NukeAntiCheat();
            }
            clock_gettime(CLOCK_MONOTONIC, &ts);
            double now = (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
            if (now - bootStart < 8.0) continue;
            if (!il2cpp_domain_get || !il2cpp_domain_get()) continue;
            FinishInitialize();
            if (g_hooked) break;
        }
        if (!g_hooked) { CHEAT_LOG("w: tapout — never hooked"); return NULL; }

        CHEAT_LOG("w: entering main loop");
        while (true) {
            usleep(16 * 1000);
            WorkerTick();
        }
    }
    return NULL;
}

#pragma mark - UI scheduling (main thread)

static void ScheduleUI() {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            @autoreleasepool {
                [[NSUserDefaults standardUserDefaults] setObject:@"true" forKey:@"anticheat.disable.banme"];
                [[NSUserDefaults standardUserDefaults] setObject:@"true" forKey:@"anticheat.disable.checkpermission"];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
            CHEAT_LOG("m: AC flags written, creating UI");
            ShowMenu();
            SetupOverlayWindow();
            CHEAT_LOG("m: UI created");
        });
    });
}

#pragma mark - Entry

__attribute__((constructor))
static void StandoffCheatInit() {
    if (!IsRunningInStandoff()) return;

    CHEAT_LOG_OPEN();
    CHEAT_INSTALL_CRASH_HANDLERS();
    CHEAT_LOG("init: start");

    pthread_t thread;
    pthread_create(&thread, NULL, cheatWorker, NULL);
    ScheduleUI();
}

@interface StandoffCheatLoader : NSObject
@end

@implementation StandoffCheatLoader

+ (void)load {
    if (!IsRunningInStandoff()) return;
    CHEAT_LOG("init: loader attached");
}

@end