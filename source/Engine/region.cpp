#include "allfiles.h"
#include "objtypes.h"
#include "region.h"
#include "newfatal.h"
#include "sludger.h"
#include "moreio.h"
#include "backdrop.h"

screenRegion * allScreenRegions = NULL;
screenRegion * overRegion = NULL;
extern inputType input;
extern int cameraX, cameraY;

void showBoxes () {
	screenRegion * huntRegion = allScreenRegions;

	while (huntRegion) {
		drawVerticalLine (huntRegion -> x1, huntRegion -> y1, huntRegion -> y2);
		drawVerticalLine (huntRegion -> x2, huntRegion -> y1, huntRegion -> y2);
		drawHorizontalLine (huntRegion -> x1, huntRegion -> y1, huntRegion -> x2);
		drawHorizontalLine (huntRegion -> x1, huntRegion -> y2, huntRegion -> x2);
		huntRegion = huntRegion -> next;
	}
}

void removeScreenRegion (int objectNum) {
	screenRegion * * huntRegion = & allScreenRegions;
	screenRegion * killMe;

	while (* huntRegion) {
		if ((* huntRegion) -> thisType -> objectNum == objectNum) {
			killMe = * huntRegion;
			* huntRegion = killMe -> next;
			removeObjectType (killMe -> thisType);
			if (killMe == overRegion) overRegion = NULL;
			delete killMe;
			killMe = NULL;
		} else {
			huntRegion = & ((* huntRegion) -> next);
		}
	}
}

void saveRegions (FILE * fp) {
	int numRegions = 0;
	screenRegion * thisRegion = allScreenRegions;
	while (thisRegion) {
		thisRegion = thisRegion -> next;
		numRegions ++;
	}
	put2bytes (numRegions, fp);
	thisRegion = allScreenRegions;
	while (thisRegion) {
		put2bytes (thisRegion -> x1, fp);
		put2bytes (thisRegion -> y1, fp);
		put2bytes (thisRegion -> x2, fp);
		put2bytes (thisRegion -> y2, fp);
		put2bytes (thisRegion -> sX, fp);
		put2bytes (thisRegion -> sY, fp);
		put2bytes (thisRegion -> di, fp);
		saveObjectRef (thisRegion -> thisType, fp);

		thisRegion = thisRegion -> next;
	}
}

void loadRegions (FILE * fp) {
	int numRegions = get2bytes (fp);

	screenRegion * newRegion;
	screenRegion * * pointy = & allScreenRegions;

	while (numRegions --) {
		newRegion = new screenRegion;
		* pointy = newRegion;
		pointy = & (newRegion -> next);

		newRegion -> x1 = get2bytes (fp);
		newRegion -> y1 = get2bytes (fp);
		newRegion -> x2 = get2bytes (fp);
		newRegion -> y2 = get2bytes (fp);
		newRegion -> sX = get2bytes (fp);
		newRegion -> sY = get2bytes (fp);
		newRegion -> di = get2bytes (fp);
		newRegion -> thisType = loadObjectRef (fp);
	}
	* pointy = NULL;
}

void killAllRegions () {
	screenRegion * killRegion;
	while (allScreenRegions) {
		killRegion = allScreenRegions;
		allScreenRegions = allScreenRegions -> next;
		removeObjectType (killRegion -> thisType);
		delete killRegion;
	}
	overRegion = NULL;
}

bool addScreenRegion (int x1, int y1, int x2, int y2, int sX, int sY, int di, int objectNum) {
	screenRegion * newRegion = new screenRegion;
	if (! checkNew (newRegion)) return false;
	newRegion -> di = di;
	newRegion -> x1 = x1;
	newRegion -> y1 = y1;
	newRegion -> x2 = x2;
	newRegion -> y2 = y2;
	newRegion -> sX = sX;
	newRegion -> sY = sY;
	newRegion -> thisType = loadObjectType (objectNum);
	newRegion -> next = allScreenRegions;
	allScreenRegions = newRegion;
	return (bool) (newRegion -> thisType != NULL);
}

void getOverRegion () {
	screenRegion * thisRegion = allScreenRegions;
	while (thisRegion) {
		if ((input.mouseX >= thisRegion -> x1 - cameraX) && (input.mouseY >= thisRegion -> y1 - cameraY) &&
			 (input.mouseX <= thisRegion -> x2 - cameraX) && (input.mouseY <= thisRegion -> y2 - cameraY)) {
			overRegion = thisRegion;
			return;
		}
		thisRegion = thisRegion -> next;
	}
	overRegion = NULL;
	return;
}

screenRegion * getRegionForObject (int obj) {
	screenRegion * thisRegion = allScreenRegions;

	while (thisRegion) {
		if (obj == thisRegion -> thisType -> objectNum) {
			return thisRegion;
		}
		thisRegion = thisRegion -> next;
	}

	return NULL;
}
