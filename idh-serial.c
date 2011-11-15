#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <sys/time.h>

#define RC(x)	(0xc8 | ((x) >> 7))
#define RD(x)	((x) & 0x7f)
#define GC(x)	(0xd0 | ((x) >> 7))
#define GD(x)	((x) & 0x7f)
#define BC(x)	(0xd8 | ((x) >> 7))
#define BD(x)	((x) & 0x7f)
#define HC(x)	(0xe0 | (((x) >> 7) & 0x0f))
#define HD(x)	((x) & 0x7f)
#define SC(x)	(0xf0 | ((x) >> 7))
#define SD(x)	((x) & 0x7f)
#define VC(x)	(0xf8 | ((x) >> 7))
#define VD(x)	((x) & 0x7f)

#define set_r(x)	do { fputc(RC(x), stdout); fputc(RD(x), stdout); } while(0)
#define set_g(x)	do { fputc(GC(x), stdout); fputc(GD(x), stdout); } while(0)
#define set_b(x)	do { fputc(BC(x), stdout); fputc(BD(x), stdout); } while(0)
#define set_h(x)	do { fputc(HC(x), stdout); fputc(HD(x), stdout); } while(0)
#define set_s(x)	do { fputc(SC(x), stdout); fputc(SD(x), stdout); } while(0)
#define set_v(x)	do { fputc(VC(x), stdout); fputc(VD(x), stdout); } while(0)
#define set_c(x)	do { set_r(((x) >> 16) & 0xff); set_g(((x) >> 8) & 0xff); set_b(((x) >> 0) & 0xff); } while(0)
#define	set_mode(x)	do { fputc(0xc1, stdout); fputc((((x) & 0x07) | 0x20), stdout); } while(0)

//static int hue = 0;
void sigalarm(int sig)
{
	//set_c(rand());
//	set_h(hue);
//	hue += 10;
//	if(hue > 1541)
//		hue = 0;
	set_h(rand() % 1542);
	set_v(rand() & 0xff);
}

void sigint(int sig)
{
	set_mode(1);
	exit(0);
}

int main(void)
{
//	int i;
//	int j;
	struct itimerval interval;

	setvbuf(stdin, NULL, _IONBF, 0);
	setvbuf(stdout, NULL, _IONBF, 0);
	setvbuf(stderr, NULL, _IONBF, 0);

	set_mode(6);
	set_v(0xff);
	set_s(0xff);

	signal(SIGALRM, sigalarm);
	signal(SIGINT, sigint);

	interval.it_interval.tv_sec = 0;
	interval.it_interval.tv_usec = 125000;
	interval.it_value = interval.it_interval;

	setitimer(ITIMER_REAL, &interval, NULL);

	while(1)
		sleep(1);
#if 0
	set_c(0x000000);
	for(i = 0; i < 1000; i++) {
		set_c(rand());
/*
		for(j = 0; j < 256; j++) {
			set_r(j);
			//usleep(5000);
		}
		for(j = 254; j >= 0; j--) {
			set_r(j);
			//usleep(5000);
		}
*/
	}

	return 0;
#endif
}
