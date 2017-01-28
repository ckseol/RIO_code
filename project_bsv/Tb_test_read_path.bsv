package Tb;

import FIFO::*;
import FIFOF::*;
import Vector::*;
import test_read_path::*;

(* synthesize *)
module mkTb (Empty);
	TestReadPathIfc test_read_path <- mkTestReadPath;	

        Reg#(int) cycle <- mkReg(0);
	Reg#(UInt#(32)) rcvd_in_cnt <- mkReg(0);
	
	rule init (cycle == 0);
		test_read_path.set_page_num(0);
		//test_read_path.set_err_threshold(32'h001c163c); // 1e-3
		//test_read_path.set_err_threshold(32'h00382c79); // 2e-3
		//test_read_path.set_err_threshold(32'h002a215a); // 1.5e-3
		test_read_path.set_err_threshold(32'h001ee542); // 1.1e-3
		//test_read_path.set_err_threshold(32'h0013a92a); // 0.7e-3
		//test_read_path.set_err_threshold(32'h0);
		test_read_path.start_dec();
	endrule

//	rule stop_sim (cycle == 299999);
//		test_read_path.stop_dec();
//	endrule

	rule displayOut;// (cycle == 300000);
		let frm_err_prob = test_read_path.get_frm_err_prob();
		if (frm_err_prob.frm_err_cnt == 1) begin
			$display("Frame cnt=%d, frame error cnt=%d", frm_err_prob.frm_cnt, frm_err_prob.frm_err_cnt);
			$finish(); 
		end
	endrule

        rule cycleCount;
                cycle <= cycle + 1;
//		if (cycle == 300001) begin
//			$display("Cycle: %d", cycle);	
//			$finish();
//		end
                //$display("%d", cycle);
        endrule


endmodule: mkTb
endpackage: Tb

