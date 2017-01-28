#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include "bdbmpcie.h"
#include "dmasplitter.h"


int main(int argc, char** argv) {
	BdbmPcie* pcie = BdbmPcie::getInstance();

	//while(1) {
		sleep(100);
		for (int i=0 ; i<7 ; i++)
			printf("[Page:%d] %d\n", i, pcie->userReadWord(i << 2));
		printf("WL cnt: %d\n", pcie->userReadWord(7 << 2));
	//}
	return 0;
}
