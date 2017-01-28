package RS_encoder;

import FIFO::*;
import SpecialFIFOs::*;
import RS_common::*;
import Vector::*;

function PARITY encode(PARITY x, Bit#(6) u);
	PARITY y;
	y[0] = gf_mul_m6(x[17], 6'd25)^gf_mul_m6(u[5:0], 6'd25);
	y[1] = gf_mul_m6(x[0], 6'd1)^gf_mul_m6(x[17], 6'd13)^gf_mul_m6(u[5:0], 6'd13);
	y[2] = gf_mul_m6(x[1], 6'd1)^gf_mul_m6(x[17], 6'd8)^gf_mul_m6(u[5:0], 6'd8);
	y[3] = gf_mul_m6(x[2], 6'd1)^gf_mul_m6(x[17], 6'd43)^gf_mul_m6(u[5:0], 6'd43);
	y[4] = gf_mul_m6(x[3], 6'd1)^gf_mul_m6(x[17], 6'd11)^gf_mul_m6(u[5:0], 6'd11);
	y[5] = gf_mul_m6(x[4], 6'd1)^gf_mul_m6(x[17], 6'd35)^gf_mul_m6(u[5:0], 6'd35);
	y[6] = gf_mul_m6(x[5], 6'd1)^gf_mul_m6(x[17], 6'd9)^gf_mul_m6(u[5:0], 6'd9);
	y[7] = gf_mul_m6(x[6], 6'd1)^gf_mul_m6(x[17], 6'd61)^gf_mul_m6(u[5:0], 6'd61);
	y[8] = gf_mul_m6(x[7], 6'd1)^gf_mul_m6(x[17], 6'd34)^gf_mul_m6(u[5:0], 6'd34);
	y[9] = gf_mul_m6(x[8], 6'd1)^gf_mul_m6(x[17], 6'd37)^gf_mul_m6(u[5:0], 6'd37);
	y[10] = gf_mul_m6(x[9], 6'd1)^gf_mul_m6(x[17], 6'd3)^gf_mul_m6(u[5:0], 6'd3);
	y[11] = gf_mul_m6(x[10], 6'd1)^gf_mul_m6(x[17], 6'd59)^gf_mul_m6(u[5:0], 6'd59);
	y[12] = gf_mul_m6(x[11], 6'd1)^gf_mul_m6(x[17], 6'd27)^gf_mul_m6(u[5:0], 6'd27);
	y[13] = gf_mul_m6(x[12], 6'd1)^gf_mul_m6(x[17], 6'd49)^gf_mul_m6(u[5:0], 6'd49);
	y[14] = gf_mul_m6(x[13], 6'd1)^gf_mul_m6(x[17], 6'd8)^gf_mul_m6(u[5:0], 6'd8);
	y[15] = gf_mul_m6(x[14], 6'd1)^gf_mul_m6(x[17], 6'd1)^gf_mul_m6(u[5:0], 6'd1);
	y[16] = gf_mul_m6(x[15], 6'd1)^gf_mul_m6(x[17], 6'd61)^gf_mul_m6(u[5:0], 6'd61);
	y[17] = gf_mul_m6(x[16], 6'd1)^gf_mul_m6(x[17], 6'd53)^gf_mul_m6(u[5:0], 6'd53);
	return y;
endfunction


interface RSEncoderIfc;
        method Action load_msg_bits(SYMBOL msg_bits);
        method ActionValue#(SYMBOL) get_encoded();
endinterface: RSEncoderIfc

(* synthesize, options = "-no-aggressive-conditions" *)
module mkRSEncoder(RSEncoderIfc);
	Reg#(PARITY) reg_state_vector <- mkReg(replicate(0)); 
	FIFO#(SYMBOL) fifo_msg_in <- mkPipelineFIFO;
	FIFO#(PARITY) fifo_parity <- mkPipelineFIFO;
	FIFO#(SYMBOL) fifo_parity_out <- mkPipelineFIFO;
	Reg#(UInt#(6)) reg_in_cnt <- mkReg(0);
	Reg#(UInt#(5)) reg_out_cnt <- mkReg(0);
	
	(* mutually_exclusive = "encoding, parity_out" *)
	rule encoding (reg_in_cnt < fromInteger(valueOf(MESSAGE_LEN)));
		let current_in = fifo_msg_in.first;
		fifo_msg_in.deq();
		fifo_parity_out.enq(current_in);
		reg_state_vector <= encode(reg_state_vector, current_in);
		reg_in_cnt <= reg_in_cnt + 1;
		//$display("%d, %b", reg_in_cnt, current_in);
	endrule

	rule encoding_done (reg_in_cnt == fromInteger(valueOf(MESSAGE_LEN)));
		fifo_parity.enq(reg_state_vector);
		reg_state_vector <= replicate(0);
		reg_in_cnt <= 0;
	endrule

	rule parity_out (reg_out_cnt < fromInteger(valueOf(PARITY_LEN)));
		let parity_vec = fifo_parity.first;
		UInt#(5) idx = fromInteger(valueOf(PARITY_LEN)) - reg_out_cnt - 1;
		fifo_parity_out.enq(parity_vec[idx]);
		reg_out_cnt <= reg_out_cnt + 1;
	endrule

        rule parity_out_done (reg_out_cnt == fromInteger(valueOf(PARITY_LEN)));
                fifo_parity.deq();
                reg_out_cnt <= 0;
        endrule


        method Action load_msg_bits(SYMBOL msg_bits);
		fifo_msg_in.enq(msg_bits);
	endmethod

        method ActionValue#(SYMBOL) get_encoded();
		fifo_parity_out.deq();
		return fifo_parity_out.first;
	endmethod

endmodule: mkRSEncoder

endpackage: RS_encoder

