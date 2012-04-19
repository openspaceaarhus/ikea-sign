#ifndef PIND_SURFACE_H
#define PIND_SURFACE_H

#include <SDL.h>
#ifdef USE_OPENGL
#include <SDL_opengl.h>
#else
#include <SDL_opengles.h>
#endif

class CImg {
public:
	static SDL_Surface *loadImage(const char *filename);
};

class CPindSurface {
private:
	GLuint texture_id;
	Uint32 w, h;
	Uint32 org_w, org_h;
	float tex_w, tex_h;
	bool clip;
	CPindSurface();

public:
	CPindSurface(const char *filename, bool clip, bool themed);
	~CPindSurface();

	void blit(SDL_Rect *src_pos, SDL_Rect *dst_pos);
	void blit(SDL_Rect *src_pos, SDL_Rect *dst_pos, SDL_Rect *bounding_rect);
	int getWidth();
	int getHeight();
};

#endif
