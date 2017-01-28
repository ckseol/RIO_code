package RIO_decoder_1st;

import Vector::*;
import FIFO::*;
import SpecialFIFOs::*;
import RIO_subencoder_1st::*;
import BlockInterleaver::*;
//import LLRUpdater::*;
import Demapper::*;

//typedef Bit#(32) MESSAGE;
//typedef Bit#(128) ENCODED;

//`include "polar_codec_common.bsv"
import Polar_codec_common_revised::*;

//`include "encoder_config.bsv"
 
interface RIODecoder1stIfc;
	method Action load_encoded_bits(ENCODED encoded_bits);
	method Action set_page_num(UInt#(3) page_num);
	method Action set_no_error(Bool is_no_error);
	method Action load_err_vec(ENCODED err_vec);
	method ActionValue#(MESSAGE) get_decoded();
endinterface: RIODecoder1stIfc

(* synthesize, options = "-no-aggressive-conditions" *)
module mkRIODecoder1st(RIODecoder1stIfc);
	BlockInterleaverIfc#(64, 256, 8, 6) block_intlv_1 <- mkBlockInterleaver;
	BlockInterleaverIfc#(64, 256, 8, 6) block_intlv_2 <- mkBlockInterleaver;
	Reg#(Bool) reg_bi_ind_in <- mkReg(False);
	Reg#(Bool) reg_bi_ind_err_in <- mkReg(False);
	Reg#(Bool) reg_bi_ind_out <- mkReg(False);

	DemapperIfc demapper <- mkDemapper;

	FIFO#(ENCODED) fifo_encoded_bits_in <- mkPipelineFIFO;
        FIFO#(ENCODED) fifo_encoded_err_vec <- mkPipelineFIFO;

	Reg#(UInt#(6)) reg_subcodeword_cnt <- mkReg(0);
	
	Reg#(Bool) reg_buf1_full <- mkReg(False);
	Reg#(Bool) reg_buf2_full <- mkReg(False);
	Reg#(Bool) reg_err_cor_done <- mkReg(False);

	Reg#(UInt#(8)) reg_enc_in_cnt <- mkReg(0); 
	Reg#(UInt#(8)) reg_err_vec_in_cnt <- mkReg(0);
	FIFO#(Bool) fifo_no_error <- mkFIFO1;


	rule state_msg_in1 (!reg_buf1_full && !reg_bi_ind_in);
			block_intlv_1.put_row(fifo_encoded_bits_in.first, reg_enc_in_cnt); fifo_encoded_bits_in.deq();
                	if (reg_enc_in_cnt < 8'd255)
                        	reg_enc_in_cnt <= reg_enc_in_cnt + 1;
               		else if (reg_enc_in_cnt == 8'd255) begin
                                reg_buf1_full <= True;
                        	reg_bi_ind_in <= True;
                        	reg_enc_in_cnt <= 0;
                	end
	endrule

        rule state_msg_in2 (!reg_buf2_full && reg_bi_ind_in);
                        block_intlv_2.put_row(fifo_encoded_bits_in.first, reg_enc_in_cnt); fifo_encoded_bits_in.deq();
                        if (reg_enc_in_cnt < 8'd255)
                                reg_enc_in_cnt <= reg_enc_in_cnt + 1;
                        else if (reg_enc_in_cnt == 8'd255) begin
                                reg_buf2_full <= True;
                                reg_bi_ind_in <= False;
                                reg_enc_in_cnt <= 0;
                        end
        endrule
 
	rule state_err_corr1 (reg_buf1_full && !reg_bi_ind_err_in && !reg_err_cor_done && !fifo_no_error.first);
			let tmp = block_intlv_1.get_row(reg_err_vec_in_cnt);
                	block_intlv_1.put_row(fifo_encoded_err_vec.first ^ tmp, reg_err_vec_in_cnt); fifo_encoded_err_vec.deq();
                	if (reg_err_vec_in_cnt < 8'd255)
                        	reg_err_vec_in_cnt <= reg_err_vec_in_cnt + 1;
                	else if (reg_err_vec_in_cnt == 8'd255) begin
                        	reg_err_cor_done <= True;
                        	reg_err_vec_in_cnt <= 0;
                        	reg_bi_ind_err_in <= True;
                	end
	endrule

        rule state_err_corr2 (reg_buf2_full && reg_bi_ind_err_in && !reg_err_cor_done && !fifo_no_error.first);
                        let tmp = block_intlv_2.get_row(reg_err_vec_in_cnt);
                        block_intlv_2.put_row(fifo_encoded_err_vec.first ^ tmp, reg_err_vec_in_cnt); fifo_encoded_err_vec.deq();
                        if (reg_err_vec_in_cnt < 8'd255)
                                reg_err_vec_in_cnt <= reg_err_vec_in_cnt + 1;
                        else if (reg_err_vec_in_cnt == 8'd255) begin
                                reg_err_cor_done <= True;
                                reg_err_vec_in_cnt <= 0;
                                reg_bi_ind_err_in <= False;
                        end
        endrule
		
	rule start_subdecoding1 (reg_buf1_full && !reg_bi_ind_out && fifo_no_error.first);
			Codeword decoded_subcodeword = mulG256(block_intlv_1.get_col(reg_subcodeword_cnt));
			demapper.putDecVec(decoded_subcodeword);
			//if (reg_subcodeword_cnt < 8'd255)
			//if (reg_subcodeword_cnt == 0)
			//	reg_bi_ind_err_in <= True;
                	//else 
			if (reg_subcodeword_cnt < 63)
				reg_subcodeword_cnt <= reg_subcodeword_cnt + 1;	
		//if (reg_subcodeword_cnt == 8'd255) begin
                	else if (reg_subcodeword_cnt == 63) begin
				reg_buf1_full <= False;
				fifo_no_error.deq();
				reg_subcodeword_cnt <= 0;
				reg_bi_ind_out <= True;
				reg_bi_ind_err_in <= True;
			end
	endrule

        rule start_subdecoding2 (reg_buf2_full && reg_bi_ind_out && fifo_no_error.first);
                        Codeword decoded_subcodeword = mulG256(block_intlv_2.get_col(reg_subcodeword_cnt));
                        demapper.putDecVec(decoded_subcodeword);
                        //if (reg_subcodeword_cnt < 8'd255)
                        //if (reg_subcodeword_cnt == 0)
                        //        reg_bi_ind_err_in <= False;
                        //else 
			if (reg_subcodeword_cnt < 63)
                                reg_subcodeword_cnt <= reg_subcodeword_cnt + 1;
                //if (reg_subcodeword_cnt == 8'd255) begin
                        else if (reg_subcodeword_cnt == 63) begin
                                reg_buf2_full <= False;
                                fifo_no_error.deq();
                                reg_subcodeword_cnt <= 0;
				reg_bi_ind_out <= False;
				reg_bi_ind_err_in <= False;
                        end
	endrule

        rule start_subdecoding_w_error1 (reg_buf1_full && !reg_bi_ind_out && reg_err_cor_done && !fifo_no_error.first);
                	Codeword decoded_subcodeword = mulG256(block_intlv_1.get_col(reg_subcodeword_cnt));
                	demapper.putDecVec(decoded_subcodeword);
                //if (reg_subcodeword_cnt < 8'd255)
                	if (reg_subcodeword_cnt < 63)
                        	reg_subcodeword_cnt <= reg_subcodeword_cnt + 1;
                //if (reg_subcodeword_cnt == 8'd255) begin
                	else if (reg_subcodeword_cnt == 63) begin
                        	reg_buf1_full <= False;
				reg_err_cor_done <= False;
				fifo_no_error.deq();
                        	reg_subcodeword_cnt <= 0;
				reg_bi_ind_out <= True;
                	end
	endrule

        rule start_subdecoding_w_error2 (reg_buf2_full && reg_bi_ind_out && reg_err_cor_done && !fifo_no_error.first);
                        Codeword decoded_subcodeword = mulG256(block_intlv_2.get_col(reg_subcodeword_cnt));
                        demapper.putDecVec(decoded_subcodeword);
                //if (reg_subcodeword_cnt < 8'd255)
                        if (reg_subcodeword_cnt < 63)
                                reg_subcodeword_cnt <= reg_subcodeword_cnt + 1;
                //if (reg_subcodeword_cnt == 8'd255) begin
                        else if (reg_subcodeword_cnt == 63) begin
                                reg_buf2_full <= False;
                                reg_err_cor_done <= False;
                                fifo_no_error.deq();
                                reg_subcodeword_cnt <= 0;
                                reg_bi_ind_out <= False;
                        end		
        endrule

        method Action load_encoded_bits(ENCODED encoded_bits);
		fifo_encoded_bits_in.enq(mulG64(encoded_bits));
	endmethod

        method Action set_page_num(UInt#(3) page_num);
	//	$display("Decoder, setting page number: %d", page_num);
		demapper.setPageNum(page_num);
	endmethod

        method Action set_no_error(Bool is_no_error);
		fifo_no_error.enq(is_no_error);
	endmethod

        method Action load_err_vec(ENCODED err_vec);
		fifo_encoded_err_vec.enq(mulG64(err_vec));
	endmethod

        method ActionValue#(MESSAGE) get_decoded();
		let decoded <- demapper.getDemappedOut();
		return decoded;
	endmethod	

endmodule: mkRIODecoder1st

endpackage: RIO_decoder_1st
