#include <stdint.h>

#include "allfiles.h"
#include "zbuffer.h"
#include "fileset.h"
#include "moreio.h"
#include "newfatal.h"
#include "graphics.h"

zBufferData zBuffer;
extern int sceneWidth, sceneHeight;

void killZBuffer () {
	if (zBuffer.tex) {
		deleteTextures (1, &zBuffer.texName);
		zBuffer.texName = 0;
		delete zBuffer.tex;
		zBuffer.tex = NULL;
	}
	zBuffer.numPanels = 0;
	zBuffer.originalNum =0;
}

void sortZPal (int *oldpal, int *newpal, int size) {
	int i, tmp;

	for (i = 0; i < size; i ++) {
		newpal[i] = i;
	}

	if (size < 2) return;		
		
	for (i = 1; i < size; i ++) {
		if (oldpal[newpal[i]] < oldpal[newpal[i-1]]) {
			tmp = newpal[i];
			newpal[i] = newpal[i-1];
			newpal[i-1] = tmp;
			i = 0;
		}
	}
}

bool setZBuffer (int y) {
	int x, n;
	uint32_t stillToGo = 0;
	int yPalette[16], sorted[16], sortback[16];

	killZBuffer ();
	
	setResourceForFatal (y);

	zBuffer.originalNum = y;
	if (! openFileFromNum (y)) return false;
	if (fgetc (bigDataFile) != 'S') return fatal ("Not a Z-buffer file");
	if (fgetc (bigDataFile) != 'z') return fatal ("Not a Z-buffer file");
	if (fgetc (bigDataFile) != 'b') return fatal ("Not a Z-buffer file");

	switch (fgetc (bigDataFile)) {
		case 0:
		zBuffer.width = 640;
		zBuffer.height = 480;
		break;
		
		case 1:
		zBuffer.width = get2bytes (bigDataFile);
		zBuffer.height = get2bytes (bigDataFile);
		break;
		
		default:
		return fatal ("Extended Z-buffer format not supported in this version of the SLUDGE engine");
	}
	if (zBuffer.width != sceneWidth || zBuffer.height != sceneHeight) {
		char tmp[256];
		sprintf (tmp, "Z-w: %d Z-h:%d w: %d, h:%d", zBuffer.width, zBuffer.height, sceneWidth, sceneHeight);
		return fatal ("Z-buffer width and height don't match scene width and height", tmp);
	}
		
	zBuffer.numPanels = fgetc (bigDataFile);
	for (y = 0; y < zBuffer.numPanels; y ++) {
		yPalette[y] = get2bytes (bigDataFile);
	}
	sortZPal (yPalette, sorted, zBuffer.numPanels);
	for (y = 0; y < zBuffer.numPanels; y ++) {
		zBuffer.panel[y] = yPalette[sorted[y]];
		sortback[sorted[y]] = y; 
	}
	
	int picWidth = sceneWidth;
	int picHeight = sceneHeight;
	if (! NPOT_textures) {
		picWidth = getNextPOT(picWidth);
		picHeight = getNextPOT(picHeight);
	}
	zBuffer.tex = new GLubyte [picHeight*picWidth];
	if (! checkNew (zBuffer.tex)) return false;

	for (y = 0; y < sceneHeight; y ++) {
		for (x = 0; x < sceneWidth; x ++) {
			if (stillToGo == 0) {
				n = fgetc (bigDataFile);
				stillToGo = n >> 4;
				if (stillToGo == 15) stillToGo = get2bytes (bigDataFile) + 16l;
				else stillToGo ++;
				n &= 15;
			}
			zBuffer.tex[y*picWidth + x] = sortback[n]*16;
			stillToGo --;
		}
	}
	finishAccess ();
	
	setResourceForFatal (-1);
		
	if (! zBuffer.texName) glGenTextures (1, &zBuffer.texName);
	glBindTexture (GL_TEXTURE_2D, zBuffer.texName);
	glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	texImage2D (GL_TEXTURE_2D, 0, GL_ALPHA, picWidth, picHeight, 0, GL_ALPHA, GL_UNSIGNED_BYTE, zBuffer.tex, zBuffer.texName);
	
	
	return true;
}

void drawZBuffer(int x, int y, bool upsidedown) {
	int i;
	
	if (! zBuffer.tex) return;
	
	glEnable(GL_DEPTH_TEST);
	glEnable(GL_BLEND);
	glColorMask (GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);
	glDepthMask (GL_TRUE);

	glUseProgram(shader.texture);
	setPMVMatrix(shader.texture);

	//glTexEnvf (GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
	glBindTexture (GL_TEXTURE_2D, zBuffer.texName);
	setPrimaryColor(1.0, 1.0, 1.0, 1.0);

	for (i = 1; i<zBuffer.numPanels; i++) {
		GLfloat z = 1.0 - (double) i * (1.0 / 128.0);

		GLfloat vy1 = -y, vy2 = zBuffer.height-y;
		if (upsidedown) {
			vy1 += zBuffer.height;
			vy2 -= zBuffer.height;
		}

		const GLfloat vertices[] = { 
			(GLfloat)-x, vy1, z,
			(GLfloat)zBuffer.width-x, vy1, z, 
			(GLfloat)-x, vy2, z,
			(GLfloat)zBuffer.width-x, vy2, z
		};

		const GLfloat texCoords[] = { 
			0.0f, 0.0f,
			backdropTexW, 0.0f,
			0.0f, backdropTexH,
			backdropTexW, backdropTexH
		}; 

		glUniform1i(glGetUniformLocation(shader.texture, "zBuffer"), 1);
		glUniform1f(glGetUniformLocation(shader.texture, "zBufferLayer"), i);
 
		drawQuad(shader.texture, vertices, 1, texCoords);
		glUniform1i(glGetUniformLocation(shader.texture, "zBuffer"), 0);
	}
	
	glColorMask (GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
	glDepthMask (GL_FALSE);
	glDisable(GL_BLEND);	
	glUseProgram(0);
}

