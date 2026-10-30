#import "recoil.h"
#import "il2cpp_resolver.h"
#import "tracelog.h"

extern IL2CPPResolver* GetResolver();

// 0.37→0.39.x reality check:
//   RecoilControl class + its _multiplier fields are GONE (obfuscated away).
//   What survives with readable names is the config chain:
//     GunParameters._recoilParameters -> RecoilParameters.horizontalRange / verticalRange
//   GunParameters instances are shared config assets — patching them zeroes
//   recoil for every gun without touching per-player runtime state.
static RecoilControl s_recoil;
static bool s_paramsPatched = false;

static void* FindObjectsOfTypeAll(const Il2CppClass* klass) {
    auto* r = GetResolver();
    if (!r || !klass || !r->classes.Object) return nullptr;
    const Il2CppMethodInfo* m = il2cpp_class_get_method_from_name(
        r->classes.Object, "FindObjectsOfTypeAll", 1);
    if (!m) return nullptr;
    const Il2CppType* t = il2cpp_class_get_type(klass);
    if (!t) return nullptr;
    Il2CppObject* typeObj = il2cpp_type_get_object(t);
    if (!typeObj) return nullptr;
    void* params[] = { typeObj };
    Il2CppException* exc = nullptr;
    return (void*)il2cpp_runtime_invoke(m, nullptr, params, &exc);
}

static const Il2CppClass* ResolveGunParameters() {
    auto* r = GetResolver();
    if (r->classes.GunParameters) return r->classes.GunParameters;
    // fallback: sweep namespaces for the named class
    if (!r || !r->assemblies) return nullptr;
    for (size_t i = 0; i < r->assemblyCount; i++) {
        const Il2CppImage* img = il2cpp_assembly_get_image(r->assemblies[i]);
        if (!img) continue;
        const Il2CppClass* k = il2cpp_class_from_name(img, "Axlebolt.Standoff.Inventory.Gun", "GunParameters");
        if (k) return k;
    }
    return nullptr;
}

void RecoilControl::Update() {
    if (!g_config.initialized || !g_config.recoilEnabled) return;
    if (s_paramsPatched) return;

    auto* r = GetResolver();
    if (!r || !r->IsReady()) return;
    const Il2CppClass* gunParams = ResolveGunParameters();
    if (!gunParams || !r->classes.RecoilParameters) return;

    Il2CppArray* all = (Il2CppArray*)FindObjectsOfTypeAll(gunParams);
    if (!all || il2cpp_array_length(all) == 0) return;

    const Il2CppFieldInfo* rpField =
        il2cpp_class_get_field_from_name(gunParams, "_recoilParameters");
    if (!rpField) { CHEAT_LOG("rc: gun params layout drifted"); s_paramsPatched = true; return; }

    const Il2CppFieldInfo* horiz =
        il2cpp_class_get_field_from_name(r->classes.RecoilParameters, "horizontalRange");
    const Il2CppFieldInfo* vert =
        il2cpp_class_get_field_from_name(r->classes.RecoilParameters, "verticalRange");
    if (!horiz || !vert) { CHEAT_LOG("rc: recoil params fields gone"); s_paramsPatched = true; return; }

    int patched = 0;
    uintptr_t count = il2cpp_array_length(all);
    if (count > 256) count = 256;
    for (uintptr_t i = 0; i < count; i++) {
        void* gp = il2cpp_array_get(all, i);
        if (!gp) continue;
        void* rp = nullptr;
        il2cpp_field_get_value(gp, rpField, &rp);
        if (!rp) continue;
        float zero = 0.0f;
        il2cpp_field_set_value(rp, horiz, &zero);
        il2cpp_field_set_value(rp, vert, &zero);
        patched++;
    }
    if (patched > 0) {
        s_paramsPatched = true;
        CHEAT_LOG("rc: zeroed recoil spread on %d gun configs", patched);
    }
}

RecoilControl* GetRecoilControl() {
    return &s_recoil;
}
