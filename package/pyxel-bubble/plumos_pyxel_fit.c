#define _GNU_SOURCE

#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

typedef unsigned int GLuint;
typedef int GLint;
typedef struct SDL_Window SDL_Window;
typedef void *(*SDLGLGetProcAddress)(const char *name);
typedef int (*SDLGLSetAttribute)(int attr, int value);
typedef void *(*SDLGLCreateContext)(SDL_Window *window);
typedef int (*SDLGLMakeCurrent)(SDL_Window *window, void *context);
typedef void (*SDLGLSwapWindow)(SDL_Window *window);
typedef const char *(*SDLGetError)(void);
typedef SDL_Window *(*SDLCreateWindow)(const char *title, int x, int y,
                                       int width, int height,
                                       unsigned int flags);
typedef void (*GLUseProgram)(GLuint program);
typedef GLint (*GLGetUniformLocation)(GLuint program, const char *name);
typedef void (*GLUniform1f)(GLint location, float value);
typedef void (*GLUniform2f)(GLint location, float x, float y);

enum { MAX_PROGRAMS = 32 };

struct program_state {
    GLuint program;
    GLint screen_pos;
    GLint screen_size;
    GLint screen_scale;
    int has_source_size;
    float screen_x;
    float screen_y;
    float fit_factor;
};

static SDLGLGetProcAddress real_sdl_gl_get_proc_address;
static SDLGLSetAttribute real_sdl_gl_set_attribute;
static SDLGLCreateContext real_sdl_gl_create_context;
static SDLGLMakeCurrent real_sdl_gl_make_current;
static SDLGLSwapWindow real_sdl_gl_swap_window;
static SDLGetError real_sdl_get_error;
static void *gles_handle;
static SDLCreateWindow real_sdl_create_window;
static GLUseProgram real_gl_use_program;
static GLGetUniformLocation real_gl_get_uniform_location;
static GLUniform1f real_gl_uniform_1f;
static GLUniform2f real_gl_uniform_2f;
static struct program_state programs[MAX_PROGRAMS];
static GLuint current_program;
static int fit_enabled = -1;
static float output_width = 640.0f;
static float output_height = 480.0f;
static int fit_reported;
static int frame_stats_enabled = -1;
static unsigned long frame_stats_swaps;
static struct timespec frame_stats_started;

enum {
    SDL_GL_CONTEXT_MAJOR_VERSION = 17,
    SDL_GL_CONTEXT_MINOR_VERSION = 18,
    SDL_GL_CONTEXT_EGL = 19,
    SDL_GL_CONTEXT_PROFILE_MASK = 21,
    SDL_GL_CONTEXT_PROFILE_ES = 0x0004
};

static int env_enabled(const char *name, int default_value)
{
    const char *value = getenv(name);

    if (!value || !value[0]) {
        return default_value;
    }
    return strcmp(value, "0") != 0 && strcasecmp(value, "false") != 0 &&
           strcasecmp(value, "no") != 0;
}

static float env_dimension(const char *name, float default_value)
{
    const char *value = getenv(name);
    char *end = NULL;
    float parsed;

    if (!value || !value[0]) {
        return default_value;
    }
    parsed = strtof(value, &end);
    return end != value && parsed > 0.0f ? parsed : default_value;
}

static void init_config(void)
{
    if (fit_enabled >= 0) {
        return;
    }
    fit_enabled = env_enabled("PLUMOS_PYXEL_FIT", 1);
    output_width = env_dimension("PLUMOS_PYXEL_FIT_WIDTH", 640.0f);
    output_height = env_dimension("PLUMOS_PYXEL_FIT_HEIGHT", 480.0f);
    gles_handle = dlopen(getenv("PLUMOS_PYXEL_GLES_LIBRARY") ?: "libGLESv2.so.2",
                         RTLD_NOW | RTLD_LOCAL);
}

static void force_gles2_attributes(void)
{
    if (!real_sdl_gl_set_attribute) {
        real_sdl_gl_set_attribute =
            (SDLGLSetAttribute)dlsym(RTLD_NEXT, "SDL_GL_SetAttribute");
    }
    if (!real_sdl_gl_set_attribute) {
        return;
    }
    real_sdl_gl_set_attribute(SDL_GL_CONTEXT_PROFILE_MASK,
                              SDL_GL_CONTEXT_PROFILE_ES);
    real_sdl_gl_set_attribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2);
    real_sdl_gl_set_attribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);
    real_sdl_gl_set_attribute(SDL_GL_CONTEXT_EGL, 1);
}

int SDL_GL_SetAttribute(int attr, int value)
{
    if (!real_sdl_gl_set_attribute) {
        real_sdl_gl_set_attribute =
            (SDLGLSetAttribute)dlsym(RTLD_NEXT, "SDL_GL_SetAttribute");
    }
    if (!real_sdl_gl_set_attribute) {
        return -1;
    }
    if (attr == SDL_GL_CONTEXT_PROFILE_MASK) {
        value = SDL_GL_CONTEXT_PROFILE_ES;
    } else if (attr == SDL_GL_CONTEXT_MAJOR_VERSION) {
        value = 2;
    } else if (attr == SDL_GL_CONTEXT_MINOR_VERSION) {
        value = 0;
    } else if (attr == SDL_GL_CONTEXT_EGL) {
        value = 1;
    }
    return real_sdl_gl_set_attribute(attr, value);
}

SDL_Window *SDL_CreateWindow(const char *title, int x, int y, int width,
                             int height, unsigned int flags)
{
    if (!real_sdl_create_window) {
        real_sdl_create_window =
            (SDLCreateWindow)dlsym(RTLD_NEXT, "SDL_CreateWindow");
    }
    if (!real_sdl_create_window) {
        return NULL;
    }
    force_gles2_attributes();
    fprintf(stderr,
            "plumos-pyxel-display: backend=kmsdrm api=gles2 source=%dx%d\n",
            width, height);
    return real_sdl_create_window(title, x, y, width, height, flags);
}

void *SDL_GL_CreateContext(SDL_Window *window)
{
    void *context;
    int current_rc = -1;

    if (!real_sdl_gl_create_context) {
        real_sdl_gl_create_context =
            (SDLGLCreateContext)dlsym(RTLD_NEXT, "SDL_GL_CreateContext");
    }
    if (!real_sdl_gl_make_current) {
        real_sdl_gl_make_current =
            (SDLGLMakeCurrent)dlsym(RTLD_NEXT, "SDL_GL_MakeCurrent");
    }
    if (!real_sdl_get_error) {
        real_sdl_get_error = (SDLGetError)dlsym(RTLD_NEXT, "SDL_GetError");
    }
    if (!real_sdl_gl_create_context) {
        return NULL;
    }
    force_gles2_attributes();
    context = real_sdl_gl_create_context(window);
    if (context && real_sdl_gl_make_current) {
        current_rc = real_sdl_gl_make_current(window, context);
    }
    fprintf(stderr,
            "plumos-pyxel-display: context=%s make-current=%d%s%s\n",
            context ? "created" : "failed", current_rc,
            (!context || current_rc) && real_sdl_get_error ? " error=" : "",
            (!context || current_rc) && real_sdl_get_error
                ? real_sdl_get_error()
                : "");
    return context;
}

void SDL_GL_SwapWindow(SDL_Window *window)
{
    struct timespec now;
    double elapsed;

    if (!real_sdl_gl_swap_window) {
        real_sdl_gl_swap_window =
            (SDLGLSwapWindow)dlsym(RTLD_NEXT, "SDL_GL_SwapWindow");
    }
    if (!real_sdl_gl_swap_window) {
        return;
    }
    real_sdl_gl_swap_window(window);
    if (frame_stats_enabled < 0) {
        frame_stats_enabled = env_enabled("PLUMOS_PYXEL_FRAME_STATS", 0);
        if (frame_stats_enabled) {
            clock_gettime(CLOCK_MONOTONIC, &frame_stats_started);
        }
    }
    if (!frame_stats_enabled) {
        return;
    }
    ++frame_stats_swaps;
    clock_gettime(CLOCK_MONOTONIC, &now);
    elapsed = (double)(now.tv_sec - frame_stats_started.tv_sec) +
              (double)(now.tv_nsec - frame_stats_started.tv_nsec) / 1000000000.0;
    if (elapsed >= 5.0) {
        fprintf(stderr,
                "plumos-pyxel-frame: swaps=%lu elapsed=%.3f fps=%.3f\n",
                frame_stats_swaps, elapsed, frame_stats_swaps / elapsed);
        frame_stats_swaps = 0;
        frame_stats_started = now;
    }
}

static struct program_state *program_state(GLuint program, int create)
{
    struct program_state *free_slot = NULL;
    int i;

    for (i = 0; i < MAX_PROGRAMS; ++i) {
        if (programs[i].program == program) {
            return &programs[i];
        }
        if (!programs[i].program && !free_slot) {
            free_slot = &programs[i];
        }
    }
    if (!create || !free_slot || !program) {
        return NULL;
    }
    free_slot->program = program;
    free_slot->screen_pos = -1;
    free_slot->screen_size = -1;
    free_slot->screen_scale = -1;
    return free_slot;
}

static void fit_gl_use_program(GLuint program)
{
    current_program = program;
    real_gl_use_program(program);
}

static GLint fit_gl_get_uniform_location(GLuint program, const char *name)
{
    struct program_state *state;
    GLint location = real_gl_get_uniform_location(program, name);

    if (!name || location < 0) {
        return location;
    }
    state = program_state(program, 1);
    if (!state) {
        return location;
    }
    if (strcmp(name, "u_screenPos") == 0) {
        state->screen_pos = location;
    } else if (strcmp(name, "u_screenSize") == 0) {
        state->screen_size = location;
    } else if (strcmp(name, "u_screenScale") == 0) {
        state->screen_scale = location;
    }
    return location;
}

static void fit_gl_uniform_2f(GLint location, float x, float y)
{
    struct program_state *state = program_state(current_program, 0);

    if (state && location == state->screen_pos) {
        state->screen_x = x;
        state->screen_y = y;
    }
    if (fit_enabled && state && location == state->screen_size) {
        float factor = 1.0f;
        float fitted_width;
        float fitted_height;
        float fitted_x;
        float fitted_y;

        state->has_source_size = 1;
        if (x > output_width) {
            factor = output_width / x;
        }
        if (y * factor > output_height) {
            factor = output_height / y;
        }
        state->fit_factor = factor;
        fitted_width = x * factor;
        fitted_height = y * factor;
        fitted_x = factor < 1.0f - 0.0001f
                       ? (output_width - fitted_width) * 0.5f
                       : state->screen_x;
        fitted_y = factor < 1.0f - 0.0001f
                       ? (output_height - fitted_height) * 0.5f
                       : state->screen_y;
        if (!fit_reported) {
            fprintf(stderr,
                    "plumos-pyxel-fit: upstream=%.1f,%.1f %.0fx%.0f "
                    "output=%.0fx%.0f factor=%.6f offset=%.1f,%.1f\n",
                    state->screen_x, state->screen_y, x, y, fitted_width,
                    fitted_height, factor, fitted_x, fitted_y);
            fit_reported = 1;
        }
        if (factor < 1.0f - 0.0001f && state->screen_pos >= 0) {
            real_gl_uniform_2f(state->screen_pos, fitted_x, fitted_y);
            real_gl_uniform_2f(location, fitted_width, fitted_height);
            return;
        }
    }
    real_gl_uniform_2f(location, x, y);
}

static void fit_gl_uniform_1f(GLint location, float value)
{
    struct program_state *state = program_state(current_program, 0);

    if (!fit_enabled || !state || location != state->screen_scale ||
        !state->has_source_size || state->fit_factor >= 1.0f - 0.0001f ||
        state->fit_factor <= 0.0f || value <= 0.0f) {
        real_gl_uniform_1f(location, value);
        return;
    }
    real_gl_uniform_1f(location, value * state->fit_factor);
}

void *SDL_GL_GetProcAddress(const char *name)
{
    void *address;

    init_config();
    if (!real_sdl_gl_get_proc_address) {
        real_sdl_gl_get_proc_address =
            (SDLGLGetProcAddress)dlsym(RTLD_NEXT, "SDL_GL_GetProcAddress");
        if (!real_sdl_gl_get_proc_address) {
            return NULL;
        }
    }
    address = gles_handle && name ? dlsym(gles_handle, name) : NULL;
    if (!address) {
        address = real_sdl_gl_get_proc_address(name);
    }
    if (!fit_enabled || !name) {
        return address;
    }
    if (strcmp(name, "glUseProgram") == 0) {
        real_gl_use_program = (GLUseProgram)address;
        return (void *)fit_gl_use_program;
    }
    if (strcmp(name, "glGetUniformLocation") == 0) {
        real_gl_get_uniform_location = (GLGetUniformLocation)address;
        return (void *)fit_gl_get_uniform_location;
    }
    if (strcmp(name, "glUniform1f") == 0) {
        real_gl_uniform_1f = (GLUniform1f)address;
        return (void *)fit_gl_uniform_1f;
    }
    if (strcmp(name, "glUniform2f") == 0) {
        real_gl_uniform_2f = (GLUniform2f)address;
        return (void *)fit_gl_uniform_2f;
    }
    return address;
}
