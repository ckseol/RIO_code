package Tb;

import FIFO::*;
import FIFOF::*;
import Vector::*;
import test_write_path::*;

(* synthesize *)
module mkTb (Empty);

	TestWritePathIfc test_write_path <- mkTestWritePath;
	
        Reg#(int) cycle <- mkReg(0);

	rule get_enc_err_prob;
		let enc_err_prob <- test_write_path.get_enc_err_prob();
		
		for (Integer i=0 ; i<7 ; i=i+1)
			$display("[Page:%d] Enc fail cnt: %d", i, enc_err_prob.enc_err_cnt[i]);
		$display("WL count: %d", enc_err_prob.wl_cnt);
	endrule			
	
        rule cycleCount (cycle > 0);
                cycle <= cycle + 1;
		if (cycle == 2000000) begin
		//	$display("Cycle: %d", cycle);	
			$finish();
		end
               // $display("%d", cycle);
        endrule


endmodule: mkTb
endpackage: Tb

