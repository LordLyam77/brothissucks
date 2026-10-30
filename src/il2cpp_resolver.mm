#import "il2cpp_resolver.h"
#include <dlfcn.h>
#include <cstdio>
#include "tracelog.h"

#define DEFINE_FPTR(ret, name, args) ret (*name) args = nullptr

extern "C" {
    DEFINE_FPTR(const Il2CppDomain*, il2cpp_domain_get, ());
    DEFINE_FPTR(const Il2CppAssembly**, il2cpp_domain_get_assemblies, (const Il2CppDomain*, size_t*));
    DEFINE_FPTR(const Il2CppImage*, il2cpp_assembly_get_image, (const Il2CppAssembly*));
    DEFINE_FPTR(const char*, il2cpp_image_get_name, (const Il2CppImage*));
    DEFINE_FPTR(const Il2CppClass*, il2cpp_class_from_name, (const Il2CppImage*, const char*, const char*));
    DEFINE_FPTR(const Il2CppFieldInfo*, il2cpp_class_get_field_from_name, (const Il2CppClass*, const char*));
    DEFINE_FPTR(const Il2CppMethodInfo*, il2cpp_class_get_method_from_name, (const Il2CppClass*, const char*, int));
    DEFINE_FPTR(const char*, il2cpp_class_get_name, (const Il2CppClass*));
    DEFINE_FPTR(const char*, il2cpp_class_get_namespace, (const Il2CppClass*));
    DEFINE_FPTR(const Il2CppClass*, il2cpp_class_get_parent, (const Il2CppClass*));
    DEFINE_FPTR(const Il2CppFieldInfo*, il2cpp_class_get_fields, (const Il2CppClass*, Il2CppIterator*));
    DEFINE_FPTR(size_t, il2cpp_field_get_offset, (const Il2CppFieldInfo*));
    DEFINE_FPTR(const char*, il2cpp_field_get_name, (const Il2CppFieldInfo*));
    DEFINE_FPTR(const Il2CppType*, il2cpp_field_get_type, (const Il2CppFieldInfo*));
    DEFINE_FPTR(const Il2CppType*, il2cpp_field_get_type, (const Il2CppFieldInfo*));
    DEFINE_FPTR(void, il2cpp_field_get_value, (void*, const Il2CppFieldInfo*, void*));
    DEFINE_FPTR(void, il2cpp_field_set_value, (void*, const Il2CppFieldInfo*, const void*));
    DEFINE_FPTR(void, il2cpp_field_static_get_value, (const Il2CppFieldInfo*, void*));
    DEFINE_FPTR(void, il2cpp_field_static_set_value, (const Il2CppFieldInfo*, const void*));
    DEFINE_FPTR(Il2CppObject*, il2cpp_runtime_invoke, (const Il2CppMethodInfo*, void*, void**, Il2CppException**));
    DEFINE_FPTR(Il2CppObject*, il2cpp_runtime_invoke_varargs, (const Il2CppMethodInfo*, void*, void**, Il2CppException**));
    DEFINE_FPTR(const char*, il2cpp_method_get_name, (const Il2CppMethodInfo*));
    DEFINE_FPTR(Il2CppObject*, il2cpp_object_new, (const Il2CppClass*));
    DEFINE_FPTR(Il2CppObject*, il2cpp_object_unbox, (Il2CppObject*));
    DEFINE_FPTR(Il2CppClass*, il2cpp_object_get_class, (Il2CppObject*));
    DEFINE_FPTR(Il2CppThread*, il2cpp_thread_attach, (const Il2CppDomain*));
    DEFINE_FPTR(Il2CppThread*, il2cpp_thread_current, ());
    DEFINE_FPTR(const Il2CppDomain*, il2cpp_thread_get_domain, (Il2CppThread*));
    DEFINE_FPTR(Il2CppClass*, il2cpp_class_from_il2cpp_type, (const Il2CppType*));
    DEFINE_FPTR(const Il2CppType*, il2cpp_class_get_type, (const Il2CppClass*));
    DEFINE_FPTR(int, il2cpp_type_get_type, (const Il2CppType*));
    DEFINE_FPTR(Il2CppObject*, il2cpp_type_get_object, (const Il2CppType*));
    DEFINE_FPTR(Il2CppObject*, il2cpp_string_new, (const char*));
    DEFINE_FPTR(size_t, il2cpp_string_length, (Il2CppObject*));
    DEFINE_FPTR(const char*, il2cpp_string_chars, (Il2CppObject*));
    DEFINE_FPTR(Il2CppArray*, il2cpp_array_new, (const Il2CppClass*, uintptr_t));
    DEFINE_FPTR(Il2CppArray*, il2cpp_array_new_specific, (const Il2CppClass*, uintptr_t));
    DEFINE_FPTR(Il2CppClass*, il2cpp_array_class_get, (const Il2CppClass*, uint32_t));
    DEFINE_FPTR(void*, il2cpp_array_get, (const Il2CppArray*, uintptr_t));
    DEFINE_FPTR(uintptr_t, il2cpp_array_length, (const Il2CppArray*));
}

extern IL2CPPResolver* g_resolver;

IL2CPPResolver* GetResolver() {
    return g_resolver;
}

const Il2CppImage* IL2CPPResolver::FindImage(const char* partialName) {
    for (size_t i = 0; i < assemblyCount; i++) {
        const Il2CppImage* img = il2cpp_assembly_get_image(assemblies[i]);
        if (!img) continue;
        const char* imgName = il2cpp_image_get_name(img);
        if (imgName && strstr(imgName, partialName)) return img;
    }
    return nullptr;
}

const Il2CppClass* IL2CPPResolver::FindClass(const char* ns, const char* name) {
    for (size_t i = 0; i < assemblyCount; i++) {
        const Il2CppImage* img = il2cpp_assembly_get_image(assemblies[i]);
        if (!img) continue;
        const Il2CppClass* klass = il2cpp_class_from_name(img, ns, name);
        if (klass) return klass;
    }
    return nullptr;
}

const Il2CppClass* IL2CPPResolver::FindClassRecursive(const char* name) {
    for (size_t i = 0; i < assemblyCount; i++) {
        const Il2CppImage* img = il2cpp_assembly_get_image(assemblies[i]);
        if (!img) continue;
        const Il2CppClass* klass = il2cpp_class_from_name(img, "", name);
        if (klass) return klass;
        const char* ns[] = {
            "Axlebolt.Standoff.Player",
            "Axlebolt.Standoff.Inventory",
            "Axlebolt.Standoff.Inventory.Gun",
            "Axlebolt.Standoff.Inventory.Weapon",
            "Axlebolt.Standoff.Controls",
            "Axlebolt.Standoff.Game.UI",
            "Axlebolt.Standoff.Game",
            "Axlebolt.Standoff.Common",
            "Axlebolt.Standoff",
            "Axlebolt.Utilities",
            "Axlebolt.Cam",
            "Axlebolt.Ballistics.Simulation",
            "UnityEngine",
            "",
            nullptr
        };
        for (int j = 0; ns[j]; j++) {
            klass = il2cpp_class_from_name(img, ns[j], name);
            if (klass) return klass;
        }
    }
    return nullptr;
}

// 1.0.x insurance: exact name not found → walk the live type system and match
// game classes by case-insensitive substring (catches suffix renames like
// PlayerController → PlayerControllerNew without a new dump).
static char ClLower(char c) { return (c >= 'A' && c <= 'Z') ? (char)(c - 'A' + 'a') : c; }
static bool ClCIEqual(const char* a, const char* b) {
    if (!a || !b) return false;
    for (; *a || *b; a++, b++)
        if (ClLower(*a) != ClLower(*b)) return false;
    return true;
}
static bool ClCIContains(const char* hay, const char* needle) {
    if (!hay || !needle) return false;
    for (const char* h = hay; *h; h++) {
        const char* a = h; const char* b = needle;
        for (; *b; a++, b++)
            if (ClLower(*a) != ClLower(*b)) break;
        if (!*b) return true;
    }
    return false;
}

const Il2CppClass* IL2CPPResolver::FindClassLoose(const char* name) {
    if (!name || !il2cpp_image_get_class || !il2cpp_image_get_class_count) return nullptr;
    // pass 1: exact-name match anywhere — pass 2 is only the contains-fallback,
    // so "PlayerController" can't lose to a longer variant sharing the prefix.
    for (int pass = 0; pass < 2; pass++) {
        for (size_t i = 0; i < assemblyCount; i++) {
            const Il2CppImage* img = il2cpp_assembly_get_image(assemblies[i]);
            if (!img) continue;
            uint32_t ccount = il2cpp_image_get_class_count(img);
            for (uint32_t c = 0; c < ccount; c++) {
                const Il2CppClass* k = il2cpp_image_get_class(img, c);
                if (!k) continue;
                const char* nm = il2cpp_class_get_name(k);
                if (!nm) continue;
                if (pass == 0 ? ClCIEqual(nm, name) : ClCIContains(nm, name)) return k;
            }
        }
    }
    return nullptr;
}

size_t IL2CPPResolver::GetFieldOffset(const Il2CppClass* klass, const char* fieldName) {    if (!klass) return 0;
    std::string key = std::string(il2cpp_class_get_name(klass)) + "." + fieldName;
    auto it = m_fieldCache.find(key);
    if (it != m_fieldCache.end()) return it->second;
    const Il2CppFieldInfo* field = il2cpp_class_get_field_from_name(klass, fieldName);
    if (!field) return 0;
    size_t offset = il2cpp_field_get_offset(field);
    m_fieldCache[key] = offset;
    return offset;
}

const Il2CppMethodInfo* IL2CPPResolver::GetMethod(const Il2CppClass* klass, const char* name, int paramCount) {
    if (!klass) return nullptr;
    return il2cpp_class_get_method_from_name(klass, name, paramCount);
}

bool IL2CPPResolver::Initialize() {
    if (m_ready) return true;

    domain = il2cpp_domain_get();
    if (!domain) return false;

    assemblies = il2cpp_domain_get_assemblies(domain, &assemblyCount);
    if (!assemblies || assemblyCount == 0) return false;

    CHEAT_LOG("r: domain ok, %zu assemblies", assemblyCount);

    auto resolve = [&](const char* n) -> const Il2CppClass* {
        const Il2CppClass* k = FindClassRecursive(n);
        if (!k) {
            k = FindClassLoose(n);
            if (k) CHEAT_LOG("r: loose-resolved '%s' via type-system sweep", n);
        }
        return k;
    };

    classes.PlayerController = resolve("PlayerController");
    classes.PlayerManager = resolve("PlayerManager");
    classes.BipedMap = resolve("BipedMap");
    classes.PlayerCharacterView = resolve("PlayerCharacterView");
    classes.WeaponController = resolve("WeaponController");
    classes.RecoilControl = resolve("RecoilControl");
    classes.RecoilParameters = resolve("RecoilParameters");
    classes.GunParameters = resolve("GunParameters");
    classes.CameraScopeZoomer = resolve("CameraScopeZoomer");
    classes.AimView = resolve("AimView");
    classes.ShootArea = resolve("ShootArea");
    classes.HUDView = resolve("HUDView");
    classes.PlayerView = resolve("PlayerView");
    classes.FpsOverlay = resolve("FpsOverlay");
    classes.WeaponManager = resolve("WeaponManager");
    classes.PlayerInputs = resolve("PlayerInputs");
    classes.Raycaster = resolve("Raycaster");
    classes.SpectatorCameraEffect = resolve("SpectatorCameraEffect");
    classes.PhotonPlayerGameExtension = resolve("PhotonPlayerGameExtension");
    CHEAT_LOG("r: standoff classes done (player=%p recoil=%p)", (void*)classes.PlayerController, (void*)classes.RecoilControl);

    classes.PhotonView = FindClass("Photon", "PhotonView");
    classes.PhotonPlayer = FindClass("", "PhotonPlayer");

    classes.GameObject = FindClass("UnityEngine", "GameObject");
    classes.Transform = FindClass("UnityEngine", "Transform");
    classes.Camera = FindClass("UnityEngine", "Camera");
    classes.MonoBehaviour = FindClass("UnityEngine", "MonoBehaviour");
    classes.Behaviour = FindClass("UnityEngine", "Behaviour");
    classes.Component = FindClass("UnityEngine", "Component");
    classes.Object = FindClass("UnityEngine", "Object");
    classes.Vector3 = FindClass("UnityEngine", "Vector3");
    classes.Quaternion = FindClass("UnityEngine", "Quaternion");
    classes.Rect = FindClass("UnityEngine", "Rect");
    classes.Screen = FindClass("UnityEngine", "Screen");
    CHEAT_LOG("r: engine classes done");

    int found = 0;
    if (classes.PlayerController) found++;
    if (classes.PlayerManager) found++;
    if (classes.BipedMap) found++;
    if (classes.Transform) found++;
    if (classes.Camera) found++;
    if (classes.GameObject) found++;
    if (classes.PhotonView) found++;

    printf("Resolved %d core classes\n", found);

    if (found < 4) {
        printf("WARNING: Too few classes resolved, retrying...\n");
        return false;
    }

    m_ready = true;
    return true;
}
