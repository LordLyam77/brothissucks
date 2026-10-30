#import "dumper.h"
#import "il2cpp_api.h"
#import "tracelog.h"
#import <Foundation/Foundation.h>
#import <stdio.h>
#import <string.h>

// intentionally independent of the resolver: the dumper must run even when
// resolution FAILED (that's exactly when it's most valuable).
static char LowerChar(char c) {
    return (c >= 'A' && c <= 'Z') ? (char)(c - 'A' + 'a') : c;
}

static bool CIContains(const char* hay, const char* needle) {
    if (!hay || !needle) return false;
    for (const char* h = hay; *h; h++) {
        const char* a = h; const char* b = needle;
        for (; *b; a++, b++)
            if (LowerChar(*a) != LowerChar(*b)) break;
        if (!*b) return true;
    }
    return false;
}

// member detail skipped for noisy engine/system namespaces — class lines only.
static bool IsLeanNamespace(const char* ns) {
    if (!ns) return false;
    return CIContains(ns, "UnityEngine") || CIContains(ns, "System") ||
           CIContains(ns, "Photon") || CIContains(ns, "Firebase") ||
           CIContains(ns, "Google");
}

void SO2_DumpAllTypes(bool autoTriggered) {
    if (!il2cpp_domain_get || !il2cpp_domain_get()) {
        CHEAT_LOG("d: no domain, dump aborted");
        return;
    }
    size_t asmCount = 0;
    const Il2CppAssembly** asmz = il2cpp_domain_get_assemblies(il2cpp_domain_get(), &asmCount);
    if (!asmz || asmCount == 0) { CHEAT_LOG("d: no assemblies"); return; }

    NSString* dir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString* path = [dir stringByAppendingPathComponent:
        autoTriggered ? @"so2dump_auto.cs" : @"so2dump.cs"];
    FILE* f = fopen([path UTF8String], "w");
    if (!f) { CHEAT_LOG("d: cannot open dump file"); return; }

    fprintf(f, "// Standoff 2 live type-system dump%s\n// manual=0\n", autoTriggered ? " (automatic — anchor classes failed)" : "");
    CHEAT_LOG("d: dumping %zu assemblies to %s", asmCount, [path UTF8String]);

    long classTotal = 0;
    for (size_t i = 0; i < asmCount; i++) {
        const Il2CppImage* img = il2cpp_assembly_get_image(asmz[i]);
        if (!img || !il2cpp_image_get_name(img)) continue;
        const char* imgName = il2cpp_image_get_name(img);
        fprintf(f, "\n// Assembly: %s\n", imgName);

        if (!il2cpp_image_get_class_count || !il2cpp_image_get_class) {
            CHEAT_LOG("d: image-class api missing");
            break;
        }
        uint32_t ccount = il2cpp_image_get_class_count(img);
        for (uint32_t c = 0; c < ccount; c++) {
            const Il2CppClass* k = il2cpp_image_get_class(img, c);
            if (!k) continue;
            const char* ns = il2cpp_class_get_namespace(k);
            const char* nm = il2cpp_class_get_name(k);
            if (!nm) continue;
            classTotal++;

            const Il2CppClass* parent = il2cpp_class_get_parent(k);
            const char* pnm = parent ? il2cpp_class_get_name(parent) : nullptr;

            fprintf(f, "// Namespace: %s\nclass %s%s%s\n{\n",
                    ns ? ns : "", nm,
                    pnm ? " : " : "", pnm ? pnm : "");
            if (IsLeanNamespace(ns)) { fprintf(f, "}\n"); continue; }

            // fields — offsets here are THE payout: obfuscated-but-positioned
            if (il2cpp_class_get_fields && il2cpp_field_get_name && il2cpp_field_get_offset) {
                Il2CppIterator fit = 0;
                const Il2CppFieldInfo* fld;
                while ((fld = il2cpp_class_get_fields(k, &fit)) != nullptr) {
                    const char* fn = il2cpp_field_get_name(fld);
                    if (!fn) continue;
                    int typeId = 0;
                    if (il2cpp_field_get_type && il2cpp_type_get_type)
                        typeId = il2cpp_type_get_type(il2cpp_field_get_type(fld));
                    fprintf(f, "    %s : TypeId(%d); // 0x%lx\n", fn, typeId,
                            (unsigned long)il2cpp_field_get_offset(fld));
                }
            }
            // methods — names only; obfuscated names are exactly what we want
            if (il2cpp_class_get_methods && il2cpp_method_get_name) {
                Il2CppIterator mit = 0;
                const Il2CppMethodInfo* m;
                while ((m = il2cpp_class_get_methods(k, &mit)) != nullptr) {
                    const char* mn = il2cpp_method_get_name(m);
                    if (mn) fprintf(f, "    %s;\n", mn);
                }
            }
            fprintf(f, "}\n");
        }
        fflush(f);
        CHEAT_LOG("d: image %s done (classes so far %ld)", imgName, classTotal);
    }
    fclose(f);
    CHEAT_LOG("d: DUMP COMPLETE — %ld classes → %s", classTotal, [path UTF8String]);
}

bool SO2_DumpRequestedByUser() {
    NSString* v = [[NSUserDefaults standardUserDefaults] stringForKey:@"so2.dump"];
    return v && [v isEqualToString:@"1"];
}
