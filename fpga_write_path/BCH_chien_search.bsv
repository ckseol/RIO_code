package BCH_chien_search;

import FIFO::*;
import SpecialFIFOs::*;
import Vector::*;
import BCH_common::*;

interface ChienSearchIfc;
        method Action load_err_loc_poly(POLYNOMIAL_CHIEN  elp);
        method ActionValue#(Bit#(64)) get_err_vector();
endinterface: ChienSearchIfc

(* synthesize, options = "-no-aggressive-conditions" *)
module mkChienSearch(ChienSearchIfc);
	FIFO#(POLYNOMIAL_CHIEN) fifo_elp_in <- mkFIFO1;
	Reg#(POLYNOMIAL_CHIEN) reg_buffer <- mkRegU;
	Reg#(GF_SYM) reg_lambda0 <- mkRegU;
	Reg#(UInt#(11)) reg_cnt <- mkReg(0);

	FIFO#(Bit#(64)) fifo_err_vec_out <- mkPipelineFIFO;
	FIFO#(Vector#(64, Bit#(15))) fifo_elp_eval <- mkPipelineFIFO;

        rule update_buffer_init(reg_cnt == 0);
                let elp = fifo_elp_in.first;
		reg_buffer <= init_reg_buffer(elp);
		reg_cnt <= reg_cnt + 1;
        endrule
	

	rule update_buffer (reg_cnt > 0);
		if (reg_cnt <= 11'd256) begin
			reg_buffer <= update_reg_buffer(reg_buffer);
			fifo_elp_eval.enq(elp_evaluated(reg_buffer));
			reg_cnt <= reg_cnt + 1;
		end
		else begin
			fifo_elp_in.deq();
			reg_cnt <= 0;
		end
	endrule

	rule from_elp_eval_to_err_vector;
		let elp_eval = fifo_elp_eval.first; fifo_elp_eval.deq();
		Bit#(64) err_vec = 0;
		for (Integer i=0 ; i<64 ; i=i+1)
			err_vec[i] = elp_eval[i] == 15'd0 ? 1 : 0;
		fifo_err_vec_out.enq(err_vec);
	endrule

        method Action load_err_loc_poly(POLYNOMIAL_CHIEN elp);
		fifo_elp_in.enq(elp);
	endmethod

        method ActionValue#(Bit#(64)) get_err_vector();	
		let out = fifo_err_vec_out.first;
		fifo_err_vec_out.deq();
		return out;
	endmethod

endmodule: mkChienSearch

endpackage: BCH_chien_search

