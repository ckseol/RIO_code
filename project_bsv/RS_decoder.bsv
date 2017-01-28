package RS_decoder;

import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Vector::*;
import RS_syndrome::*;
import RS_BM_algorithm::*;
import RS_chien_search::*;
import RS_common::*;

typedef enum {INIT, GETTING_RCVD, CHECK_SYNDROME, GET_ERR_LOC_POLY, GET_ERR_VAL, WAIT_ERR_EVAL_DONE, ERROR_CORRECTION, UNCORR_CASE, DECODING_DONE} RSDecoderState deriving(Bits, Eq);

interface RSDecoderIfc;
        method Action load_rcvd_bits(SYMBOL msg_bits);
        method ActionValue#(SYMBOL) get_decoded();
endinterface: RSDecoderIfc

(* synthesize, options = "-no-aggressive-conditions" *)
module mkRSDecoder(RSDecoderIfc);

	FIFO#(SYMBOL) fifo_rcvd_symbol_in <- mkPipelineFIFO;
	FIFO#(SYMBOL) fifo_decoded_symbol_out <- mkPipelineFIFO;

        RSSyndromeIfc rs_syndrome <- mkRSSyndrome;
	RSBMAlgorithmIfc rs_bm_alg <- mkRSBMAlgorithm;
	RSChienSearchIfc rs_chien_search <- mkRSChienSearch; 
	RSForneyAlgorithmIfc rs_forney_algorithm <- mkRSForneyAlgorithm;

        Reg#(int) cycle <- mkReg(0);
        Reg#(UInt#(6)) reg_msg_in_cnt <- mkReg(0);
	Reg#(UInt#(6)) reg_decoded_out_cnt <- mkReg(0);
	Vector#(CODEWORD_LEN, Reg#(SYMBOL)) vec_reg_rcvd_symbols <- replicateM(mkReg(0));
        Vector#(CODEWORD_LEN, Reg#(SYMBOL)) vec_reg_err_vec <- replicateM(mkReg(0));
	Reg#(RSDecoderState) reg_state <- mkReg(INIT);

	//rule init (cycle == 0);
	//	msg_in_cnt <= 0;
	//endrule
	FIFO#(POLYNOMIAL) fifo_err_loc_poly <- mkPipelineFIFO;
	FIFO#(POLYNOMIAL) fifo_err_eval_poly <- mkPipelineFIFO;

	FIFOF#(UInt#(6)) fifo_loc_j <- mkPipelineFIFOF;	
	Reg#(UInt#(3)) reg_err_cnt <- mkReg(0);
	Reg#(UInt#(3)) reg_mu <- mkReg(0);

	Reg#(UInt#(6)) reg_raw_err_cnt <- mkReg(0);

	FIFO#(Bool) fifo_uncorr_flag <- mkFIFO1; 

	rule init (reg_state == INIT);
		reg_msg_in_cnt <=0;
		reg_state <= GETTING_RCVD;
		reg_decoded_out_cnt <= 0;
		reg_mu <= 0;
		reg_err_cnt <= 0;
		writeVReg(vec_reg_err_vec, replicate(0));
		//fifo_loc_j.clear();
		//rs_forney_algorithm.clear();
		reg_raw_err_cnt <= 0;
	endrule

        rule inputMessages (reg_msg_in_cnt < fromInteger(valueOf(CODEWORD_LEN)) && reg_state == GETTING_RCVD);
		let rcvd_symbol_in = fifo_rcvd_symbol_in.first;

		reg_raw_err_cnt <= reg_raw_err_cnt + ((rcvd_symbol_in == 0) ? 0 : 1);

		if (reg_msg_in_cnt < fromInteger(valueOf(CODEWORD_LEN)-1)) begin
			reg_state <= GETTING_RCVD;
			fifo_rcvd_symbol_in.deq();
		end
		else
			reg_state <= CHECK_SYNDROME;

		rs_syndrome.load_symbol(rcvd_symbol_in);				
		//msg_in_cnt <= msg_in_cnt + 1;
		//$display("[%d] %d", reg_msg_in_cnt, rcvd_symbol_in);
		vec_reg_rcvd_symbols[reg_msg_in_cnt] <= rcvd_symbol_in;
                reg_msg_in_cnt <= reg_msg_in_cnt + 1;
        endrule

        function Bool isNonzero (SYMBOL a);
                return a != 0;
        endfunction
	
	rule getSyndrome (reg_state == CHECK_SYNDROME);
		//$display("Raw error cnt@RS  decoder: %d", reg_raw_err_cnt); 
		let syndrome_out <-  rs_syndrome.get_syndrome();
		//$display("RS syndrome: %b", syndrome_out);

		if (!any(isNonzero, syndrome_out)) begin
			reg_state <= DECODING_DONE;
			//$display("RS dec: No error");
		end
		else begin
			rs_bm_alg.load_syndrome(syndrome_out);
			//for (Integer i=0 ; i<8 ; i=i+1)
			//	$display("%d, ", syndrome_out[i]);	
			reg_state <= GET_ERR_LOC_POLY;
		end
	endrule

        rule getErrorLocPoly (reg_state == GET_ERR_LOC_POLY);
                let err_loc_poly <- rs_bm_alg.get_err_loc_poly();
		let err_eval_poly <- rs_bm_alg.get_err_eval_poly();
		//rs_chien_search.load_err_loc_poly(err_loc_poly);
		fifo_err_loc_poly.enq(err_loc_poly);
		fifo_err_eval_poly.enq(err_eval_poly);

		let idx = findIndex(isNonzero, reverse(err_loc_poly));
		//if (isValid(idx)) begin
			UInt#(5) mu = fromInteger(valueOf(DOUBLE_T_RS)) - zeroExtend(fromMaybe(?, idx));
			reg_mu <= truncate(mu);
		//end
		rs_chien_search.load_err_loc_poly(err_loc_poly, truncate(mu));
		reg_state <= GET_ERR_VAL;
                //for (Integer i=0 ; i<9 ; i=i+1)
                  //     $display("lambda[%d]: %d", i, err_loc_poly[i]);           
		//$display("mu = %d", mu);
                //for (Integer i=0 ; i<9 ; i=i+1)
                  //      $display("omega[%d]: %d", i, err_eval_poly[i]);		
        endrule

	rule getLocj (reg_state == GET_ERR_VAL);
		let loc_j <- rs_chien_search.get_loc_j();
		rs_forney_algorithm.load_input(fifo_err_loc_poly.first, fifo_err_eval_poly.first, loc_j);
		fifo_loc_j.enq(fromInteger(valueOf(CODEWORD_LEN)) - loc_j - 1);
		$display("loc_j = %d", fromInteger(valueOf(CODEWORD_LEN)) - loc_j - 1);
	endrule
	
	//(* mutually_exclusive = "getErrorValue, checkUncorr" *)
	rule getErrorValue (reg_state == GET_ERR_VAL);
		let err_val <- rs_forney_algorithm.get_err_value();
		let err_loc = fifo_loc_j.first; fifo_loc_j.deq();
		vec_reg_err_vec[err_loc] <= err_val;	
		reg_err_cnt <= reg_err_cnt + 1;
                $display("err_loc = %d, err_val = %d", err_loc, err_val);
	endrule
	
	rule getUncorrFlag (reg_state == GET_ERR_VAL);	
		let uncorr_flag = rs_chien_search.get_uncorr_flag();
                if (isValid(uncorr_flag)) begin
                        fifo_uncorr_flag.enq(fromMaybe(?, uncorr_flag));
                end
	endrule	
	
	rule checkUncorr (reg_state == GET_ERR_VAL);
		if (fifo_uncorr_flag.first)
			reg_state <= UNCORR_CASE;
		else 
			reg_state <= ERROR_CORRECTION;
		fifo_uncorr_flag.deq();
	endrule

	rule errorCorrection (reg_state == ERROR_CORRECTION); 
               	fifo_err_loc_poly.deq();
               	fifo_err_eval_poly.deq();
		for (Integer i=0 ; i<valueOf(CODEWORD_LEN) ; i=i+1)
			vec_reg_rcvd_symbols[i] <= vec_reg_rcvd_symbols[i] ^ vec_reg_err_vec[i];
               	reg_state <= DECODING_DONE;
		//$display("Correctable");	
	endrule

        rule uncorrCase (reg_state == UNCORR_CASE);
                fifo_err_loc_poly.deq();
                fifo_err_eval_poly.deq();
                reg_state <= DECODING_DONE;
                $display("Uncorrectable");
        endrule


	rule decodingDone (reg_state == DECODING_DONE);
		fifo_decoded_symbol_out.enq(vec_reg_rcvd_symbols[reg_decoded_out_cnt]);
		if (reg_decoded_out_cnt == fromInteger(valueOf(MESSAGE_LEN) - 1)) begin
			fifo_rcvd_symbol_in.deq();		
			reg_state <= INIT;
		end
		else begin
			reg_decoded_out_cnt <= reg_decoded_out_cnt + 1;
			reg_state <= DECODING_DONE;
		end
	endrule

        method Action load_rcvd_bits(SYMBOL msg_bits);
		fifo_rcvd_symbol_in.enq(msg_bits);
	endmethod

        method ActionValue#(SYMBOL) get_decoded();
		fifo_decoded_symbol_out.deq();
		return fifo_decoded_symbol_out.first;	
	endmethod

endmodule: mkRSDecoder

endpackage: RS_decoder

