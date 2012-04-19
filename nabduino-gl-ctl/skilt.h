#ifndef SKILT_H
#define SKILT_H

#include <SDL.h>
#include "font.h"

class CSkilt {
private:
	int skilt_socket;
	bool need_fast_redraw;

	bool Running;
	unsigned long long packetOut;
	CPindSurface *bg;
	CPindSurface *main_bg;
	char color_str[16];

	CFont *font;

	int start_move_x, start_move_y, current_move_x, current_move_y;
public:
	CSkilt();
	int OnExecute();
	void DrawPlaying();
        void OnEventPlaying(SDL_Event* Event);

private:
	void SetColor();
	int MakeSocket(const char *host, int port);
        bool OnInit();
        void OnEvent(SDL_Event* Event);
        void OnLoop();
        void OnRender();
        void OnCleanup();
};

#endif
