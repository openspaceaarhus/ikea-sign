#include <SDL_image.h>
#include <string.h>

#include "pind_surface.h"
#include "font.h"
#include "opengl.h"
#include "globals.h"

#define FONT_BASE_RES_W 700
#define FONT_BASE_RES_H 960

CFont::CFont(const char *filename)
{
	unsigned int offsets[55*2];
	SDL_Surface *surface_font;

	widest = 0;
	surface_font = CImg::loadImage(filename);
	texture_id = opengl_create_texture_5551(surface_font, &w, &h);

	orig_w = surface_font->w;
	orig_h = surface_font->h;
	scaled_h = (orig_h / 2) * screen_size_h / FONT_BASE_RES_H;
	spacing = 7 * screen_size_h / FONT_BASE_RES_H;

	SDL_LockSurface(surface_font);

	/* Now find offsets */
	int offsetc = 0;
	bool blanksearch = true;
	for(int line=0; line<2; line++) {
		for(int x=0; x<surface_font->w; x++) {
			bool line_empty = true;
			for(int y=line*64; y<(line+1)*64; y++) {
				int bpp = surface_font->format->BytesPerPixel;
				/* Here p is the address to the pixel we want to retrieve */
				Uint8 *p = (Uint8 *)surface_font->pixels + y * surface_font->pitch + x * bpp;
				Uint8 rgb[4];
				SDL_GetRGBA(*(Uint32 *)p, surface_font->format, rgb, rgb+1, rgb+2, rgb+3);
				if(rgb[0] | rgb[1] | rgb[2]) {
					line_empty = false;
					break;
				}
			}
			
			if(blanksearch && !line_empty) {
				blanksearch = false;
				offsets[offsetc++] = x - 1;
			}
			if(!blanksearch && line_empty) {
				blanksearch = true;
				offsets[offsetc++] = x + 1;
				
				if(offsets[offsetc-1] - offsets[offsetc-2] > widest) {
					widest = offsets[offsetc-1] - offsets[offsetc-2];
				}
			}
		}
	}

	for(unsigned int i=0; i<sizeof(letter_offsets) / sizeof(letter_offsets[0]); i+=2) {
		widths[i / 2] = (offsets[i+1] - offsets[i]) * screen_size_w / FONT_BASE_RES_W;
		letter_offsets[i] = offsets[i] / (float)w;
		letter_offsets[i+1] = offsets[i+1] / (float)w;
	}

	SDL_UnlockSurface(surface_font);
	SDL_FreeSurface(surface_font);
}

void CFont::BlitCentered(const char *str, int ypos)
{
	SDL_Rect pos;

	pos.x = screen_size_w / 2 - Width(str) / 2;
	pos.y = ypos;

	Blit(str, &pos);
}

void CFont::BlitCentered(const char *str, int ypos, SDL_Rect *bounding_rect)
{
	SDL_Rect pos;

	pos.x = screen_size_w / 2 - Width(str) / 2;
	pos.y = ypos;

	Blit(str, &pos, bounding_rect);
}

void CFont::Blit(const char *str, SDL_Rect *pos, SDL_Rect *bounding_rect)
{
	bounding_rect->x = pos->x;
	bounding_rect->y = pos->y;
	Blit(str, pos);
	bounding_rect->w = pos->x - bounding_rect->x;
	bounding_rect->h = GetHeight();
}

void CFont::Blit(const char *str, SDL_Rect *pos)
{
	GLfloat texCoords[8];

	for(int i=0; str[i]; i++) {
		if(str[i] >= '0' && str[i] <= 'Z') {
			int fonti = str[i] - '0';

			texCoords[4] = texCoords[0] = letter_offsets[fonti * 2];
			texCoords[3] = texCoords[1] = (fonti > 0x17) ? 0.5f : 0.0f;
			texCoords[6] = texCoords[2] = letter_offsets[fonti * 2 + 1];
			texCoords[7] = texCoords[5] = 0.5f + texCoords[1];

			pos->w = widths[fonti];
			pos->h = scaled_h;

			opengl_blit(texture_id, texCoords, pos);

			pos->x += widths[fonti] + spacing;
		} else if(str[i] == ' ') {
			/* We all know a space should be equal to '0' in width */
			pos->x += widths[0];
		}
	}
}

unsigned int CFont::Width(const char *str)
{
	unsigned int size = 0;

	for(int i=0; str[i]; i++) {
		if(str[i] >= '0' && str[i] <= 'Z') {
			int fonti = str[i] - '0';

			size += widths[fonti] + spacing;
		} else if(str[i] == ' ') {
			size += widths[0];
		}
	}

	return size;
}


int CFont::GetHeight()
{
	return scaled_h;
}
