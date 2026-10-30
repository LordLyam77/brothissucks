#pragma once

// 1.0.0 derivation hook — walks the live IL2CPP type system and writes a
// dump.cs to Documents. Triggered by user default "so2.dump" = "1", or
// automatically when core anchor classes fail to resolve (major version
// renamed something — the dump IS the fix map for it).
void SO2_DumpAllTypes(bool autoTriggered);
bool SO2_DumpRequestedByUser();
