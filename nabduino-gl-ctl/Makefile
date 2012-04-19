CXX=g++
CC=gcc
IMAGE_PATH=\"./data/\"
TMP_PATH=\"/tmp/\"
SDL_CFLAGS=$(shell sdl-config --cflags)
SDL_LDFLAGS=$(shell sdl-config --libs) 
OBJS=skilt.o opengl.o pind_surface.o globals.o font.o
LDFLAGS=$(SDL_LDFLAGS) -lSDL_image -lGL
CXXFLAGS=-g -O1 -Wall $(SDL_CFLAGS) -DMOUSE_CONTROLLED -DIMAGE_PATH=$(IMAGE_PATH) -DTMP_PATH=$(TMP_PATH) -DUSE_OPENGL
CFLAGS=-g -O1 -Wall

skilt: $(OBJS)
	$(CXX) -o $@ $(LDFLAGS) $(OBJS)

clean:
	rm -f *~ *.o skilt
