package RS_syndrome;
import Vector::*;
import FIFO::*;
import SpecialFIFOs::*;
import RS_common::*;

function SYNDROME update_syndrome(SYNDROME s_k, Bit#(6) r);
	SYNDROME s_k_next;
	s_k_next[0] = r ^ gf_mul_m6(s_k[0], 6'd2);
	s_k_next[1] = r ^ gf_mul_m6(s_k[1], 6'd4);
	s_k_next[2] = r ^ gf_mul_m6(s_k[2], 6'd8);
	s_k_next[3] = r ^ gf_mul_m6(s_k[3], 6'd16);
	s_k_next[4] = r ^ gf_mul_m6(s_k[4], 6'd32);
	s_k_next[5] = r ^ gf_mul_m6(s_k[5], 6'd3);
	s_k_next[6] = r ^ gf_mul_m6(s_k[6], 6'd6);
	s_k_next[7] = r ^ gf_mul_m6(s_k[7], 6'd12);
	s_k_next[8] = r ^ gf_mul_m6(s_k[8], 6'd24);
	s_k_next[9] = r ^ gf_mul_m6(s_k[9], 6'd48);
	s_k_next[10] = r ^ gf_mul_m6(s_k[10], 6'd35);
	s_k_next[11] = r ^ gf_mul_m6(s_k[11], 6'd5);
	s_k_next[12] = r ^ gf_mul_m6(s_k[12], 6'd10);
	s_k_next[13] = r ^ gf_mul_m6(s_k[13], 6'd20);
	s_k_next[14] = r ^ gf_mul_m6(s_k[14], 6'd40);
	s_k_next[15] = r ^ gf_mul_m6(s_k[15], 6'd19);
	s_k_next[16] = r ^ gf_mul_m6(s_k[16], 6'd38);
	s_k_next[17] = r ^ gf_mul_m6(s_k[17], 6'd15);
	return s_k_next;
endfunction


interface RSSyndromeIfc;
        method Action load_symbol(SYMBOL symbols);
        method ActionValue#(SYNDROME) get_syndrome();
endinterface: RSSyndromeIfc

(* synthesize, options = "-no-aggressive-conditions" *)
module mkRSSyndrome(RSSyndromeIfc);
        Reg#(SYNDROME) reg_syndrome <- mkReg(replicate(0));
        FIFO#(SYMBOL) fifo_symbol_in <- mkBypassFIFO;
        FIFO#(SYNDROME) fifo_syndrome_out <- mkPipelineFIFO;
        Reg#(UInt#(SYM_CNT_BIT_WIDTH)) reg_cnt <- mkReg(0);

        rule encoding (reg_cnt < fromInteger(valueOf(CODEWORD_LEN)));
                let current_in = fifo_symbol_in.first;
                fifo_symbol_in.deq();
                reg_syndrome <= update_syndrome(reg_syndrome, current_in);
                reg_cnt <= reg_cnt + 1;
                //$display("%d, %b", reg_cnt, current_in);
        endrule

        rule encoding_done (reg_cnt == fromInteger(valueOf(CODEWORD_LEN)));
                fifo_syndrome_out.enq(reg_syndrome);
                reg_syndrome <= replicate(0);
                reg_cnt <= 0;
        endrule

        method Action load_symbol(SYMBOL symbols);
                fifo_symbol_in.enq(symbols);
        endmethod

        method ActionValue#(SYNDROME) get_syndrome();
                let syndrome = fifo_syndrome_out.first;
                fifo_syndrome_out.deq();
                return syndrome;
        endmethod

endmodule: mkRSSyndrome



endpackage: RS_syndrome

