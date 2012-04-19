#ifndef FONT_H
#define FONT_H

#include <SDL.h>
#include "opengl.h"

class CFont {
private:
	GLfloat letter_offsets[55*2];
	unsigned int widths[55];
	unsigned int widest;
	Uint32 w;
	Uint32 h;
	int scaled_h;
	int orig_w;
	int orig_h;
	int spacing;
	GLuint texture_id;
	
public:
	CFont(const char *filename);

	void Blit(const char *str, SDL_Rect *pos);
	void Blit(const char *str, SDL_Rect *pos, SDL_Rect *bounding_rect);
	void BlitCentered(const char *str, int ypos);
	void BlitCentered(const char *str, int ypos, SDL_Rect *bounding_rect);
	unsigned int Width(const char *str);
	int GetHeight();
};

#endif
