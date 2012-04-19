#include <unistd.h>
#include <netdb.h>
#include <netinet/in.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/time.h>
#include "globals.h"
#include "pind_surface.h"
#include "opengl.h"
#include "skilt.h"

static const char *FONT_FILENAME = IMAGE_PATH "font_64.png";

static void HSVtoRGB( float *r, float *g, float *b, float h, float s, float v )
{
	int i;
	float f, p, q, t;

	if( s == 0 ) {
		// achromatic (grey)
		*r = *g = *b = v;
		return;
	}

	h /= 60;			// sector 0 to 5
	i = floor( h );
	f = h - i;			// factorial part of h
	p = v * ( 1 - s );
	q = v * ( 1 - s * f );
	t = v * ( 1 - s * ( 1 - f ) );

	switch( i ) {
		case 0:
			*r = v;
			*g = t;
			*b = p;
			break;
		case 1:
			*r = q;
			*g = v;
			*b = p;
			break;
		case 2:
			*r = p;
			*g = v;
			*b = t;
			break;
		case 3:
			*r = p;
			*g = q;
			*b = v;
			break;
		case 4:
			*r = t;
			*g = p;
			*b = v;
			break;
		default:		// case 5:
			*r = v;
			*g = p;
			*b = q;
			break;
	}

}

int CSkilt::MakeSocket(const char *host, int port)
{
	int sock;
	struct sockaddr_in sa;
	struct hostent *hp;

	int ret;

	hp = gethostbyname(host);
	if(hp == NULL) { return -1; }
	
	/* Copy host address from hostent to (server) socket address */
	memcpy((char *)&sa.sin_addr, (char *)hp->h_addr, hp->h_length);
	sa.sin_family = hp->h_addrtype;		/* Set service sin_family to PF_INET */
	sa.sin_port = htons(port);      	/* Put portnum into sockaddr */
	
	sock = socket(hp->h_addrtype, SOCK_DGRAM, 0);
	if(sock == -1) { return -1; }
	
	ret = connect(sock, (struct sockaddr *)&sa, sizeof(sa));
	if(ret == -1) { return -1; }
	
	return sock;
}


CSkilt::CSkilt()
{
	Running = true;
	bg = NULL;
	packetOut = 0;
	current_move_x = 0;
	current_move_y = 0;
	sprintf(color_str, "00:00:00");
}

int CSkilt::OnExecute()
{
	SDL_Event Event;
	int fpc = 0;

	if(OnInit() == false) {
		return -1;
	}

	while(Running) {
		bool event = false;
		Uint32 before = SDL_GetTicks();

		while(SDL_PollEvent(&Event)) {
			OnEvent(&Event);
			event = true;
		}
		
		OnLoop();

		if(event || need_fast_redraw || (fpc % FPS) == 0) {
			need_fast_redraw = opengl_clear();
			OnRender();

			opengl_swap();
		}

		if(SDL_GetTicks() - before < 1000 / FPS) {
			SDL_Delay(1000 / FPS - (SDL_GetTicks() - before));
		}
		
		fpc++;
	}

	OnCleanup();

	return 0;
}

void CSkilt::SetColor()
{
	float r, g, b, h, s, v;
	unsigned char packet[] = {0x0, 0x0, 0x0, 0x0, 0x1, 0x2, 0x3, 0x4, 0x1, 0x2, 0x3, 0x4, 0x0, 0x0, 0x0, 42, 0, 0, 0};

	h = current_move_x * 360.0f / screen_size_w;
	v = 1.0 - current_move_y / (float)screen_size_h;
	s = 1.0;
	HSVtoRGB(&r, &g, &b, h, s, v);
	packet[sizeof(packet) - 3] = (unsigned char)(r * 255.0);
	packet[sizeof(packet) - 2] = (unsigned char)(g * 255.0);
	packet[sizeof(packet) - 1] = (unsigned char)(b * 255.0);

	sprintf(color_str, "%02X:%02X:%02X", packet[sizeof(packet) - 3], packet[sizeof(packet) - 2], packet[sizeof(packet) - 1]);
	
	if(skilt_socket > 0) {
		if(packetOut) {
			unsigned char resp[16];
			fd_set rfds;
			struct timeval tv;
			int retval;
			
			do {
				FD_ZERO(&rfds);
				FD_SET(skilt_socket, &rfds);
				
				tv.tv_sec = 0;
				tv.tv_usec = 0;
				
				retval = select(skilt_socket + 1, &rfds, NULL, NULL, &tv);
				if(retval > 0) {
					recv(skilt_socket, resp, sizeof(resp), 0);
					packetOut = 0;
				}
			} while(retval > 0);
		}

		/* Check if we should just time out and allow a new packet */
		if(packetOut) {
			struct timeval tv;
			gettimeofday(&tv, 0);
			unsigned long long now = 1000 * (unsigned long long)tv.tv_sec + (unsigned long long)tv.tv_usec / 1000;
			if(now > packetOut + 150) {
				packetOut = 0;
			}
		}

		if(packetOut == 0 && send(skilt_socket, packet, sizeof(packet), 0) > 0) {
			struct timeval tv;
			gettimeofday(&tv, 0);
			packetOut = 1000 * (unsigned long long)tv.tv_sec + (unsigned long long)tv.tv_usec / 1000;
		}
	}
}

bool CSkilt::OnInit()
{
	if(SDL_Init(SDL_INIT_VIDEO) < 0) {
		return false;
	}
	
#if defined(ANDROID)
extern int Android_ScreenWidth;
extern int Android_ScreenHeight;

	screen_size_w = Android_ScreenWidth;
	screen_size_h = Android_ScreenHeight;

#else
	SDL_Rect** modes;
	
	/* Get available fullscreen/hardware modes */
	modes = SDL_ListModes(NULL, SDL_FULLSCREEN|SDL_HWSURFACE);

	/* Check if there are any modes available */
	if (modes && modes != (SDL_Rect**)-1) {
		int i;
		for (i=0; modes[i]; ++i) {
			/* See if the mode is portrait and higher resolution than the current */
			if(modes[i]->w < modes[i]->h &&
			   modes[i]->w > screen_size_w &&
			   modes[i]->h > screen_size_h) {
				screen_size_w = modes[i]->w;
				screen_size_h = modes[i]->h;
			}
		}
	}
#endif
    
	if(!opengl_init()) {
		return false;
	}

	font = new CFont(FONT_FILENAME);

	main_bg = new CPindSurface("main_bg.png", false, true);

	bg = main_bg;

	skilt_socket = MakeSocket("10.0.2.115", 5570);

	{
		unsigned char serial_mode_packet[] = {0x0, 0x0, 0x0, 0x0, 0x1, 0x2, 0x3, 0x4, 0x1, 0x2, 0x3, 0x4, 0x0, 0x0, 0x0, 43, 6};
		send(skilt_socket, serial_mode_packet, sizeof(serial_mode_packet), 0);
	}

	return true;
}

void CSkilt::OnEvent(SDL_Event *event)
{
	if(event->type == SDL_QUIT) {
		Running = false;
		return;
	}

	switch(event->type) {
#ifdef MOUSE_CONTROLLED
	case SDL_MOUSEBUTTONDOWN:
	{
		int x = event->button.x;
		int y = event->button.y;
#else
	case SDL_FINGERDOWN:
	{
		SDL_Touch *state  = SDL_GetTouch(event->tfinger.touchId);
		int x = event->tfinger.x * screen_size_w / state->xres;
		int y = event->tfinger.y * screen_size_h / state->yres;
#endif
		current_move_x = x;
		current_move_y = y;

		SetColor();
	}
	break;

#ifdef MOUSE_CONTROLLED
	case SDL_MOUSEMOTION: {
		current_move_x = event->motion.x;
		current_move_y = event->motion.y;
#else
	case SDL_FINGERMOTION: {
		SDL_Touch *state  = SDL_GetTouch(event->tfinger.touchId);
		current_move_x = event->tfinger.x * screen_size_w / state->xres;
		current_move_y = event->tfinger.y * screen_size_h / state->yres;
#endif
		need_fast_redraw = true;
		SetColor();
		break;
	}

#ifdef MOUSE_CONTROLLED
        case SDL_MOUSEBUTTONUP:
	{
#else
	case SDL_FINGERUP:	
	{
#endif
	}
	break;
	}
}

void CSkilt::OnRender()
{
	SDL_Rect pos = {0, 0, screen_size_w, screen_size_h};
	
	main_bg->blit(NULL, &pos);
	
	pos.x = screen_size_w - font->Width("00:00:00") - 5;
	pos.y = screen_size_h - font->GetHeight();

	font->Blit(color_str, &pos);
}

void CSkilt::OnCleanup()
{
	if(skilt_socket > 0) {
		close(skilt_socket);
		skilt_socket = -1;
	}
	SDL_Quit();
}

void CSkilt::OnLoop()
{
}


int main(int argc, char *argv[])
{
	CSkilt skilt;

	return skilt.OnExecute();
}
