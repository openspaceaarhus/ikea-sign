#ifndef OPENGL_H
#define OPENGL_H

#ifdef USE_OPENGL
#include <SDL_opengl.h>
#else
#include <SDL_opengles.h>
#endif

#include <SDL.h>

struct SDL_Surface;
struct SDL_Rect;

bool opengl_init();
void opengl_swap();
Uint32 nextPowerOfTwo(Uint32 size);
GLuint opengl_create_texture_8888(SDL_Surface *surface, Uint32 *pWidth, Uint32 *pHeight);
GLuint opengl_create_texture_5551(SDL_Surface *surface, Uint32 *pWidth, Uint32 *pHeight);
void opengl_blit(GLuint texture_id, SDL_Rect *dst_pos);
void opengl_blit_reverse(GLuint texture_id, SDL_Rect *dst_pos);
void opengl_blit(GLuint texture_id, GLfloat texCoords[8], SDL_Rect *dst_pos);
bool opengl_clear();
void opengl_start_transition(bool direction);

#endif
