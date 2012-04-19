#include <SDL.h>
#include "globals.h"
#include "opengl.h"

static SDL_Window *window;         /* main window */
static SDL_GLContext context;
static bool transition = false;
static int transition_w;
static int transition_delta;
static bool transition_direction;
static GLuint screenshot_tex;

bool opengl_init()
{
	transition_delta = screen_size_w / FPS * 3;

	SDL_GL_SetAttribute(SDL_GL_RED_SIZE, 5);
	SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE, 6);
	SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE, 5);
	SDL_GL_SetAttribute(SDL_GL_ALPHA_SIZE, 0);
	SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 0);
	SDL_GL_SetAttribute(SDL_GL_RETAINED_BACKING, 0);
	SDL_GL_SetAttribute(SDL_GL_ACCELERATED_VISUAL, 1);

	window = SDL_CreateWindow(NULL, 0, 0, screen_size_w, screen_size_h,
				  SDL_WINDOW_OPENGL | SDL_WINDOW_SHOWN |
				  SDL_WINDOW_BORDERLESS);

	context = SDL_GL_CreateContext(window);

	glDisable(GL_DEPTH_TEST);
	glDisable(GL_CULL_FACE);

	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();

	glViewport(0, 0, screen_size_w, screen_size_h);
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	 
#ifdef USE_OPENGL
	glOrtho(0,
		screen_size_w,
		screen_size_h,
		0, 0.0, 1.0);
#else
	glOrthof((GLfloat) 0,
		 (GLfloat) screen_size_w,
		 (GLfloat) screen_size_h,
		 (GLfloat) 0, 0.0, 1.0);
#endif
	
	glMatrixMode(GL_MODELVIEW);

	glEnable(GL_TEXTURE_2D);
	glEnable(GL_BLEND);
	glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);

	/* Generate our screenshot texture for transitions */
	glGenTextures(1, &screenshot_tex);
	glBindTexture(GL_TEXTURE_2D, screenshot_tex);
	 
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, nextPowerOfTwo(screen_size_w), nextPowerOfTwo(screen_size_h), 0,
                     GL_RGBA, GL_UNSIGNED_SHORT_5_6_5, NULL);

	return true;
}

void opengl_swap()
{
	SDL_GL_SwapWindow(window);
}

bool opengl_clear()
{
	bool ret;
	if(!transition) {
		glClear(GL_COLOR_BUFFER_BIT);
		ret = false;
	} else {
		SDL_Rect pos;
		int draw_offset;

		transition_w -= transition_delta;

		if(transition_w <= 0) {
			transition_w = 0;
			transition = false;
		}

		/* Draw screenshot */
		glLoadIdentity();

		draw_offset = screen_size_w - transition_w;
		if(transition_direction) {
			draw_offset = -draw_offset;
		}
		glTranslatef(draw_offset, 0, 0);

		pos.x = 0;
		pos.y = screen_size_h - nextPowerOfTwo(screen_size_h);
		pos.w = nextPowerOfTwo(screen_size_w);
		pos.h = nextPowerOfTwo(screen_size_h);
		opengl_blit_reverse(screenshot_tex, &pos);

		/* Translate the rest */
		glLoadIdentity();

		draw_offset = transition_w;
		if(!transition_direction) {
			draw_offset = -draw_offset;
		}

		glTranslatef(draw_offset, 0, 0);

		ret = true;
	}

	return ret;
}

void opengl_start_transition(bool direction)
{
	transition = true;
	transition_direction = direction;
	transition_w = screen_size_w;
	glBindTexture(GL_TEXTURE_2D, screenshot_tex);
	
	glCopyTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, 0, 0, nextPowerOfTwo(screen_size_w), nextPowerOfTwo(screen_size_h), 0);
}

Uint32 nextPowerOfTwo(Uint32 size)
{
    if ((size & (size - 1)) || !size) {
        int log = 0;

        while (size >>= 1)
            ++log;

        size = (2 << log);
    }

    return size;
}

static GLuint opengl_create_texture(SDL_Surface *surface, Uint32 *pWidth, Uint32 *pHeight, bool f8888)
{
	Uint32 pixelFormat = SDL_PIXELFORMAT_RGBA5551;
	GLenum format = GL_UNSIGNED_SHORT_5_5_5_1;
	
	int bpp;                    /* texture bits per pixel */
	Uint32 Rmask, Gmask, Bmask, Amask;  /* masks for pixel format passed into OpenGL */
	SDL_Surface *surface_rgba8888;  /* this serves as a destination to convert the image to the format passed into OpenGL */
	GLuint texture_id = 0;

	Uint32 width = nextPowerOfTwo(surface->w);
	Uint32 height = nextPowerOfTwo(surface->h);

	if (pWidth) *pWidth = width;
	if (pHeight) *pHeight = height;

	if(f8888) {
		pixelFormat = SDL_PIXELFORMAT_ABGR8888;
		format = GL_UNSIGNED_BYTE;
	}

	
	/* Grab info about format that will be passed into OpenGL */
	SDL_PixelFormatEnumToMasks(pixelFormat, &bpp, &Rmask, &Gmask,
				   &Bmask, &Amask);
    
	/* Create surface that will hold pixels passed into OpenGL */
	surface_rgba8888 =
		SDL_CreateRGBSurface(0, width, height, bpp, Rmask,
				     Gmask, Bmask, Amask);
	/* Blit to this surface, effectively converting the format */
	SDL_BlitSurface(surface, NULL, surface_rgba8888, NULL);
    
	glGenTextures(1, &texture_id);
	glBindTexture(GL_TEXTURE_2D, texture_id);
    
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
#ifndef __ANDROID__
	glTexParameteri(GL_TEXTURE_2D, GL_GENERATE_MIPMAP, GL_TRUE);
#endif
    
 	/* The alpha channel is not transferred - fix that */
	SDL_LockSurface(surface);
	SDL_LockSurface(surface_rgba8888);

	// Map old NPOT surface to POT surface
	// don't care about the rest of the pixels, as we are never going to blit them
	int bpp_orig = surface->format->BytesPerPixel;
	int i = 0;

	// We only have alpha channels in RGBA 8888
	if(bpp_orig > 3) {
		if(f8888) {
			for(int y=0; y<surface->h; y++, i += width) {
				for(int x=0; x<surface->w; x++) {
					Uint8 *p = (Uint8 *)surface->pixels + y * surface->pitch + x * bpp_orig;
					Uint8 rgb[4];
					SDL_GetRGBA(*(Uint32 *)p, surface->format, rgb, rgb+1, rgb+2, rgb+3);
					((Uint8 *)surface_rgba8888->pixels)[(i + x)*4+3] = rgb[3];
				}
			}
		} else {
			for(int y=0; y<surface->h; y++, i += width) {
				for(int x=0; x<surface->w; x++) {
					Uint8 *p = (Uint8 *)surface->pixels + y * surface->pitch + x * bpp_orig;
					Uint8 rgb[4];
					SDL_GetRGBA(*(Uint32 *)p, surface->format, rgb, rgb+1, rgb+2, rgb+3);
					if(rgb[3]) {
						((Uint16 *)surface_rgba8888->pixels)[i + x] |= Amask;
					}
				}
			}
		}
	}

	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0,
                     GL_RGBA, format, surface_rgba8888->pixels);

	SDL_UnlockSurface(surface);
	SDL_UnlockSurface(surface_rgba8888);

        SDL_FreeSurface(surface_rgba8888);

	return texture_id;
}

GLuint opengl_create_texture_8888(SDL_Surface *surface, Uint32 *pWidth, Uint32 *pHeight)
{
	return opengl_create_texture(surface, pWidth, pHeight, true);
}

GLuint opengl_create_texture_5551(SDL_Surface *surface, Uint32 *pWidth, Uint32 *pHeight)
{
	return opengl_create_texture(surface, pWidth, pHeight, false);
}

static void internal_opengl_blit(GLuint texture_id, GLfloat texCoords[8], SDL_Rect *dst_pos)
{
	GLfloat vertices[8];

	vertices[0] = dst_pos->x;
	vertices[1] = dst_pos->y;
	vertices[2] = dst_pos->x + dst_pos->w;
	vertices[3] = dst_pos->y;
	vertices[4] = dst_pos->x;
	vertices[5] = dst_pos->y + dst_pos->h;
	vertices[6] = dst_pos->x + dst_pos->w;
	vertices[7] = dst_pos->y + dst_pos->h;

	glVertexPointer(2, GL_FLOAT, 0, vertices);
	glTexCoordPointer(2, GL_FLOAT, 0, texCoords);
	glBindTexture(GL_TEXTURE_2D, texture_id);

	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);	
}

void opengl_blit(GLuint texture_id, GLfloat texCoords[8], SDL_Rect *dst_pos)
{
	internal_opengl_blit(texture_id, texCoords, dst_pos);
}

void opengl_blit(GLuint texture_id, SDL_Rect *dst_pos)
{
	GLfloat texCoords[8];

	float texX1 = 0.0f;
	float texX2 = 1.0f;
	float texY1 = 0.0f;
	float texY2 = 1.0f;
	
	texCoords[0] = texX1;
	texCoords[1] = texY1;
	texCoords[2] = texX2;
	texCoords[3] = texY1;
	texCoords[4] = texX1;
	texCoords[5] = texY2;
	texCoords[6] = texX2;
	texCoords[7] = texY2;

	internal_opengl_blit(texture_id, texCoords, dst_pos);
}

void opengl_blit_reverse(GLuint texture_id, SDL_Rect *dst_pos)
{
	GLfloat texCoords[8];

	float texX1 = 0.0f;
	float texX2 = 1.0f;
	float texY1 = 1.0f;
	float texY2 = 0.0f;
	
	texCoords[0] = texX1;
	texCoords[1] = texY1;
	texCoords[2] = texX2;
	texCoords[3] = texY1;
	texCoords[4] = texX1;
	texCoords[5] = texY2;
	texCoords[6] = texX2;
	texCoords[7] = texY2;

	internal_opengl_blit(texture_id, texCoords, dst_pos);
}
