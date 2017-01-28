package BCH_decoder;

import FIFO::*;
import SpecialFIFOs::*;
import Vector::*;
import BCH_BM_no_inv::*;
import BCH_chien_search::*;
import BCH_common::*;


interface BCHDecoderIfc;
        method Action load_rcvd_bits(MESSAGE rcvd_bits);
	method ActionValue#(Bool) is_no_error();
        method ActionValue#(Bit#(64)) get_err_vec();
endinterface: BCHDecoderIfc

(* synthesize, options = "-no-aggressive-conditions" *)
module mkBCHDecoder(BCHDecoderIfc);
	Reg#(Bit#(PARITY_LEN)) reg_g <- mkReg(0);
	FIFO#(SYNDROME) fifo_syndrome <- mkPipelineFIFO;
	BMAlgorithmIfc bm_algorithm <- mkBMAlgorithm;
	ChienSearchIfc chien_search <- mkChienSearch;

	FIFO#(MESSAGE) fifo_loaded_rcvd_bits <- mkPipelineFIFO;
	Reg#(UInt#(10)) reg_cnt <- mkReg(0);

	//FIFO#(Bit#(64)) fifo_err_vec <- mkPipelineFIFO;
	FIFO#(Bool) fifo_is_no_error_out <- mkPipelineFIFO;
		
	Reg#(UInt#(16)) reg_raw_err_cnt <- mkReg(0);

	rule get_rcvd_bits (reg_cnt <= 10'd260);
		let rcvd_bits = fifo_loaded_rcvd_bits.first;
		//if (rcvd_bits != 0)
		//	$display("Input, [%d] %b", reg_cnt, rcvd_bits);
		fifo_loaded_rcvd_bits.deq();

		reg_raw_err_cnt <= reg_raw_err_cnt + zeroExtend(countOnes(rcvd_bits));

		reg_g <= update_g(reg_g, rcvd_bits);
	//	if (reg_cnt == 10'd260)
	//		$display("Last input: %b", rcvd_bits);
		reg_cnt <= reg_cnt + 1;
	endrule

	rule get_syndrome (reg_cnt == 10'd261);
		fifo_syndrome.enq(get_syndrome(reg_g));
		reg_g <= 0;
		reg_cnt <= 0;
		reg_raw_err_cnt <= 0;
		//$display("Raw error cnt@BCH decoder: %d", reg_raw_err_cnt);
	endrule	

        function Bool isNonzero (GF_SYM a);
                return a != 0;
        endfunction

	rule load_syndrome_to_bm_algorithm;
		let syndrome = fifo_syndrome.first;
	//	for (int i=0 ; i<40 ; i=i+1)
	//		$display("Syndrome[%d]=%b", i, syndrome[i]);
		if (any(isNonzero, syndrome)) begin
			fifo_is_no_error_out.enq(False);
	                bm_algorithm.load_syndrome(fifo_syndrome.first);			
		end
		else begin
			//$display("BCH dec: No error");
			fifo_is_no_error_out.enq(True);
		end
		fifo_syndrome.deq();
	endrule

	rule get_err_loc_poly;
                let err_loc_pol_full <- bm_algorithm.get_err_loc_poly();
		POLYNOMIAL_CHIEN err_loc_pol_ain;
		
                for (Integer i=0 ; i<=valueOf(T_BCH) ; i=i+1) begin
			err_loc_pol_ain[i] = err_loc_pol_full[i];
          //              $display("[%d] %b", i, err_loc_pol_full[i]);
		end
                //$finish;
                chien_search.load_err_loc_poly(err_loc_pol_ain);
	endrule
/*
	rule get_err_vector;
		Bit#(64) err_vec <- chien_search.get_err_vector();
		fifo_err_vec.enq(err_vec);
	endrule
*/
	Reg#(UInt#(8)) reg_out_cnt <- mkReg(0);	
        method Action load_rcvd_bits(MESSAGE rcvd_bits);
		fifo_loaded_rcvd_bits.enq(rcvd_bits);
	endmethod

        method ActionValue#(Bool) is_no_error();
		fifo_is_no_error_out.deq();
		return fifo_is_no_error_out.first;	
	endmethod
	
        method ActionValue#(Bit#(64)) get_err_vec();
		Bit#(64) err_vec <- chien_search.get_err_vector();
		//if (err_vec != 0)
		//	$display("[Err out] [%d] %b", reg_out_cnt, err_vec);
		reg_out_cnt <= reg_out_cnt + 1;
		return err_vec;
		//fifo_err_vec.deq();
		//return fifo_err_vec.first;
	endmethod

endmodule: mkBCHDecoder

endpackage: BCH_decoder

