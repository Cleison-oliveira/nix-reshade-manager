#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <dlfcn.h>
#include <stdint.h>
#include <ctype.h>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>

#ifndef DEFAULT_KEY_EFFECTS
#define DEFAULT_KEY_EFFECTS "116,0,1,0"
#endif

#ifndef DEFAULT_KEY_OVERLAY
#define DEFAULT_KEY_OVERLAY "117,0,1,0"
#endif

typedef struct VkNegotiateLoaderLayerInterfaceVersion {
    int sType;
    void *pNext;
    uint32_t loaderLayerInterfaceVersion;
    void *pfnGetInstanceProcAddr;
    void *pfnGetDeviceProcAddr;
    void *pfnGetPhysicalDeviceProcAddr;
} VkNegotiateLoaderLayerInterfaceVersion;

typedef int (*PFN_vkNegotiate)(VkNegotiateLoaderLayerInterfaceVersion *);
typedef void *(*PFN_vkVoidFunction)(void);
typedef void *(*PFN_vkGetInstanceProcAddr)(void *instance, const char *pName);
typedef int (*PFN_vkCreateInstance)(const void *pCreateInfo, const void *pAllocator, void *pInstance);

static void log_debug(const char *fmt, ...) {
    const char *no_log = getenv("RESHADE_DISABLE_LOGGING");
    if (no_log && no_log[0] != '\0' && strcmp(no_log, "0") != 0) return;

    const char *xdg = getenv("XDG_DATA_HOME");
    char dir[1024];
    char path[1024];
    if (xdg && xdg[0] != '\0') {
        snprintf(dir, sizeof(dir), "%s/reshade", xdg);
    } else {
        const char *home = getenv("HOME");
        if (!home) return;
        snprintf(dir, sizeof(dir), "%s/.local/share/reshade", home);
    }
    mkdir(dir, 0755);
    snprintf(path, sizeof(path), "%s/loader_filter.log", dir);
    FILE *f = fopen(path, "a");
    if (!f) return;
    va_list args;
    va_start(args, fmt);
    vfprintf(f, fmt, args);
    va_end(args);
    fclose(f);
}

static const char *get_basename(const char *path) {
    if (!path) return "";
    const char *p1 = strrchr(path, '/');
    const char *p2 = strrchr(path, '\\');
    const char *p = (p1 > p2) ? p1 : p2;
    return p ? p + 1 : path;
}

static int is_reshade_disabled(void) {
    const char *dis = getenv("DISABLE_RESHADE");
    if (dis && dis[0] != '\0' && strcmp(dis, "0") != 0) return 1;

    const char *r = getenv("RESHADE");
    if (r && strcmp(r, "0") == 0) return 1;

    const char *re = getenv("RESHADE_ENABLE");
    if (re && strcmp(re, "0") == 0) return 1;

    return 0;
}

static int is_launcher_or_helper(void) {
    char exe_path[1024];
    ssize_t n = readlink("/proc/self/exe", exe_path, sizeof(exe_path) - 1);
    if (n > 0) {
        exe_path[n] = '\0';
        const char *base = get_basename(exe_path);
        char lower_exe[256];
        size_t elen = strlen(base);
        if (elen >= sizeof(lower_exe)) elen = sizeof(lower_exe) - 1;
        for (size_t i = 0; i < elen; i++) {
            lower_exe[i] = (char)tolower((unsigned char)base[i]);
        }
        lower_exe[elen] = '\0';

        if (strcmp(lower_exe, "heroic") == 0 ||
            strcmp(lower_exe, "lutris") == 0 ||
            strcmp(lower_exe, "heronite") == 0 ||
            strcmp(lower_exe, "steam") == 0 ||
            strcmp(lower_exe, "steamwebhelper") == 0 ||
            strcmp(lower_exe, "epicwebhelper") == 0 ||
            strcmp(lower_exe, "gamescope") == 0 ||
            strcmp(lower_exe, "gamemoded") == 0 ||
            strcmp(lower_exe, "faugus") == 0) {
            return 1;
        }
    }

    return 0;
}

static void ensure_directories_and_preset(const char *profile_dir) {
    if (!profile_dir || profile_dir[0] == '\0') return;

    mkdir(profile_dir, 0775);

    const char *cache_root = getenv("XDG_CACHE_HOME");
    char cache_dir[1024];
    if (cache_root && cache_root[0] != '\0') {
        snprintf(cache_dir, sizeof(cache_dir), "%s/reshade", cache_root);
    } else {
        const char *home = getenv("HOME");
        snprintf(cache_dir, sizeof(cache_dir), "%s/.cache/reshade", home ? home : "");
    }
    mkdir(cache_dir, 0775);

    char preset_path[1024];
    snprintf(preset_path, sizeof(preset_path), "%s/ReShadePreset.ini", profile_dir);

    struct stat st;
    if (stat(preset_path, &st) != 0) {
        FILE *pf = fopen(preset_path, "w");
        if (pf) {
            fputs("Techniques=\nTechniqueSorting=\n", pf);
            fclose(pf);
            chmod(preset_path, 0664);
        }
    } else {
        chmod(preset_path, 0664);
    }
}

static void setup_profile_ini(const char *ini_path, const char *profile_dir) {
    ensure_directories_and_preset(profile_dir);

    char preset_path[1024];
    snprintf(preset_path, sizeof(preset_path), "%s/ReShadePreset.ini", profile_dir);

    const char *home = getenv("HOME");
    if (!home) home = "";

    const char *cache_root = getenv("XDG_CACHE_HOME");
    char cache_dir[1024];
    if (cache_root && cache_root[0] != '\0') {
        snprintf(cache_dir, sizeof(cache_dir), "%s/reshade", cache_root);
    } else {
        snprintf(cache_dir, sizeof(cache_dir), "%s/.cache/reshade", home);
    }

    FILE *f = fopen(ini_path, "r");
    if (!f) {
        // Initial creation with declarative defaults
        FILE *out = fopen(ini_path, "w");
        if (!out) return;

        fprintf(out,
            "[GENERAL]\n"
            "EffectSearchPaths=@NIX_RESHADE_SHADERS@/**,%s/.local/share/reshade/reshade-shaders/Shaders/**\n"
            "IntermediateCachePath=%s\n"
            "PresetPath=%s\n"
            "TextureSearchPaths=@NIX_RESHADE_TEXTURES@/**,%s/.local/share/reshade/reshade-shaders/Textures/**\n"
            "\n"
            "[INPUT]\n"
            "KeyEffects=" DEFAULT_KEY_EFFECTS "\n"
            "KeyOverlay=" DEFAULT_KEY_OVERLAY "\n"
            "\n"
            "[OVERLAY]\n"
            "AutoSavePreset=1\n"
            "TutorialProgress=4\n",
            home, cache_dir, preset_path, home
        );
        fclose(out);
        chmod(ini_path, 0664);
        return;
    }

    // File exists: inspect without touching user settings
    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (sz <= 0 || sz > 2 * 1024 * 1024) { fclose(f); return; }

    char *content = malloc(sz + 1);
    if (!content) { fclose(f); return; }
    size_t rd = fread(content, 1, sz, f);
    fclose(f);
    content[rd] = '\0';

    int needs_fix = 0;
    if (strstr(content, "@NIX_RESHADE_SHADERS@") == NULL) {
        needs_fix = 1;
    }
    if (strstr(content, "PresetPath=./ReShadePreset.ini") != NULL) {
        needs_fix = 1;
    }

    // If Nix store shaders are already included and preset path is valid, leave untouched!
    if (!needs_fix) {
        free(content);
        chmod(ini_path, 0664);
        return;
    }

    char tmp_path[1024];
    snprintf(tmp_path, sizeof(tmp_path), "%s.tmp", ini_path);
    FILE *out = fopen(tmp_path, "w");
    if (!out) { free(content); return; }

    char *saveptr = NULL;
    char *line = strtok_r(content, "\r\n", &saveptr);
    int in_general = 0;

    while (line) {
        if (strcmp(line, "[GENERAL]") == 0) {
            in_general = 1;
            fprintf(out, "%s\n", line);
            line = strtok_r(NULL, "\r\n", &saveptr);
            continue;
        }
        if (line[0] == '[') {
            in_general = 0;
        }

        if (in_general) {
            if (strncmp(line, "EffectSearchPaths=", 18) == 0) {
                if (strstr(line, "@NIX_RESHADE_SHADERS@") == NULL) {
                    const char *existing = line + 18;
                    if (*existing) {
                        fprintf(out, "EffectSearchPaths=@NIX_RESHADE_SHADERS@/**,%s\n", existing);
                    } else {
                        fprintf(out, "EffectSearchPaths=@NIX_RESHADE_SHADERS@/**,%s/.local/share/reshade/reshade-shaders/Shaders/**\n", home);
                    }
                } else {
                    fprintf(out, "%s\n", line);
                }
                line = strtok_r(NULL, "\r\n", &saveptr);
                continue;
            }
            if (strncmp(line, "TextureSearchPaths=", 19) == 0) {
                if (strstr(line, "@NIX_RESHADE_TEXTURES@") == NULL) {
                    const char *existing = line + 19;
                    if (*existing) {
                        fprintf(out, "TextureSearchPaths=@NIX_RESHADE_TEXTURES@/**,%s\n", existing);
                    } else {
                        fprintf(out, "TextureSearchPaths=@NIX_RESHADE_TEXTURES@/**,%s/.local/share/reshade/reshade-shaders/Textures/**\n", home);
                    }
                } else {
                    fprintf(out, "%s\n", line);
                }
                line = strtok_r(NULL, "\r\n", &saveptr);
                continue;
            }
            if (strncmp(line, "PresetPath=./ReShadePreset.ini", 30) == 0) {
                fprintf(out, "PresetPath=%s\n", preset_path);
                line = strtok_r(NULL, "\r\n", &saveptr);
                continue;
            }
        }

        // All other sections ([INPUT], [OVERLAY], [STYLE], etc.) remain completely untouched!
        fprintf(out, "%s\n", line);
        line = strtok_r(NULL, "\r\n", &saveptr);
    }

    fclose(out);
    free(content);
    rename(tmp_path, ini_path);
    chmod(ini_path, 0664);
}

static void scan_and_standardize_configs(void) {
    const char *xdg = getenv("XDG_DATA_HOME");
    char configs_dir[1024];
    if (xdg && xdg[0] != '\0') {
        snprintf(configs_dir, sizeof(configs_dir), "%s/reshade/configurations", xdg);
    } else {
        const char *home = getenv("HOME");
        if (!home) return;
        snprintf(configs_dir, sizeof(configs_dir), "%s/.local/share/reshade/configurations", home);
    }

    DIR *d = opendir(configs_dir);
    if (!d) return;
    struct dirent *ent;
    while ((ent = readdir(d)) != NULL) {
        if (ent->d_name[0] == '.') continue;
        char pdir[1024];
        snprintf(pdir, sizeof(pdir), "%s/%s", configs_dir, ent->d_name);
        struct stat st;
        if (stat(pdir, &st) == 0 && S_ISDIR(st.st_mode)) {
            char ini[1024];
            snprintf(ini, sizeof(ini), "%s/ReShade.ini", pdir);
            setup_profile_ini(ini, pdir);
        }
    }
    closedir(d);
}

static void *real_handle = NULL;
static PFN_vkNegotiate real_func = NULL;
static PFN_vkGetInstanceProcAddr real_gipa = NULL;
static PFN_vkCreateInstance real_createInstance = NULL;

static void init_real_reshade(void) {
    if (!real_handle) {
        real_handle = dlopen("@ORIG_RESHADE_SO@", RTLD_LAZY | RTLD_GLOBAL);
        if (real_handle) {
            real_func = (PFN_vkNegotiate)dlsym(real_handle, "vkNegotiateLoaderLayerInterfaceVersion");
            log_debug("[ReShade Filter] Loaded @ORIG_RESHADE_SO@ (real_func=%p)\n", (void*)real_func);
        } else {
            log_debug("[ReShade Filter] ERROR: dlopen @ORIG_RESHADE_SO@ failed: %s\n", dlerror());
        }
    }
}

static int hook_vkCreateInstance(const void *pCreateInfo, const void *pAllocator, void *pInstance) {
    if (!real_createInstance && real_gipa) {
        real_createInstance = (PFN_vkCreateInstance)real_gipa(NULL, "vkCreateInstance");
    }
    int res = real_createInstance ? real_createInstance(pCreateInfo, pAllocator, pInstance) : -3;
    log_debug("[ReShade Filter] PID %d: vkCreateInstance executed, res=%d\n", getpid(), res);
    return res;
}

static void *hook_vkGetInstanceProcAddr(void *instance, const char *pName) {
    if (pName && strcmp(pName, "vkCreateInstance") == 0) {
        if (!real_createInstance && real_gipa) {
            real_createInstance = (PFN_vkCreateInstance)real_gipa(instance, "vkCreateInstance");
        }
        return (void *)hook_vkCreateInstance;
    }
    if (real_gipa) {
        return real_gipa(instance, pName);
    }
    return NULL;
}

int vkNegotiateLoaderLayerInterfaceVersion(VkNegotiateLoaderLayerInterfaceVersion *pVersionStruct) {
    char exe[512] = {0};
    ssize_t n = readlink("/proc/self/exe", exe, sizeof(exe) - 1);
    if (n > 0) exe[n] = '\0';

    char cmd[1024] = {0};
    FILE *fc = fopen("/proc/self/cmdline", "rb");
    if (fc) {
        size_t b = fread(cmd, 1, sizeof(cmd) - 1, fc);
        fclose(fc);
        for (size_t i = 0; i < b; i++) if (cmd[i] == '\0') cmd[i] = ' ';
    }

    if (is_reshade_disabled() || is_launcher_or_helper()) {
        log_debug("[ReShade Filter] PID %d (%s | %s): Ignored (disabled or desktop launcher)\n", getpid(), exe, cmd);
        return -3;
    }

    log_debug("[ReShade Filter] PID %d (%s | %s): Negotiating interface version %u...\n",
              getpid(), exe, cmd, pVersionStruct ? pVersionStruct->loaderLayerInterfaceVersion : 0);

    scan_and_standardize_configs();
    init_real_reshade();
    if (!real_func) {
        log_debug("[ReShade Filter] ERROR: real_func is NULL\n");
        return -3;
    }

    int res = real_func(pVersionStruct);
    if (res == 0 && pVersionStruct && pVersionStruct->pfnGetInstanceProcAddr) {
        real_gipa = (PFN_vkGetInstanceProcAddr)pVersionStruct->pfnGetInstanceProcAddr;
        pVersionStruct->pfnGetInstanceProcAddr = (void *)hook_vkGetInstanceProcAddr;
        log_debug("[ReShade Filter] Successfully hooked pfnGetInstanceProcAddr (%p) for PID %d\n", (void*)real_gipa, getpid());
    }
    return res;
}

void *vkGetInstanceProcAddr(void *instance, const char *pName) {
    if (is_reshade_disabled() || is_launcher_or_helper()) return NULL;
    init_real_reshade();
    if (!real_gipa && real_func) {
        VkNegotiateLoaderLayerInterfaceVersion vstruct;
        memset(&vstruct, 0, sizeof(vstruct));
        vstruct.sType = 1;
        vstruct.loaderLayerInterfaceVersion = 2;
        if (real_func(&vstruct) == 0 && vstruct.pfnGetInstanceProcAddr) {
            real_gipa = (PFN_vkGetInstanceProcAddr)vstruct.pfnGetInstanceProcAddr;
        }
    }
    return hook_vkGetInstanceProcAddr(instance, pName);
}
