package RIO_encoder_1st;

import Vector::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import RIO_subencoder_1st::*;
import BlockInterleaver::*;
import LLRUpdater::*;
import RegFile::*;
import Mapper::*;
//typedef Bit#(32) MESSAGE;
//typedef Bit#(128) ENCODED;

//`include "polar_codec_common_revised.bsv"

import Polar_codec_common_revised::*;

//`include "encoder_config.bsv"

typedef 64 N_LLR_UPDATER;
typedef 6 LOG2_N_LLR_UPDATER;
typedef 4 N_GROUP;
typedef 3 LOG2_N_GROUP_PLUS_1;

typedef 7 N_PAGES;
 
typedef enum {ENC_IDLE, ENC_DATA_IN, ENC_ENCODING, ENC_ENCODING_GET_LLRS, ENC_SUBENCODING, ENC_SUBENCODING_GET_RESULT, ENC_SUBENCODING_R0N256, ENC_DONE} ENC_state deriving(Bits, Eq);

interface RIOEncoder1stIfc;
	method Action load_msg(MESSAGE msg_bits);
	method Action load_prev_enc(ENCODED prev_enc_in);
	method Action set_page_num(UInt#(3) page_num);
	method ActionValue#(ENCODED) get_encoded();
	method ActionValue#(UInt#(15)) get_enc_fail_bit_cnt();
endinterface: RIOEncoder1stIfc

(* synthesize, options = "-no-aggressive-conditions" *)
module mkRIOEncoder1st(RIOEncoder1stIfc);
	BlockInterleaverIfc#(256, 64, 6, 8) block_intlv <- mkBlockInterleaver;
	MapperIfc mapper <- mkMapper;

	Vector#(N_LLR_UPDATER, LLRUpdaterIfc) llr_updater <- replicateM(mkLLRUpdater);
	RIOSubEncoder1stIfc rio_sub_encoder <- mkRIOSubEncoder1st;

	FIFO#(ENCODED) fifo_encoded_out <- mkPipelineFIFO;
	FIFO#(ENCODED) fifo_prev_enc_in <- mkPipelineFIFO;
	FIFO#(MESSAGE) fifo_msg_in <- mkPipelineFIFO;

	Vector#(Codeword_len, FIFO#(LLR#(8))) fifo_llr_vector <- replicateM(mkFIFO);
	Reg#(UInt#(6)) sub_cw_counter <- mkReg(0);
	Reg#(ENC_state) state <- mkReg(ENC_IDLE);

	FIFO#(PAGE_NUM) fifo_page_num <- mkFIFO1; 
	//Reg#(PAGE_NUM) reg_page_num <- mkReg(0);
	//Reg#(Vector#(64, Bit#(128))) prev_enc <- mkRegU;
	
	Reg#(UInt#(8)) prev_enc_in_counter <- mkReg(0);	
	Reg#(UInt#(6)) reg_msg_in_cnt <- mkReg(0);
	Reg#(Bool) reg_msg_buf_full <- mkReg(False);
	Reg#(Bool) reg_prev_enc_in_buf_full <- mkReg(False); 

	Reg#(UInt#(15)) reg_enc_fail_cnt <- mkReg(0);
	FIFO#(UInt#(15)) fifo_enc_fail_bit_cnt <- mkFIFO1;

	//Handling output
	//Reg#(UInt#(8)) col_counter <- mkReg(0);
        Reg#(UInt#(8)) col_counter_enc_fail <- mkReg(0);

        Reg#(UInt#(LOG2_N_GROUP_PLUS_1)) reg_offset1 <- mkReg(0);
        Reg#(UInt#(LOG2_N_GROUP_PLUS_1)) reg_offset2 <- mkReg(0);

	Vector#(256, Reg#(Bit#(64))) reg_prev_enc <- replicateM(mkReg(0));

	//FIFO#(LLR_vector#(8)) fifo_llr_for_subencoder <- mkFIFO1;
	//Reg#(LLR_vector#(10)) reg_llr_for_subencoder <- mkRegU;
	Vector#(256, FIFO#(LLR#(8))) fifo_llr_for_subencoder <- replicateM(mkPipelineFIFO);

	rule stateIdle (state == ENC_IDLE);
		sub_cw_counter <= 0;
	//	col_counter <= 0;
		prev_enc_in_counter <= 0;
		reg_msg_in_cnt <= 0;
		reg_enc_fail_cnt <= 0;
		reg_msg_buf_full <= False;
		reg_prev_enc_in_buf_full <= False;
		state <= ENC_DATA_IN;
		block_intlv.reset_reg();
		//$display("Page number set: %d", fifo_page_num.first);
	endrule

	rule state_msg_into_mapper (state == ENC_DATA_IN);
		mapper.putMsgVec(fifo_msg_in.first);
		fifo_msg_in.deq();
	endrule

        (* descending_urgency = "stateMsgIn, stateDataInDone " *)
	rule stateMsgIn (state == ENC_DATA_IN);
		let mappedOut <- mapper.getMappedOut();
		//$display("Mapper output: [%d] %b", reg_msg_in_cnt, mappedOut);
		block_intlv.put_row(mappedOut, reg_msg_in_cnt);
		//if (reg_msg_in_cnt < 8'd255)
		if (reg_msg_in_cnt < get_eom_bit_idx(fifo_page_num.first))
			reg_msg_in_cnt <= reg_msg_in_cnt + 1;
		//if (reg_msg_in_cnt == 8'd255)
		if (reg_msg_in_cnt == get_eom_bit_idx(fifo_page_num.first))
			reg_msg_buf_full <= True;
	endrule

	rule statePrevEncIn (state == ENC_DATA_IN && fifo_page_num.first > 0 && !reg_prev_enc_in_buf_full);
		//llr_updater[prev_enc_in_counter].put_prev_enc(fifo_prev_enc_in.first);
		reg_prev_enc[prev_enc_in_counter] <= fifo_prev_enc_in.first;
		fifo_prev_enc_in.deq();	
                if (prev_enc_in_counter < 8'd255) 
                        prev_enc_in_counter <= prev_enc_in_counter + 1;
		if (prev_enc_in_counter == 8'd255)
			reg_prev_enc_in_buf_full <= True;
        endrule

        rule statePrevEncInPage0 (state == ENC_DATA_IN && fifo_page_num.first == 0  && !reg_prev_enc_in_buf_full);
		for (Integer i=0 ; i<256 ; i=i+1) 
			reg_prev_enc[i] <= 0;
                        //llr_updater[i].put_prev_enc(0);
		reg_prev_enc_in_buf_full <= True;
        endrule

	rule stateDataInDone (state == ENC_DATA_IN && reg_msg_buf_full && reg_prev_enc_in_buf_full);
		state <= ENC_ENCODING;
	endrule
	 
	rule stateEncodingR1N256 (state == ENC_ENCODING && get_instruction(sub_cw_counter, fifo_page_num.first).instructionVector[0] == R1N256);
                SubcodeInstruction current_instr = get_instruction(sub_cw_counter, fifo_page_num.first);
                Codeword u_hat = block_intlv.get_row(sub_cw_counter);
                block_intlv.put_row(mulG256(u_hat), sub_cw_counter);
		//$display("INSTR counter: %d", sub_cw_counter);
                if (sub_cw_counter == 6'd63)
                	state <= ENC_DONE;
                else begin
                        sub_cw_counter <= sub_cw_counter + 1;
                        state <= ENC_ENCODING;
                end
        endrule

        rule stateEncodingGeneral (state == ENC_ENCODING  && get_instruction(sub_cw_counter, fifo_page_num.first).instructionVector[0] != R1N256 && reg_offset1 <= fromInteger(valueOf(N_GROUP)-1));
                SubcodeInstruction current_instr = get_instruction(sub_cw_counter, fifo_page_num.first);
                for (Integer i=0 ; i<valueOf(N_LLR_UPDATER) ; i=i+1) begin
                        UInt#(8) idx = fromInteger(i)+(zeroExtend(reg_offset1) << fromInteger(valueOf(LOG2_N_LLR_UPDATER)));
                        let u_hat = block_intlv.get_col(idx);
                        let prev_enc = reg_prev_enc[idx];

                        llr_updater[i].put_input(prev_enc, u_hat, pack(sub_cw_counter));
                end
                reg_offset1 <= reg_offset1 + 1;
        endrule

        for (Integer j=0 ; j<valueOf(N_GROUP) ; j=j+1) begin
        rule stateEncodingGetLLRs (state == ENC_ENCODING && get_instruction(sub_cw_counter, fifo_page_num.first).instructionVector[0] != R1N256 && reg_offset2 == fromInteger(j));
                SubcodeInstruction current_instr = get_instruction(sub_cw_counter, fifo_page_num.first);
                for (Integer i=0 ; i<valueOf(N_LLR_UPDATER) ; i=i+1) begin
			LLR#(8) llr <- llr_updater[i].get_llr();
			fifo_llr_for_subencoder[i+j*valueOf(N_LLR_UPDATER)].enq(llr);
                end

                if (reg_offset2 == fromInteger(valueOf(N_GROUP)-1)) begin
			reg_offset1 <= 0;
			reg_offset2 <= 0;
                        if (current_instr.instructionVector[0] == R0N256)
                                state <= ENC_SUBENCODING_R0N256;
                        else
                                state <= ENC_SUBENCODING;
                end
		else begin
			reg_offset2 <= reg_offset2 + 1;
		end
        endrule
        end

/*

        rule stateEncodingGeneral (state == ENC_ENCODING  && get_instruction(sub_cw_counter, fifo_page_num.first).instructionVector[0] != R1N256);
                SubcodeInstruction current_instr = get_instruction(sub_cw_counter, fifo_page_num.first);
                //$display("INSTR counter: %d", sub_cw_counter);
                for (Integer i=0 ; i<256 ; i=i+1) begin
                        let u_hat = block_intlv.get_col(fromInteger(i));
                        let prev_enc = reg_prev_enc[i];
			llr_updater[i].put_input(prev_enc, u_hat, pack(sub_cw_counter));
                end
                //if (current_instr.instructionVector[0] == R0N64) 
                //	state <= ENC_SUBENCODING_R0N64;
                //else    
                //	state <= ENC_SUBENCODING;
		state <= ENC_ENCODING_GET_LLRS;
        endrule

        rule stateEncodingGetLLRs (state == ENC_ENCODING_GET_LLRS);//state == ENC_ENCODING  && get_instruction(sub_cw_counter, fifo_page_num.first).instructionVector[0] != R1N256);
                SubcodeInstruction current_instr = get_instruction(sub_cw_counter, fifo_page_num.first);
		LLR_vector#(8) llr_for_subencoder;

                //$display("Get LLRs: INSTR counter: %d", sub_cw_counter);
                for (Integer i=0 ; i<256 ; i=i+1) begin 
                        llr_for_subencoder[i] <- llr_updater[i].get_llr();
		end
		//reg_llr_for_subencoder <= llr_for_subencoder;
		fifo_llr_for_subencoder.enq(llr_for_subencoder);

                if (current_instr.instructionVector[0] == R0N256)
                        state <= ENC_SUBENCODING_R0N256;
                else
                        state <= ENC_SUBENCODING;
        endrule	
*/
        rule stateSubEncodingR0N256 (state == ENC_SUBENCODING_R0N256);
                Codeword encoded_result;
		//LLR_vector#(8) llr_for_subencoder = fifo_llr_for_subencoder.first; fifo_llr_for_subencoder.deq();
                //LLR_vector#(8) llr_for_subencoder; // = reg_llr_for_subencoder;

                //for (Integer i=0 ; i<256 ; i=i+1) begin
                  //      encoded_result[i] = hardDecision(llr_for_subencoder[i]);
		//end
                for (Integer i=0 ; i<256 ; i=i+1) begin
                        //LLR#(10) llr <- llr_updater[i].get_llr();
                        //encoded_result[i] = hardDecision(llr);
                        //encoded_result[i] = hardDecision(llr_for_subencoder[i]);
                        encoded_result[i] = hardDecision(fifo_llr_for_subencoder[i].first);
                        fifo_llr_for_subencoder[i].deq();
                end


                //$display("[%d] %b", sub_cw_counter, encoded_result);
                block_intlv.put_row(encoded_result, sub_cw_counter);
                if (sub_cw_counter == 6'd63)
                        state <= ENC_DONE;
                else begin
                        sub_cw_counter <= sub_cw_counter + 1;
                        state <= ENC_ENCODING;
                end
        endrule

	rule stateSubEncoding (state == ENC_SUBENCODING);
		//LLR_vector#(8) llr_for_subencoder = fifo_llr_for_subencoder.first; fifo_llr_for_subencoder.deq();
                LLR_vector#(8) llr_for_subencoder;// = reg_llr_for_subencoder;

		SubcodeInstruction current_instr = get_instruction(sub_cw_counter, fifo_page_num.first);
                Codeword msg_bit_ind = get_msg_bit_ind(sub_cw_counter, fifo_page_num.first);
                Codeword u_hat = block_intlv.get_row(sub_cw_counter);

		for (Integer i=0 ; i<256 ; i=i+1) begin
			llr_for_subencoder[i] = fifo_llr_for_subencoder[i].first;
			fifo_llr_for_subencoder[i].deq();
		end
		//for (Integer i=0 ; i<64 ; i=i+1)
		//	$display("[%2d]%d ", i, llr_for_subencoder[i]);
		rio_sub_encoder.load_LLR(llr_for_subencoder);
		rio_sub_encoder.load_u_hat(u_hat);
		rio_sub_encoder.load_msg_ind(msg_bit_ind);		
		rio_sub_encoder.load_enc_instruction(current_instr);
		state <= ENC_SUBENCODING_GET_RESULT;
	endrule

        rule stateSubEncodingGetResult (state == ENC_SUBENCODING_GET_RESULT);
                Codeword encoded_result <- rio_sub_encoder.get_encoded_result();
                //Codeword updated_u_hat <- rio_sub_encoder.get_updated_u_hat();
		//$display("[%d] %b", sub_cw_counter, encoded_result);
                block_intlv.put_row(encoded_result, sub_cw_counter);
		if (sub_cw_counter == 6'd63)
			state <= ENC_DONE;
		else begin
			sub_cw_counter <= sub_cw_counter + 1;
                	state <= ENC_ENCODING;
		end
        endrule

	rule stateEncDone (state == ENC_DONE);
		let partial_encoded_col = block_intlv.get_col(col_counter_enc_fail);
		let encoded_out = mulG64(partial_encoded_col);
		let prev_page_enc_data = reg_prev_enc[col_counter_enc_fail];
		let updated_reg_enc_fail_cnt =  reg_enc_fail_cnt + zeroExtend(countOnes(prev_page_enc_data & (~encoded_out)));
		reg_enc_fail_cnt <= updated_reg_enc_fail_cnt;
		fifo_encoded_out.enq(encoded_out);
		if (col_counter_enc_fail == 8'd255) begin
			//for (Integer i=0 ; i<64 ; i=i+1)
	                  //      llr_updater[i].flush_prev_enc();
			fifo_enc_fail_bit_cnt.enq(updated_reg_enc_fail_cnt);
			fifo_page_num.deq();
			//$display("Page num. %d deq@RIO encoder 1st", fifo_page_num.first); 
			col_counter_enc_fail <= 0;
			state <= ENC_IDLE;
		end
		else begin
			col_counter_enc_fail <= col_counter_enc_fail + 1;
			state <= ENC_DONE;
		end
	endrule

        method Action load_msg(MESSAGE msg_bits);
		//mapper.putMsgVec(msg_bits);
		fifo_msg_in.enq(msg_bits);
	endmethod

        method Action load_prev_enc(ENCODED prev_enc_in);
		fifo_prev_enc_in.enq(prev_enc_in);
	endmethod

        method Action set_page_num(UInt#(3) page_num);
		//if (fifo_page_num.notFull) begin
			mapper.setPageNum(page_num);
			fifo_page_num.enq(page_num);
			//reg_page_num <= page_num;
		//end
	endmethod

        method ActionValue#(ENCODED) get_encoded();
		let encoded_out = fifo_encoded_out.first; fifo_encoded_out.deq();
		return encoded_out;	
	endmethod

	method ActionValue#(UInt#(15)) get_enc_fail_bit_cnt();
		//let enc_fail_bit_cnt = fifo_enc_fail_bit_cnt.first;
		fifo_enc_fail_bit_cnt.deq();
		return fifo_enc_fail_bit_cnt.first;		
	endmethod

endmodule: mkRIOEncoder1st

endpackage: RIO_encoder_1st
