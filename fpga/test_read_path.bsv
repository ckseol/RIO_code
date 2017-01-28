package test_read_path;

import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Vector::*;
import RIO_code_scheme_read_path::*;
import noise_gen::*;

typedef 288 CODEWORD_LEN;
typedef struct { UInt#(32) frm_err_cnt; UInt#(64) frm_cnt; } Frm_err_prob deriving(Bits, Eq);
typedef enum {INIT, SIM_DECODING} Tester_state deriving(Bits, Eq);

function UInt#(9) get_msg_bit_len(UInt#(3) page_num);
        return case (page_num)
                3'd0: 9'd256;
                3'd1: 9'd256;
                3'd2: 9'd256;
                3'd3: 9'd192;
                3'd4: 9'd128;
                3'd5: 9'd128;
                3'd6: 9'd64;
        endcase;
endfunction

interface TestReadPathIfc;
	method Action set_page_num(UInt#(3) page_num);
	method Action set_err_threshold(UInt#(32) threshold);
	method Action stop_dec();
	method Action start_dec();
	method Action reset_sim();
	method Frm_err_prob get_frm_err_prob();
endinterface

(* synthesize *)
module mkTestReadPath (TestReadPathIfc);
	//RIOCodeSchemeReadPathIfc rio_code_read_path <- mkRIOCodeSchemeReadPath;
	NoiseGenIfc err_vec_gen <- mkNoiseGen;

	FIFO#(UInt#(3)) fifo_page_num_in <- mkFIFO1;
	FIFO#(UInt#(32)) fifo_threshold_in <- mkFIFO1;

	Reg#(Frm_err_prob) reg_frm_err_prob <- mkRegU;
	Reg#(Tester_state) reg_state <- mkReg(INIT);
	
	Reg#(UInt#(32)) reg_rcvd_in_cnt <- mkReg(0);
	Reg#(UInt#(32)) reg_msg_out_cnt <- mkReg(0);

	Reg#(UInt#(16)) reg_err_cnt <- mkReg(0);

	Reg#(UInt#(16)) reg_raw_err_cnt <- mkReg(0);
	Reg#(UInt#(32)) reg_total_raw_err_cnt <- mkReg(0);

	FIFO#(Bool) fifo_sim_dec <- mkPipelineFIFO;

	//Clock clk <- exposeCurrentClock;
	//Reset rst <- exposeCurrentReset;
	//Reg#(bit) rst_read_path <- mkRegA(0, clocked_by clk, reset_by rst);
	RIOCodeSchemeReadPathIfc rio_code_read_path <- mkRIOCodeSchemeReadPath;

	rule init (reg_state == INIT);
		//rio_code_read_path.setPageNum(fifo_page_num_in.first);
		err_vec_gen.set_threshold(fifo_threshold_in.first);
		Frm_err_prob frm_err_prob_init;
		frm_err_prob_init.frm_err_cnt = 0;
		frm_err_prob_init.frm_cnt = 0;
		reg_total_raw_err_cnt <= 0;
		reg_frm_err_prob <= frm_err_prob_init;
		reg_state <= SIM_DECODING;

		$display("[INIT] Page num: %d", fifo_page_num_in.first);
		$display("[INIT] Threshold: %d", fifo_threshold_in.first);
		$display("reg_rcvd_in_cnt = %d", reg_rcvd_in_cnt);
		$display("reg_msg_out_cnt = %d", reg_msg_out_cnt);

		//reg_err_cnt <= 0;
		//reg_rcvd_in_cnt <= 0;
		//reg_msg_out_cnt <= 0;
	endrule

	rule set_decoder_page_num (reg_state == SIM_DECODING && fifo_sim_dec.first);
		rio_code_read_path.setPageNum(fifo_page_num_in.first);
	endrule
	
        rule gen_zero_codeword (reg_state == SIM_DECODING && fifo_sim_dec.first);
		Bit#(64) codeword = 64'b0;//get_output(truncate(rcvd_in_cnt)-1, fromInteger(valueOf(Page_num)));
		//Bit#(64) mask = '1 >> 32;
		Bit#(64) err_vec <- err_vec_gen.get_err_vec();
                //rio_code_read_path.putRcvd(codeword ^ err_vec);
		//$display("[%d] %b",reg_rcvd_in_cnt, err_vec); 
		if (reg_rcvd_in_cnt == fromInteger(valueOf(CODEWORD_LEN)-1)) begin
			
			rio_code_read_path.putRcvd(codeword ^ err_vec);
			let raw_err_cnt = reg_raw_err_cnt + zeroExtend(countOnes(err_vec));
			reg_raw_err_cnt <= 0;
			reg_rcvd_in_cnt <= 0;
			$display("Raw error count: %d", raw_err_cnt);
			reg_total_raw_err_cnt <= reg_total_raw_err_cnt + zeroExtend(raw_err_cnt);
		end
		else begin
			rio_code_read_path.putRcvd(codeword ^ err_vec);

			if (reg_rcvd_in_cnt == 0)
				reg_raw_err_cnt <= zeroExtend(countOnes(err_vec));
			else
				reg_raw_err_cnt <= reg_raw_err_cnt + zeroExtend(countOnes(err_vec));

	                reg_rcvd_in_cnt <= reg_rcvd_in_cnt + 1;
		end
        endrule

	rule get_result (reg_state == SIM_DECODING && fifo_sim_dec.first);
		let read_path_out <- rio_code_read_path.getDecoded();
		UInt#(16) current_err_cnt = zeroExtend(countOnes(read_path_out));
		UInt#(16) err_cnt = reg_err_cnt + current_err_cnt;  
		let frm_err_prob = reg_frm_err_prob;
		//let ref_data_matlab = get_msg_bit(truncate(msg_out_cnt), fromInteger(valueOf(Page_num)));

	/*	
		if (current_err_cnt == 0)
			$display("[%d][%d] Correct", frm_err_prob.frm_cnt, reg_msg_out_cnt);
		else begin
			$display("[%d] Incorrect [%d] %d", frm_err_prob.frm_cnt, reg_msg_out_cnt, current_err_cnt);
		end
	*/	
		//if (reg_msg_out_cnt == zeroExtend(get_msg_bit_len(fifo_page_num_in.first)-1)) begin
                if (reg_msg_out_cnt == zeroExtend((get_msg_bit_len(fifo_page_num_in.first) >> 1)-1)) begin

			frm_err_prob.frm_cnt = frm_err_prob.frm_cnt + 1;

			if (err_cnt > 0)
				frm_err_prob.frm_err_cnt = frm_err_prob.frm_err_cnt + 1;

			$display("FRM[%d], FRM err cnt=%d, Total raw err cnt=%d", frm_err_prob.frm_cnt, frm_err_prob.frm_err_cnt, reg_total_raw_err_cnt);

			reg_frm_err_prob <= frm_err_prob;		
			reg_msg_out_cnt <= 0;
			reg_err_cnt <= 0;
		end
		else begin
			reg_msg_out_cnt <= reg_msg_out_cnt + 1;
			reg_err_cnt <= err_cnt;
		end
	endrule

	rule back_to_init (reg_state == SIM_DECODING && !fifo_sim_dec.first);
		reg_state <= INIT;
		fifo_page_num_in.deq();
		fifo_threshold_in.deq();
		fifo_sim_dec.deq();		
	endrule

        method Action set_page_num(UInt#(3) page_num);
		fifo_page_num_in.enq(page_num);
		//rio_code_read_path.setPageNum(fifo_page_num_in.first);
	endmethod

        method Action set_err_threshold(UInt#(32) threshold);
		fifo_threshold_in.enq(threshold);
                //rio_code_read_path.setPageNum(fifo_page_num_in.first);
                //err_vec_gen.set_threshold(fifo_threshold_in.first);
	endmethod

	method Action stop_dec();
		fifo_sim_dec.deq();
	endmethod

	method Action start_dec();
		fifo_sim_dec.enq(True);
	endmethod

	method Action reset_sim();
		fifo_sim_dec.enq(False);
	endmethod

        method Frm_err_prob get_frm_err_prob();
		return reg_frm_err_prob;
	endmethod

endmodule: mkTestReadPath
endpackage: test_read_path

