#include <time.h>
#include <SDL_image.h>
#include "opengl.h"
#include "pind_surface.h"

SDL_Surface *CImg::loadImage(const char *filename) {
        return IMG_Load(filename);
}

CPindSurface::CPindSurface()
{
}

CPindSurface::CPindSurface(const char *filename, bool _clip, bool themed)
{
	char path[256];

	sprintf(path, IMAGE_PATH "%s", filename);

	SDL_Surface *surface = CImg::loadImage(path);
	clip = _clip;

	if(surface) {
		org_w = surface->w;
		org_h = surface->h;
        texture_id = opengl_create_texture_8888(surface, &w, &h);
		tex_w = org_w / (float)w;
		tex_h = org_h / (float)h;
		SDL_FreeSurface(surface);
	}
}

CPindSurface::~CPindSurface()
{
	glDeleteTextures(1, &texture_id);
}

void CPindSurface::blit(SDL_Rect *src_pos, SDL_Rect *dst_pos, SDL_Rect *bounding_rect)
{
	blit(src_pos, dst_pos);

	if(bounding_rect) {
		memcpy(bounding_rect, dst_pos, sizeof(*dst_pos));
	}
}

void CPindSurface::blit(SDL_Rect *src_pos, SDL_Rect *dst_pos)
{
	GLfloat texCoords[8];

	if(!src_pos)
	{
		if(clip) {
			texCoords[0] = 0.0f;
			texCoords[1] = 0.0f;
			if(dst_pos->w < org_w) {
				texCoords[2] = dst_pos->w * tex_w / org_w;
			} else {
				texCoords[2] = tex_w;
			}
			texCoords[3] = 0.0;
			texCoords[4] = 0.0;
			if(dst_pos->h < org_h) {
				texCoords[5] = dst_pos->h * tex_h / org_h;
			} else {
				texCoords[5] = tex_h;
			}
			texCoords[6] = texCoords[2];
			texCoords[7] = texCoords[5];
		} else {
			texCoords[0] = 0.0f;
			texCoords[1] = 0.0f;
			texCoords[2] = tex_w;
			texCoords[3] = 0.0;
			texCoords[4] = 0.0;
			texCoords[5] = tex_h;
			texCoords[6] = tex_w;
			texCoords[7] = tex_h;
		}

		if(!dst_pos->w) {
			dst_pos->w = org_w;
			dst_pos->h = org_h;
		}
	} else {
		texCoords[0] = src_pos->x * tex_w / org_w;
		texCoords[1] = src_pos->y * tex_h / org_h;
		texCoords[2] = (src_pos->x + src_pos->w) * tex_w / org_w;
		texCoords[3] = texCoords[1];
		texCoords[4] = texCoords[0];
		texCoords[5] = (src_pos->y + src_pos->h) * tex_h / org_h;
		texCoords[6] = texCoords[2];
		texCoords[7] = texCoords[5];		
		
		if(!dst_pos->w) {
			dst_pos->w = src_pos->w;
			dst_pos->h = src_pos->h;
		}
	}
	
	
	opengl_blit(texture_id, texCoords, dst_pos);
}

int CPindSurface::getHeight()
{
	return org_h;
}

int CPindSurface::getWidth()
{
	return org_w;
}
