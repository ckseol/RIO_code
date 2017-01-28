package RIO_code_scheme_read_path;

import FIFO::*;
import FIFOF::*;
import Vector::*;
import FIFO::*;
import SpecialFIFOs::*;

//import RIO_encoder_1st::*;
import RIO_code_2nd::*;
//import BCH_encoder::*;
//import RS_encoder::*;

import RIO_decoder_1st::*;
import BCH_decoder::*;
import RS_decoder::*;

import RIO_code_scheme_common::*;
 
interface RIOCodeSchemeReadPathIfc;
	method Action putRcvd(Bit#(64) rcvd);
	method Action setPageNum(UInt#(3) page_num);
	method ActionValue#(Bit#(64)) getDecoded();
endinterface: RIOCodeSchemeReadPathIfc

(* synthesize, options = "-no-aggressive-conditions" *)
module mkRIOCodeSchemeReadPath(RIOCodeSchemeReadPathIfc);

	RIODecoder2ndIfc rio_decoder_2nd <- mkRIODecoder2nd;
	BCHDecoderIfc bch_decoder <- mkBCHDecoder;
	RSDecoderIfc rs_decoder <- mkRSDecoder;
	RIODecoder1stIfc rio_decoder_1st <- mkRIODecoder1st;
	
	FIFO#(Bit#(64)) fifo_rcvd_in <- mkPipelineFIFO;
	//FIFO#(DATA_32BIT) fifo_decoded_out <- mkPipelineFIFO;

	Reg#(DATA_CNT) reg_rcvd_data_cnt <- mkReg(0);
	Reg#(DATA_CNT) reg_bch_parity_cnt <- mkReg(0);
	Reg#(Bool)     reg_data_in_done <- mkReg(False);
	Reg#(DATA_CNT) reg_rs_decoded_out_cnt <- mkReg(0);
	Reg#(DATA_CNT) reg_split_data_cnt <- mkReg(0);

        CombinerIfc#(6, 64) combiner1 <- mkCombiner;
        //CombinerIfc#(64, 256) combiner2_1 <- mkCombiner;
        //CombinerIfc#(64, 256) combiner2_2 <- mkCombiner;
        SplitterIfc#(64, 32) splitter <- mkSplitter;
	SplitterIfc#(256, 64) splitter_output <- mkSplitter;

        rule rcvd_data_to_splitter (reg_rcvd_data_cnt < fromInteger(valueOf(RIO_CODE_2ND_DATA_LEN)));
                splitter.put(fifo_rcvd_in.first);
		fifo_rcvd_in.deq();
                reg_rcvd_data_cnt <= reg_rcvd_data_cnt + 1;
        endrule
	
        rule splitter_to_rio_decoder_2nd; 
		let rcvd_split <- splitter.getSplit();
		if (reg_split_data_cnt < fromInteger(valueOf(RS_ENCODED_LEN))) begin
			rio_decoder_2nd.loadEncodedBits(rcvd_split);
                	reg_split_data_cnt <= reg_split_data_cnt + 1;
		end
		else 
			reg_split_data_cnt <= 0; 
        endrule

	rule rcvd_data_to_bch_decoder (reg_rcvd_data_cnt >= fromInteger(valueOf(RIO_CODE_2ND_DATA_LEN)) && !reg_data_in_done);
		bch_decoder.load_rcvd_bits(fifo_rcvd_in.first);
		//combiner2_1.put(fifo_rcvd_in.first, False);
		rio_decoder_1st.load_encoded_bits(fifo_rcvd_in.first);
		// $display("[to combiner2_1] %b", fifo_rcvd_in.first);
		fifo_rcvd_in.deq();
		if (reg_rcvd_data_cnt < fromInteger(valueOf(MAX_DATA_CNT) -1))
			reg_rcvd_data_cnt <= reg_rcvd_data_cnt + 1;
		else begin
			reg_data_in_done <= True;
			reg_rcvd_data_cnt <= 0;
		end
	endrule

	rule rio_decoder_2nd_to_rs_decoder;
		let rio_2nd_decoded <- rio_decoder_2nd.getDecodedResult();
	//	$display("RS dec in: %b", rio_2nd_decoded);
		rs_decoder.load_rcvd_bits(rio_2nd_decoded);
	endrule

	rule rs_decoder_to_combiner1;
		let rs_decoded <- rs_decoder.get_decoded();
		if (reg_rs_decoded_out_cnt < fromInteger(valueOf(RS_INFO_LEN)-1)) begin
			reg_rs_decoded_out_cnt <= reg_rs_decoded_out_cnt + 1;
			combiner1.put(rs_decoded, False);
		end
		else begin
                        reg_rs_decoded_out_cnt <= 0;
                        combiner1.put(rs_decoded, True);			
		end
	endrule

	rule combiner1_to_bch_decoder (reg_data_in_done);
		let rs_decoded_combined <- combiner1.getCombined();
		bch_decoder.load_rcvd_bits(rs_decoded_combined);
		if (reg_bch_parity_cnt < fromInteger(valueOf(MAX_PARITY_CNT)-1))
			reg_bch_parity_cnt <= reg_bch_parity_cnt + 1;
		else begin
			reg_data_in_done <= False;
			reg_bch_parity_cnt <= 0;
		end
	endrule
/*
	rule combiner2_1_to_rio_decoder_1st;
		let rcvd_in_combined <- combiner2_1.getCombined();
		rio_decoder_1st.load_encoded_bits(rcvd_in_combined);
	endrule
*/
	rule bch_decoder_to_rio_decoder_1st_err_reporting;
		Bool is_no_error <- bch_decoder.is_no_error();
		rio_decoder_1st.set_no_error(is_no_error);
	endrule

	rule bch_decoder_to_rio_decoder_1st_err_vector;
		let err_vec <- bch_decoder.get_err_vec();
		rio_decoder_1st.load_err_vec(err_vec);
	endrule
/*
	rule bch_decoder_to_combiner2;
		let err_vec <- bch_decoder.get_err_vec();
		combiner2_2.put(err_vec, False);
	endrule

	rule combiner2_2_to_rio_decoder_1st_err_vector;
                let err_vec_combined <- combiner2_2.getCombined();
                rio_decoder_1st.load_err_vec(err_vec_combined);		
	endrule


        rule bch_decoder_to_rio_decoder_1st_err_vector;
                let err_vec <- bch_decoder.get_err_vec();
                rio_decoder_1st.load_err_vec(err_vec);
        endrule
*/
/*
	rule rio_decoder_1st_to_splitter;
		let rio_decoded <- rio_decoder_1st.get_decoded();
		splitter.put(rio_decoded);
	endrule 

	rule splitter_to_out_fifo;
		let rio_decoded_split <- splitter.getSplit();
		fifo_decoded_out.enq(rio_decoded_split);
	endrule
*/
	rule rio_decoder_1st_to_splitter_output;
		let rio_decoded <- rio_decoder_1st.get_decoded();
		splitter_output.put(rio_decoded);
	endrule
	
        method Action putRcvd(Bit#(64) rcvd);
		fifo_rcvd_in.enq(rcvd);
	endmethod

	method Action setPageNum(UInt#(3) page_num);
		rio_decoder_1st.set_page_num(page_num);
	endmethod

        method ActionValue#(Bit#(64)) getDecoded();
		//fifo_decoded_out.deq();
		//return fifo_decoded_out.first;
		let rio_decoded_split <- splitter_output.getSplit();
                return rio_decoded_split;
	endmethod

endmodule: mkRIOCodeSchemeReadPath

endpackage: RIO_code_scheme_read_path
