package Tb;

import FIFO::*;
import FIFOF::*;
import Vector::*;
import RIO_code_scheme_read_path::*;
import noise_gen::*;

`include "test_input_rio_scheme_frame1.bsv"
`include "output_rio_scheme_frame1.bsv"

typedef 6 Page_num;

(* synthesize *)
module mkTb (Empty);
	RIOCodeSchemeReadPathIfc rio_code_read_path <- mkRIOCodeSchemeReadPath;
	NoiseGenIfc err_vec_gen <- mkNoiseGen;
	
        Reg#(int) cycle <- mkReg(0);
	Reg#(UInt#(32)) rcvd_in_cnt <- mkReg(0);
	Reg#(UInt#(32)) msg_out_cnt <- mkReg(0);
/*
        rule inputMessages (msg_in_cnt < 575);
		if (msg_in_cnt < 4)
                	rio_code_read_path.putRcvd(32'h12345678);
		else if (msg_in_cnt > 556 )
			rio_code_read_path.putRcvd(32'h1);
		else
			rio_code_read_path.putRcvd(32'h0);
                msg_in_cnt <= msg_in_cnt + 1;
        endrule
*/
	rule init (rcvd_in_cnt == 0);
		rio_code_read_path.setPageNum(fromInteger(valueOf(Page_num)));
		err_vec_gen.set_threshold(32'h0020c49c);
		rcvd_in_cnt <= 1;
	endrule
	
        rule inputMessages (rcvd_in_cnt < 576 && rcvd_in_cnt > 0);
		let codeword = get_output(truncate(rcvd_in_cnt)-1, fromInteger(valueOf(Page_num)));
		Bit#(32) err_vec <- err_vec_gen.get_err_vec();
		
                rio_code_read_path.putRcvd(codeword ^ err_vec);
			
		if (rcvd_in_cnt == 575)
			rcvd_in_cnt <= 1;
		else
	                rcvd_in_cnt <= rcvd_in_cnt + 1;
        endrule

	rule displayOut;
		let read_path_out <- rio_code_read_path.getDecoded();
		let ref_data_matlab = get_msg_bit(truncate(msg_out_cnt), fromInteger(valueOf(Page_num)));
		if (read_path_out == ref_data_matlab)
			$display("[%d][%d] Correct", cycle, msg_out_cnt);
		else begin
			$display("[%d] Incorrect [%d] %b", cycle, msg_out_cnt, read_path_out ^ ref_data_matlab);
		end
		if (msg_out_cnt == 255)
			msg_out_cnt <= 0;
		else
			msg_out_cnt <= msg_out_cnt + 1;
	endrule
	
        rule cycleCount;
                cycle <= cycle + 1;
		if (cycle == 20000) begin
			$display("Cycle: %d", cycle);	
			$finish();
		end
                //$display("%d", cycle);
        endrule


endmodule: mkTb
endpackage: Tb

