#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include "bdbmpcie.h"
#include "dmasplitter.h"


int main(int argc, char** argv) {
	BdbmPcie* pcie = BdbmPcie::getInstance();

	//unsigned int d = pcie->readWord(0);
	//printf( "Magic: %x\n", d );
	//fflush(stdout);

	//pcie->userWriteWord(0, 0xdeadbeef);
	//pcie->userWriteWord(4, 0xcafef00d);
	//sleep(10);
	int page_num = 0;
	unsigned int err_threshold = 0x001c163c;
	pcie->userWriteWord(0, 1);
	pcie->userWriteWord(0, page_num);
        pcie->userWriteWord(0, 2);
        pcie->userWriteWord(0, err_threshold);
        pcie->userWriteWord(0, 3);
	
        //pcie->userWriteWord(0, 4);
//	while(1) {
		sleep(10);

		printf("\tFRM ERR: ");
		printf( "%d\n", pcie->userReadWord(0) );
		printf("\tFRM CNT L: %d",pcie->userReadWord(1 << 2));
		printf("\tFRM CNT M: %d",pcie->userReadWord(2 << 2));

	pcie->userWriteWord(0, 4);
	pcie->userWriteWord(0, 5);


        page_num = 0;
        err_threshold = 0x0;
        pcie->userWriteWord(0, 1);
        pcie->userWriteWord(0, page_num);
        pcie->userWriteWord(0, 2);
        pcie->userWriteWord(0, err_threshold);
        pcie->userWriteWord(0, 3);

                sleep(10);

                printf("\tFRM ERR: ");
                printf( "%d\n", pcie->userReadWord(0) );
                printf("\tFRM CNT L: %d",pcie->userReadWord(1 << 2));
                printf("\tFRM CNT M: %d",pcie->userReadWord(2 << 2));



/*
		pcie->userWriteWord(0, 4);
		
		sleep(1);

		pcie->userWriteWord(0, 5);


        err_threshold = 0x00382c79;
        pcie->userWriteWord(0, 1);
        pcie->userWriteWord(0, page_num);
        pcie->userWriteWord(0, 2);
        pcie->userWriteWord(0, err_threshold);
        pcie->userWriteWord(0, 3);

        //pcie->userWriteWord(0, 4);
//      while(1) {
                sleep(5);

                printf("\tFRM ERR: ");
                printf( "%d\n", pcie->userReadWord(0) );
                printf("\tFRM CNT: %d",pcie->userReadWord(1 << 2));
                pcie->userWriteWord(0, 4);


//	}*/
	return 0;
}
