package noise_gen;

import Vector::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Xorshift_r12_m5::*;


interface NoiseGenIfc;
	method Action set_threshold(UInt#(BIT_WIDTH) threshold);
	method ActionValue#(Bit#(N_RANDINT)) get_err_vec();
endinterface: NoiseGenIfc

(* synthesize, options = "-no-aggressive-conditions" *)
module mkNoiseGen(NoiseGenIfc);
	Xorshift_r12_m5_Ifc rng <- mkXorshift_r12_m5;
	FIFO#(Bit#(N_RANDINT)) fifo_err_vec_out <- mkPipelineFIFO;
	Reg#(UInt#(BIT_WIDTH)) reg_threshold <- mkReg(0);
	
	rule gen_err_vec;
		let randnum <- rng.get_val();
		Bit#(N_RANDINT) err_vec;
		for (Integer i=0 ; i<valueOf(N_RANDINT) ; i=i+1) begin
			err_vec[i] = unpack(randnum[i]) >= reg_threshold ? 0 : 1;
			//$display("[%d] %d", i, randnum[i]);
		end
		fifo_err_vec_out.enq(err_vec);
	endrule
 
        method Action set_threshold(UInt#(BIT_WIDTH) threshold);
		reg_threshold <= threshold;
	endmethod

        method ActionValue#(Bit#(N_RANDINT)) get_err_vec();
		fifo_err_vec_out.deq();
		return fifo_err_vec_out.first;
	endmethod

endmodule: mkNoiseGen

endpackage: noise_gen
