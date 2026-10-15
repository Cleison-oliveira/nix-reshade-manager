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

#define DEFAULT_OVERLAY_DOCKING \
    "Docking=[Docking][Data],DockSpace   ID=0xB0DF600F Pos=8,,8 Size=1904,,1064 Split=X,  DockNode  ID=0x00000001 Parent=0xB0DF600F SizeRef=671,,1080 Selected=0x2863d5fc,  DockNode  ID=0x00000002 Parent=0xB0DF600F SizeRef=1247,,1080 CentralNode=1\n"

#define DEFAULT_OVERLAY_WINDOW \
    "Window=[Window][Debug##Default],Pos=60,,60,Size=400,,400,Collapsed=0,[Window][Home###home],Pos=8,,8,Size=671,,1064,Collapsed=0,DockId=0x00000001,,0,[Window][Add-ons###addons],Pos=8,,8,Size=671,,1064,Collapsed=0,DockId=0x00000001,,1,[Window][Settings###settings],Pos=8,,8,Size=671,,1064,Collapsed=0,DockId=0x00000001,,2,[Window][Statistics###statistics],Pos=8,,8,Size=671,,1064,Collapsed=0,DockId=0x00000001,,3,[Window][Log###log],Pos=8,,8,Size=671,,1064,Collapsed=0,DockId=0x00000001,,4,[Window][About###about],Pos=8,,8,Size=671,,1064,Collapsed=0,DockId=0x00000001,,5,[Window][###editor],Collapsed=0,DockId=0x00000002,[Window][Viewport],Size=1920,,1080,Collapsed=0\n"

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

static void mkdir_p(const char *dir) {
    if (!dir || dir[0] == '\0') return;
    char tmp[1024];
    snprintf(tmp, sizeof(tmp), "%s", dir);
    size_t len = strlen(tmp);
    if (len == 0) return;
    if (tmp[len - 1] == '/') tmp[len - 1] = '\0';
    for (char *p = tmp + 1; *p; p++) {
        if (*p == '/') {
            *p = '\0';
            mkdir(tmp, 0775);
            *p = '/';
        }
    }
    mkdir(tmp, 0775);
}

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
    mkdir_p(dir);
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

static void get_wine_guest_exe(char *out_guest, size_t out_len) {
    if (!out_guest || out_len == 0) return;
    out_guest[0] = '\0';

    FILE *f = fopen("/proc/self/cmdline", "rb");
    if (!f) return;

    char cmd[4096] = {0};
    size_t rd = fread(cmd, 1, sizeof(cmd) - 1, f);
    fclose(f);
    if (rd == 0) return;

    size_t pos = 0;
    while (pos < rd) {
        const char *arg = cmd + pos;
        size_t arg_len = strlen(arg);
        if (arg_len >= 4) {
            char lower_arg[512] = {0};
            size_t cplen = arg_len < sizeof(lower_arg) - 1 ? arg_len : sizeof(lower_arg) - 1;
            for (size_t i = 0; i < cplen; i++) {
                lower_arg[i] = (char)tolower((unsigned char)arg[i]);
            }
            char *exe_pos = strstr(lower_arg, ".exe");
            if (exe_pos != NULL) {
                size_t exe_end = (size_t)(exe_pos - lower_arg) + 4;
                char temp[512] = {0};
                if (exe_end >= sizeof(temp)) exe_end = sizeof(temp) - 1;
                memcpy(temp, arg, exe_end);
                temp[exe_end] = '\0';
                const char *base = get_basename(temp);
                if (strcasecmp(base, "wine.exe") != 0 &&
                    strcasecmp(base, "wine64.exe") != 0 &&
                    strcasecmp(base, "wineserver.exe") != 0) {
                    snprintf(out_guest, out_len, "%s", base);
                    return;
                }
            }
        }
        pos += arg_len + 1;
    }
}

static int is_launcher_or_helper(void) {
    char exe_path[1024] = {0};
    ssize_t n = readlink("/proc/self/exe", exe_path, sizeof(exe_path) - 1);
    if (n <= 0) return 0;
    exe_path[n] = '\0';

    const char *base = get_basename(exe_path);
    char lower_exe[256] = {0};
    size_t elen = strlen(base);
    if (elen >= sizeof(lower_exe)) elen = sizeof(lower_exe) - 1;
    for (size_t i = 0; i < elen; i++) {
        lower_exe[i] = (char)tolower((unsigned char)base[i]);
    }
    lower_exe[elen] = '\0';

    // 1. Native Linux launchers and wrappers
    if (strcmp(lower_exe, "heroic") == 0 ||
        strcmp(lower_exe, "lutris") == 0 ||
        strcmp(lower_exe, "heronite") == 0 ||
        strcmp(lower_exe, "steam") == 0 ||
        strcmp(lower_exe, "steamwebhelper") == 0 ||
        strcmp(lower_exe, "epicwebhelper") == 0 ||
        strcmp(lower_exe, "gamescope") == 0 ||
        strcmp(lower_exe, "gamemoded") == 0 ||
        strcmp(lower_exe, "faugus") == 0 ||
        strcmp(lower_exe, "bottles") == 0 ||
        strcmp(lower_exe, "umu-run") == 0) {
        return 1;
    }

    // 2. Wine / Proton process checks
    if (strstr(lower_exe, "wine") != NULL) {
        char guest_exe[256] = {0};
        get_wine_guest_exe(guest_exe, sizeof(guest_exe));
        if (guest_exe[0] != '\0') {
            char lower_guest[256] = {0};
            size_t glen = strlen(guest_exe);
            if (glen >= sizeof(lower_guest)) glen = sizeof(lower_guest) - 1;
            for (size_t i = 0; i < glen; i++) {
                lower_guest[i] = (char)tolower((unsigned char)guest_exe[i]);
            }
            lower_guest[glen] = '\0';

            // Windows / Wine system background processes
            if (strcmp(lower_guest, "explorer.exe") == 0 ||
                strcmp(lower_guest, "xalia.exe") == 0 ||
                strcmp(lower_guest, "services.exe") == 0 ||
                strcmp(lower_guest, "svchost.exe") == 0 ||
                strcmp(lower_guest, "winedevice.exe") == 0 ||
                strcmp(lower_guest, "plugplay.exe") == 0 ||
                strcmp(lower_guest, "conhost.exe") == 0 ||
                strcmp(lower_guest, "cmd.exe") == 0 ||
                strcmp(lower_guest, "rundll32.exe") == 0 ||
                strcmp(lower_guest, "dxsetup.exe") == 0 ||
                strcmp(lower_guest, "start.exe") == 0 ||
                strcmp(lower_guest, "rpcss.exe") == 0 ||
                strcmp(lower_guest, "wineboot.exe") == 0) {
                return 1;
            }

            // Diagnostic, crash reporter, web helper and anti-cheat stubs
            if (strstr(lower_guest, "crashreport") != NULL ||
                strstr(lower_guest, "crashhandler") != NULL ||
                strstr(lower_guest, "bugreport") != NULL ||
                strstr(lower_guest, "socialclub") != NULL ||
                strstr(lower_guest, "cefsubprocess") != NULL ||
                strstr(lower_guest, "webhelper") != NULL ||
                strstr(lower_guest, "easyanticheat") != NULL ||
                strstr(lower_guest, "start_protected_game") != NULL ||
                strstr(lower_guest, "beservice") != NULL) {
                return 1;
            }

            // Game launchers and wrappers (unless explicitly allowed via RESHADE_ALLOW_LAUNCHER=1)
            const char *allow_launcher = getenv("RESHADE_ALLOW_LAUNCHER");
            if (!allow_launcher || allow_launcher[0] == '\0' || strcmp(allow_launcher, "0") == 0) {
                if (strstr(lower_guest, "launcher") != NULL ||
                    strstr(lower_guest, "updater") != NULL ||
                    strstr(lower_guest, "patcher") != NULL ||
                    strcmp(lower_guest, "dowser.exe") == 0 ||
                    strcmp(lower_guest, "upc.exe") == 0 ||
                    strcmp(lower_guest, "battle.net.exe") == 0 ||
                    strcmp(lower_guest, "eadesktop.exe") == 0 ||
                    strcmp(lower_guest, "origin.exe") == 0 ||
                    strcmp(lower_guest, "galaxyclient.exe") == 0 ||
                    strcmp(lower_guest, "epicgameslauncher.exe") == 0) {
                    return 1;
                }
            }
        }
    }

    return 0;
}

static void sanitize_name(char *dst, const char *src, size_t max_len) {
    if (!dst || max_len == 0) return;
    dst[0] = '\0';
    if (!src || src[0] == '\0') {
        snprintf(dst, max_len, "application");
        return;
    }

    size_t out_idx = 0;
    int last_was_underscore = 0;

    for (size_t i = 0; src[i] != '\0' && out_idx + 1 < max_len; i++) {
        unsigned char c = (unsigned char)src[i];
        if (c < 0x80 && !isalnum(c) && c != '-' && c != '_') {
            c = '_';
        }
        if (c == '_') {
            if (out_idx == 0 || last_was_underscore) {
                continue;
            }
            last_was_underscore = 1;
        } else {
            last_was_underscore = 0;
        }
        dst[out_idx++] = (char)c;
    }

    while (out_idx > 0 && dst[out_idx - 1] == '_') {
        out_idx--;
    }
    dst[out_idx] = '\0';

    if (dst[0] == '\0') {
        snprintf(dst, max_len, "application");
    }
}

static int is_generic_dir_name(const char *name) {
    if (!name || name[0] == '\0') return 1;
    char lower[64] = {0};
    size_t len = strlen(name);
    if (len >= sizeof(lower)) len = sizeof(lower) - 1;
    for (size_t i = 0; i < len; i++) lower[i] = (char)tolower((unsigned char)name[i]);
    lower[len] = '\0';

    return (strcmp(lower, "pfx") == 0 ||
            strcmp(lower, "prefix") == 0 ||
            strcmp(lower, "default") == 0 ||
            strcmp(lower, "pc") == 0 ||
            strcmp(lower, "bin") == 0 ||
            strcmp(lower, "binaries") == 0 ||
            strcmp(lower, "bin64") == 0 ||
            strcmp(lower, "bin32") == 0 ||
            strcmp(lower, "x64") == 0 ||
            strcmp(lower, "x86") == 0 ||
            strcmp(lower, "win64") == 0 ||
            strcmp(lower, "win32") == 0 ||
            strcmp(lower, "shipping") == 0 ||
            strcmp(lower, "retail") == 0 ||
            strcmp(lower, "system") == 0 ||
            strcmp(lower, "game") == 0 ||
            strcmp(lower, "games") == 0);
}

static const char *get_path_label(const char *path, char *buf, size_t buf_len) {
    if (!path || path[0] == '\0' || !buf || buf_len == 0) return "";
    buf[0] = '\0';
    char tmp[1024];
    snprintf(tmp, sizeof(tmp), "%s", path);
    size_t len = strlen(tmp);
    while (len > 1 && (tmp[len - 1] == '/' || tmp[len - 1] == '\\')) {
        tmp[--len] = '\0';
    }
    const char *base = get_basename(tmp);
    while (is_generic_dir_name(base)) {
        char *p = strrchr(tmp, '/');
        if (!p) p = strrchr(tmp, '\\');
        if (!p) break;
        *p = '\0';
        base = get_basename(tmp);
    }
    snprintf(buf, buf_len, "%s", base);
    return buf;
}

static void resolve_profile_name(char *out_profile, size_t max_len) {
    if (!out_profile || max_len == 0) return;
    out_profile[0] = '\0';

    const char *env_prof = getenv("RESHADE_PROFILE");
    if (env_prof && env_prof[0] != '\0') {
        sanitize_name(out_profile, env_prof, max_len);
        return;
    }

    char exe_path[1024] = {0};
    ssize_t n = readlink("/proc/self/exe", exe_path, sizeof(exe_path) - 1);
    if (n > 0) exe_path[n] = '\0';
    const char *linux_base = get_basename(exe_path);

    char lower_linux[256] = {0};
    size_t elen = strlen(linux_base);
    if (elen >= sizeof(lower_linux)) elen = sizeof(lower_linux) - 1;
    for (size_t i = 0; i < elen; i++) lower_linux[i] = (char)tolower((unsigned char)linux_base[i]);

    int is_wine = (strstr(lower_linux, "wine") != NULL);

    const char *steam_compat = getenv("STEAM_COMPAT_INSTALL_PATH");
    const char *steam_app_id = getenv("SteamAppId");
    const char *wine_prefix = getenv("WINEPREFIX");

    char raw_label[512] = {0};

    if (is_wine) {
        char pfx_label[256] = {0};
        if (steam_compat && steam_compat[0] != '\0') {
            get_path_label(steam_compat, raw_label, sizeof(raw_label));
        }
        if (raw_label[0] == '\0') {
            char guest_exe[256] = {0};
            get_wine_guest_exe(guest_exe, sizeof(guest_exe));
            if (guest_exe[0] != '\0') {
                char *dot = strrchr(guest_exe, '.');
                if (dot) *dot = '\0';
                snprintf(raw_label, sizeof(raw_label), "%s", guest_exe);
            }
        }
        if (raw_label[0] == '\0') {
            snprintf(raw_label, sizeof(raw_label), "%s", linux_base);
        }

        char sanitized_label[256];
        sanitize_name(sanitized_label, raw_label, sizeof(sanitized_label));

        if (steam_app_id && steam_app_id[0] != '\0' && strcmp(steam_app_id, "0") != 0) {
            char sanitized_suffix[128];
            sanitize_name(sanitized_suffix, steam_app_id, sizeof(sanitized_suffix));
            snprintf(out_profile, max_len, "%s-%s", sanitized_label, sanitized_suffix);
        } else if (wine_prefix && wine_prefix[0] != '\0') {
            get_path_label(wine_prefix, pfx_label, sizeof(pfx_label));
            if (strcmp(pfx_label, ".wine") != 0 && pfx_label[0] != '\0') {
                char sanitized_suffix[128];
                sanitize_name(sanitized_suffix, pfx_label, sizeof(sanitized_suffix));
                snprintf(out_profile, max_len, "%s-%s", sanitized_label, sanitized_suffix);
            } else {
                snprintf(out_profile, max_len, "%s", sanitized_label);
            }
        } else {
            snprintf(out_profile, max_len, "%s", sanitized_label);
        }
        return;
    }

    if (steam_app_id && steam_app_id[0] != '\0' && steam_compat && steam_compat[0] != '\0') {
        char base_label[256], sanitized_base[256], sanitized_suffix[128];
        get_path_label(steam_compat, base_label, sizeof(base_label));
        sanitize_name(sanitized_base, base_label, sizeof(sanitized_base));
        sanitize_name(sanitized_suffix, steam_app_id, sizeof(sanitized_suffix));
        snprintf(out_profile, max_len, "%s-%s", sanitized_base, sanitized_suffix);
        return;
    }

    char sanitized_base[256];
    sanitize_name(sanitized_base, linux_base, sizeof(sanitized_base));
    if (steam_app_id && steam_app_id[0] != '\0' && strcmp(steam_app_id, "0") != 0) {
        char sanitized_suffix[128];
        sanitize_name(sanitized_suffix, steam_app_id, sizeof(sanitized_suffix));
        snprintf(out_profile, max_len, "%s-%s", sanitized_base, sanitized_suffix);
    } else {
        snprintf(out_profile, max_len, "%s", sanitized_base);
    }
}

static void ensure_directories_and_preset(const char *profile_dir) {
    if (!profile_dir || profile_dir[0] == '\0') return;

    mkdir_p(profile_dir);

    const char *cache_root = getenv("XDG_CACHE_HOME");
    char cache_dir[1024];
    if (cache_root && cache_root[0] != '\0') {
        snprintf(cache_dir, sizeof(cache_dir), "%s/reshade", cache_root);
    } else {
        const char *home = getenv("HOME");
        snprintf(cache_dir, sizeof(cache_dir), "%s/.cache/reshade", home ? home : "");
    }
    mkdir_p(cache_dir);

    const char *home = getenv("HOME");
    if (home && home[0] != '\0') {
        char user_s[1024], user_t[1024];
        snprintf(user_s, sizeof(user_s), "%s/.local/share/reshade/reshade-shaders/Shaders", home);
        snprintf(user_t, sizeof(user_t), "%s/.local/share/reshade/reshade-shaders/Textures", home);
        mkdir_p(user_s);
        mkdir_p(user_t);
    }

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

static void write_sanitized_paths(FILE *out, const char *prefix, const char *line_val, const char *primary_path, const char *user_fallback) {
    fprintf(out, "%s%s", prefix, primary_path);
    if (line_val && *line_val) {
        char buf[4096];
        snprintf(buf, sizeof(buf), "%s", line_val);
        char *tok_save = NULL;
        char *tok = strtok_r(buf, ",", &tok_save);
        while (tok) {
            while (*tok == ' ' || *tok == '\t') tok++;
            int is_nix = (strncmp(tok, "/nix/store/", 11) == 0);
            int is_cur = (strstr(tok, primary_path) != NULL || strstr(primary_path, tok) != NULL);
            if (!is_nix && !is_cur && *tok) {
                fprintf(out, ",%s", tok);
            }
            tok = strtok_r(NULL, ",", &tok_save);
        }
    } else if (user_fallback && *user_fallback) {
        fprintf(out, ",%s", user_fallback);
    }
    fprintf(out, "\n");
}

static int check_has_about_selected(const char *content) {
    if (!content) return 0;
    const char *p = content;
    while ((p = strstr(p, "Selected=0x")) != NULL) {
        const char *hash = p + 9;
        if (strncasecmp(hash, "0xD094CE70", 10) == 0 ||
            strncasecmp(hash, "0x87856c2f", 10) == 0 ||
            strncasecmp(hash, "0xCBCD3A85", 10) == 0 ||
            strncasecmp(hash, "0x63E5D1F5", 10) == 0) {
            return 1;
        }
        p += 19;
    }
    return 0;
}

static void sanitize_docking_line(FILE *out, const char *line) {
    char buf[4096];
    snprintf(buf, sizeof(buf), "%s", line);
    char *p = buf;
    while ((p = strstr(p, "Selected=0x")) != NULL) {
        char *hash = p + 9;
        if (strncasecmp(hash, "0xD094CE70", 10) == 0 ||
            strncasecmp(hash, "0x87856c2f", 10) == 0 ||
            strncasecmp(hash, "0xCBCD3A85", 10) == 0 ||
            strncasecmp(hash, "0x63E5D1F5", 10) == 0) {
            memcpy(hash, "0x2863d5fc", 10);
        }
        p += 19;
    }
    fprintf(out, "%s\n", buf);
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
            DEFAULT_OVERLAY_DOCKING
            "TutorialProgress=4\n"
            DEFAULT_OVERLAY_WINDOW,
            home, cache_dir, preset_path, home
        );
        fclose(out);
        chmod(ini_path, 0664);
        return;
    }

    // File exists: inspect without touching custom user settings
    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (sz <= 0 || sz > 2 * 1024 * 1024) { fclose(f); return; }

    char *content = malloc(sz + 1);
    if (!content) { fclose(f); return; }
    size_t rd = fread(content, 1, sz, f);
    fclose(f);
    content[rd] = '\0';

    int has_valid_docking = (strstr(content, "DockNode") != NULL && strstr(content, "Selected=") != NULL);
    int has_about_selected = check_has_about_selected(content);
    int has_valid_window = (strstr(content, "###home") != NULL);

    int has_old_nix_store = 0;
    const char *ps = content;
    while ((ps = strstr(ps, "/nix/store/")) != NULL) {
        if (strncmp(ps, "@NIX_RESHADE_SHADERS@", strlen("@NIX_RESHADE_SHADERS@")) != 0 &&
            strncmp(ps, "@NIX_RESHADE_TEXTURES@", strlen("@NIX_RESHADE_TEXTURES@")) != 0) {
            has_old_nix_store = 1;
            break;
        }
        ps += 11;
    }

    int has_input_section = (strstr(content, "[INPUT]") != NULL);
    int has_fallback_key_overlay = (strstr(content, "KeyOverlay=36,0,0,0") != NULL && strcmp(DEFAULT_KEY_OVERLAY, "36,0,0,0") != 0);
    int has_zero_key_effects = (strstr(content, "KeyEffects=0,0,0,0") != NULL && strcmp(DEFAULT_KEY_EFFECTS, "0,0,0,0") != 0);

    int needs_fix = 0;
    if (strstr(content, "@NIX_RESHADE_SHADERS@") == NULL || has_old_nix_store) {
        needs_fix = 1;
    }
    if (strstr(content, "PresetPath=./ReShadePreset.ini") != NULL) {
        needs_fix = 1;
    }
    if (!has_valid_docking || has_about_selected || !has_valid_window) {
        needs_fix = 1;
    }
    if (!has_input_section || has_fallback_key_overlay || has_zero_key_effects) {
        needs_fix = 1;
    }

    if (!needs_fix) {
        free(content);
        chmod(ini_path, 0664);
        return;
    }

    char tmp_path[1024];
    snprintf(tmp_path, sizeof(tmp_path), "%s.tmp", ini_path);
    FILE *out = fopen(tmp_path, "w");
    if (!out) { free(content); return; }

    int has_overlay_section = (strstr(content, "[OVERLAY]") != NULL);
    int has_docking_line = (strstr(content, "Docking=") != NULL);
    int has_window_line = (strstr(content, "Window=") != NULL);
    int has_tutorial = (strstr(content, "TutorialProgress=") != NULL);

    char *saveptr = NULL;
    char *line = strtok_r(content, "\r\n", &saveptr);
    int in_general = 0;
    int in_input = 0;

    while (line) {
        if (strcmp(line, "[GENERAL]") == 0) {
            in_general = 1;
            in_input = 0;
            fprintf(out, "%s\n", line);
            line = strtok_r(NULL, "\r\n", &saveptr);
            continue;
        }
        if (strcmp(line, "[INPUT]") == 0) {
            in_input = 1;
            in_general = 0;
            fprintf(out, "%s\n", line);
            line = strtok_r(NULL, "\r\n", &saveptr);
            continue;
        }
        if (strcmp(line, "[OVERLAY]") == 0) {
            in_general = 0;
            in_input = 0;
            fprintf(out, "%s\n", line);
            if (!has_docking_line) {
                fputs(DEFAULT_OVERLAY_DOCKING, out);
            }
            if (!has_tutorial) {
                fputs("TutorialProgress=4\n", out);
            }
            if (!has_window_line) {
                fputs(DEFAULT_OVERLAY_WINDOW, out);
            }
            line = strtok_r(NULL, "\r\n", &saveptr);
            continue;
        }
        if (line[0] == '[') {
            in_general = 0;
            in_input = 0;
        }

        if (in_general) {
            if (strncmp(line, "EffectSearchPaths=", 18) == 0) {
                char user_def[1024];
                snprintf(user_def, sizeof(user_def), "%s/.local/share/reshade/reshade-shaders/Shaders/**", home);
                write_sanitized_paths(out, "EffectSearchPaths=", line + 18, "@NIX_RESHADE_SHADERS@/**", user_def);
                line = strtok_r(NULL, "\r\n", &saveptr);
                continue;
            }
            if (strncmp(line, "TextureSearchPaths=", 19) == 0) {
                char user_def[1024];
                snprintf(user_def, sizeof(user_def), "%s/.local/share/reshade/reshade-shaders/Textures/**", home);
                write_sanitized_paths(out, "TextureSearchPaths=", line + 19, "@NIX_RESHADE_TEXTURES@/**", user_def);
                line = strtok_r(NULL, "\r\n", &saveptr);
                continue;
            }
            if (strncmp(line, "PresetPath=./ReShadePreset.ini", 30) == 0) {
                fprintf(out, "PresetPath=%s\n", preset_path);
                line = strtok_r(NULL, "\r\n", &saveptr);
                continue;
            }
        }

        if (in_input) {
            if (has_fallback_key_overlay && strncmp(line, "KeyOverlay=36,0,0,0", 19) == 0) {
                fprintf(out, "KeyOverlay=%s\n", DEFAULT_KEY_OVERLAY);
                line = strtok_r(NULL, "\r\n", &saveptr);
                continue;
            }
            if (has_zero_key_effects && strncmp(line, "KeyEffects=0,0,0,0", 18) == 0) {
                fprintf(out, "KeyEffects=%s\n", DEFAULT_KEY_EFFECTS);
                line = strtok_r(NULL, "\r\n", &saveptr);
                continue;
            }
        }

        // Handle Docking= line
        if (strncmp(line, "Docking=", 8) == 0) {
            if (!has_valid_docking) {
                fputs(DEFAULT_OVERLAY_DOCKING, out);
                line = strtok_r(NULL, "\r\n", &saveptr);
                continue;
            }
            sanitize_docking_line(out, line);
            line = strtok_r(NULL, "\r\n", &saveptr);
            continue;
        }

        // Handle Window= line
        if (strncmp(line, "Window=", 7) == 0) {
            if (!has_valid_window || !has_valid_docking) {
                fputs(DEFAULT_OVERLAY_WINDOW, out);
                line = strtok_r(NULL, "\r\n", &saveptr);
                continue;
            }
        }

        fprintf(out, "%s\n", line);
        line = strtok_r(NULL, "\r\n", &saveptr);
    }

    if (!has_input_section) {
        fprintf(out,
            "\n[INPUT]\n"
            "KeyEffects=" DEFAULT_KEY_EFFECTS "\n"
            "KeyOverlay=" DEFAULT_KEY_OVERLAY "\n"
        );
    }

    if (!has_overlay_section) {
        fprintf(out,
            "\n[OVERLAY]\n"
            "AutoSavePreset=1\n"
            DEFAULT_OVERLAY_DOCKING
            "TutorialProgress=4\n"
            DEFAULT_OVERLAY_WINDOW
        );
    }

    fclose(out);
    free(content);
    rename(tmp_path, ini_path);
    chmod(ini_path, 0664);
}

static void scan_configs_in_dir(const char *configs_dir) {
    if (!configs_dir || configs_dir[0] == '\0') return;
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

static void scan_and_standardize_configs(void) {
    const char *xdg = getenv("XDG_DATA_HOME");
    if (xdg && xdg[0] != '\0') {
        char dir[1024];
        snprintf(dir, sizeof(dir), "%s/reshade/configurations", xdg);
        scan_configs_in_dir(dir);
    }
    const char *home = getenv("HOME");
    if (home && home[0] != '\0') {
        char dir[1024];
        snprintf(dir, sizeof(dir), "%s/.local/share/reshade/configurations", home);
        scan_configs_in_dir(dir);
    }
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

    if (is_reshade_disabled()) {
        log_debug("[ReShade Filter] PID %d (%s | %s): Ignored (ReShade explicitly disabled)\n", getpid(), exe, cmd);
        return -3;
    }

    log_debug("[ReShade Filter] PID %d (%s | %s): Negotiating interface version %u...\n",
              getpid(), exe, cmd, pVersionStruct ? pVersionStruct->loaderLayerInterfaceVersion : 0);

    // Pre-initialize and standardize profile for the resolved game profile
    char profile_name[256] = {0};
    resolve_profile_name(profile_name, sizeof(profile_name));
    if (profile_name[0] != '\0') {
        const char *xdg = getenv("XDG_DATA_HOME");
        char pdir[1024], ini[1024];
        if (xdg && xdg[0] != '\0') {
            snprintf(pdir, sizeof(pdir), "%s/reshade/configurations/%s", xdg, profile_name);
            snprintf(ini, sizeof(ini), "%s/ReShade.ini", pdir);
            setup_profile_ini(ini, pdir);
        }
        const char *home = getenv("HOME");
        if (home && home[0] != '\0') {
            snprintf(pdir, sizeof(pdir), "%s/.local/share/reshade/configurations/%s", home, profile_name);
            snprintf(ini, sizeof(ini), "%s/ReShade.ini", pdir);
            setup_profile_ini(ini, pdir);
        }
    }

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
    if (is_reshade_disabled()) return NULL;
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
