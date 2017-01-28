package Xorshift_r12_m5;

import Vector::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import xorshift_rng_r12_m5_logic::*;

typedef 32 BIT_WIDTH;
typedef 64 N_RANDINT;
typedef 384 STATE_BIT;


interface Xorshift_r12_m5_Ifc;
	method ActionValue#(Vector#(N_RANDINT, Bit#(BIT_WIDTH))) get_val();
endinterface: Xorshift_r12_m5_Ifc

(* synthesize, options = "-no-aggressive-conditions" *)
module mkXorshift_r12_m5(Xorshift_r12_m5_Ifc);
	Reg#(Bit#(STATE_BIT)) reg_state <- mkReg(384'hcf67408f_89e1a217_ca78e2dc_47543f74_e9f6a274_d2386c4a_1a10e70f_ad924199_46853fac_dba3beed_6ee7119f_21331885);
	FIFO#(Vector#(N_RANDINT, Bit#(BIT_WIDTH))) fifo_val_out <- mkPipelineFIFO;

	rule update_state;
		let val = parallel_randint32(reg_state);
		reg_state <= update_state(reg_state);
		fifo_val_out.enq(val);
		//$display("%b, %b", reg_state0, reg_state1);
	endrule

	method ActionValue#(Vector#(N_RANDINT, Bit#(BIT_WIDTH))) get_val();
		fifo_val_out.deq();
		return fifo_val_out.first;
	endmethod

endmodule: mkXorshift_r12_m5

endpackage: Xorshift_r12_m5 
