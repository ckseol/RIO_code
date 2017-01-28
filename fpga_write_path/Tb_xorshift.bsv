package Tb;

import FIFO::*;
import FIFOF::*;
import Vector::*;
import Xorshift_r12_m5::*;

typedef 6 Page_num;

(* synthesize *)
module mkTb (Empty);
	
        Reg#(int) cycle <- mkReg(0);

	Xorshift_r12_m5_Ifc rng <- mkXorshift_r12_m5;
	
	rule rnd_generate;
		let rnd_vec <- rng.get_val();
		for (Integer i=0 ; i<32 ; i=i+1)
			$display("[%d][%d] %x", cycle, i, rnd_vec[i]);
	endrule
	
        rule cycleCount;
                cycle <= cycle + 1;
		if (cycle == 3) begin
			$display("Cycle: %d", cycle);	
			$finish();
		end
                //$display("%d", cycle);
        endrule


endmodule: mkTb
endpackage: Tb

