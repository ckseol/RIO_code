package RIO_code_scheme_write_path;

import FIFO::*;
import FIFOF::*;
import Vector::*;
import FIFO::*;
import SpecialFIFOs::*;

import BRAM::*;

import RIO_encoder_1st::*;
import RIO_code_2nd::*;
import BCH_encoder::*;
import RS_encoder::*;

import RIO_code_scheme_common::*;

function BRAMRequest#(Bit#(n), Bit#(m)) makeRequest(Bool write, Bit#(n) addr, Bit#(m) data);
	return BRAMRequest{
		write: write,
		responseOnWrite:False,
		address: addr,
		datain: data};
endfunction
 
interface RIOCodeSchemeWritePathIfc;
	method Action putUserdata(Bit#(64) user_data);
	method Action setPageNum(UInt#(3) page_num);
	method Action setMaxFrmCnt(UInt#(5) max_frm_cnt);
	method ActionValue#(Bit#(64)) getEncoded();
	method ActionValue#(UInt#(15)) getEncFailBitCnt(); 
endinterface: RIOCodeSchemeWritePathIfc


(* synthesize, options = "-no-aggressive-conditions" *)
module mkRIOCodeSchemeWritePath(RIOCodeSchemeWritePathIfc);

	RIOEncoder1stIfc rio_encoder_1st <- mkRIOEncoder1st;
	BCHEncoderIfc bch_encoder <- mkBCHEncoder;
	RSEncoderIfc rs_encoder <- mkRSEncoder;
	RIOEncoder2ndIfc rio_encoder_2nd <- mkRIOEncoder2nd;
	
	FIFO#(Bit#(64)) fifo_rio_encoded_1st <- mkPipelineFIFO;
	//SplitterIfc#(256, 64) splitter1 <- mkSplitter;
	SplitterIfc#(270, 6) splitter2 <- mkSplitter;
	CombinerIfc#(32, 64) combiner1 <- mkCombiner;
	SplitterIfc#(64, 32) splitter3 <- mkSplitter;
	CombinerIfc#(32, 64) combiner2 <- mkCombiner;
	CombinerIfc#(64, 256) combiner_input <- mkCombiner;

	FIFO#(Bit#(64)) fifo_user_data_in <- mkPipelineFIFO;
	FIFO#(Bit#(64)) fifo_encoded_out <- mkPipelineFIFO;
	Reg#(UInt#(10)) reg_encoded_out_cnt <- mkReg(0);
	Reg#(UInt#(8)) reg_rio_encoded_2nd_cnt <- mkReg(0);
	//Reg#(UInt#(3)) reg_page_num <- mkReg(0);
	FIFO#(UInt#(3)) fifo_page_num <- mkPipelineFIFO;
	FIFO#(UInt#(3)) fifo_page_num_par <- mkPipelineFIFO;
	Reg#(UInt#(6)) reg_rs_in_cnt <- mkReg(0);

	Reg#(UInt#(8)) reg_delay_buffer_addr <- mkReg(0);
	Reg#(UInt#(8)) reg_rio_encoded_1st_cnt <- mkReg(0);
	Reg#(UInt#(5)) reg_rio_encoded_2nd_8B_cnt <- mkReg(0);

	Reg#(Bool) reg_parity_out_done <- mkReg(False);
	Reg#(UInt#(5)) reg_max_frm_cnt <- mkReg(0);

	// delay buffer for RIO 1st encoded data
	BRAM_Configure cfg_delay_buffer = defaultValue;
	cfg_delay_buffer.memorySize = 256;
	BRAM1Port#(Bit#(8), Bit#(64)) bram_delay_buffer <- mkBRAM1Server(cfg_delay_buffer);

	// previously encoded data buffer
        BRAM_Configure cfg_prev_enc_buffer = defaultValue;
        cfg_prev_enc_buffer.memorySize = 4096;
        BRAM2Port#(Bit#(12), Bit#(64)) bram_prev_enc_buffer <- mkBRAM2Server(cfg_prev_enc_buffer);

        BRAM_Configure cfg_prev_enc_par_buffer = defaultValue;
        cfg_prev_enc_par_buffer.memorySize = 512;
        BRAM2Port#(Bit#(9), Bit#(64)) bram_prev_enc_par_buffer <- mkBRAM2Server(cfg_prev_enc_par_buffer);

	Reg#(UInt#(4)) reg_frm_cnt_prev_enc_rd <- mkReg(0);
	Reg#(UInt#(4)) reg_frm_cnt_prev_enc_wr <- mkReg(0);
	Reg#(UInt#(4)) reg_frm_cnt_par_rd <- mkReg(0);
	Reg#(UInt#(4)) reg_frm_cnt_par_wr <- mkReg(0);
	Reg#(UInt#(8)) reg_prev_enc_buffer_addr1 <- mkReg(0);
  	Reg#(UInt#(8)) reg_prev_enc_buffer_addr2 <- mkReg(0);
	Reg#(UInt#(5)) reg_prev_enc_buffer_addr3 <- mkReg(0);

	Reg#(UInt#(6)) reg_rs_encoded_cnt <- mkReg(0);
	Reg#(UInt#(8)) reg_rio_encoded_2nd_from_buffer_cnt <- mkReg(0);
	Reg#(UInt#(5)) reg_rio_encoded_2nd_32B_cnt <- mkReg(0);

//	FIFO#(UInt#(15)) fifo_enc_fail_cnt <- mkFIFO1;

	rule input_to_combiner_input;
		combiner_input.put(fifo_user_data_in.first, False);
		fifo_user_data_in.deq();
	endrule

        rule combiner1_input_to_rio_encoder_1st;
		let combined_user_data <- combiner_input.getCombined();
		//$display("Combiner1 to RIO encoder 1st:%b", combined_user_data);
                rio_encoder_1st.load_msg(combined_user_data);
        endrule

	rule fifo_page_num_z (fifo_page_num.first == 0);
		fifo_page_num.deq();
                fifo_page_num_par.enq(fifo_page_num.first);
	endrule

	//(* mutually_exclusive = "get_prev_enc_from_prev_enc_buffer, rs_encoder_to_rio_encoder_2nd_page_nz" *)
	rule get_prev_enc_from_prev_enc_buffer (fifo_page_num.first > 0);
                Bit#(12) prev_enc_buffer_addr = {pack(reg_frm_cnt_prev_enc_rd), pack(reg_prev_enc_buffer_addr1)};
                bram_prev_enc_buffer.portA.request.put(makeRequest(False, prev_enc_buffer_addr, 0));
                //$display("Read address (prev_enc_buffer) = %d, reg_frm_cnt = %d", prev_enc_buffer_addr, reg_frm_cnt_prev_enc_rd);

                if (reg_prev_enc_buffer_addr1 < fromInteger(valueOf(RIO_CODE_1ST_DATA_LEN)-1)) begin
                        reg_prev_enc_buffer_addr1 <= reg_prev_enc_buffer_addr1 + 1;
		end
                else begin
                        reg_prev_enc_buffer_addr1 <= 0;
			fifo_page_num.deq();
			//$display("reg_frm_cnt_prev_enc_rd = %d, page_num = %d", reg_frm_cnt_prev_enc_rd, fifo_page_num.first);
			fifo_page_num_par.enq(fifo_page_num.first);
			if (reg_frm_cnt_prev_enc_rd < truncate(reg_max_frm_cnt-1)) 
				reg_frm_cnt_prev_enc_rd <= reg_frm_cnt_prev_enc_rd + 1;
			else
				reg_frm_cnt_prev_enc_rd <= 0;
		end
	endrule 

	//(* mutually_exclusive = "input_prev_enc_to_rio_encoder_1st, get_rio_encoded_2nd_prev_enc" *)
	rule input_prev_enc_to_rio_encoder_1st;// (fifo_page_num.first > 0);
                let prev_enc <- bram_prev_enc_buffer.portA.response.get;
		//$display("[P:%d][F:%d] %b", fifo_page_num.first, reg_frm_cnt_prev_enc_rd, prev_enc);
                rio_encoder_1st.load_prev_enc(prev_enc);		
	endrule

	//(* mutually_exclusive = "rio_encoder_1st_to_splitter1, combiner2_to_prev_enc_buffer" *)
	rule rio_encoder_1st_to_fifo;
		let rio_encoded_1st <- rio_encoder_1st.get_encoded();
                Bit#(12) prev_enc_buffer_addr = {pack(reg_frm_cnt_prev_enc_wr), pack(reg_prev_enc_buffer_addr2)};
                bram_prev_enc_buffer.portB.request.put(makeRequest(True, prev_enc_buffer_addr, rio_encoded_1st));
		//$display("Write address (prev_enc_buffer) = %d, %d, reg_frm_cnt = %d, page = %d", prev_enc_buffer_addr, reg_prev_enc_buffer_addr2, reg_frm_cnt_prev_enc_wr, fifo_page_num.first);
		if (reg_prev_enc_buffer_addr2 < fromInteger(valueOf(RIO_CODE_1ST_DATA_LEN)-1))
			reg_prev_enc_buffer_addr2 <= reg_prev_enc_buffer_addr2 + 1;
		else begin
			reg_prev_enc_buffer_addr2 <= 0;
	                if (reg_frm_cnt_prev_enc_wr < truncate(reg_max_frm_cnt-1))
                                reg_frm_cnt_prev_enc_wr <= reg_frm_cnt_prev_enc_wr + 1;
               	        else
                       	        reg_frm_cnt_prev_enc_wr <= 0;		
		end              
		fifo_rio_encoded_1st.enq(rio_encoded_1st);
	endrule
	
	(* mutually_exclusive = "fifo_to_bch_encoder, request_rio_encoded_1st" *)
	rule fifo_to_bch_encoder;
		let rio_encoded_1st = fifo_rio_encoded_1st.first; fifo_rio_encoded_1st.deq();
		bram_delay_buffer.portA.request.put(makeRequest(True, pack(reg_delay_buffer_addr), rio_encoded_1st));	
		bch_encoder.load_msg_bits(rio_encoded_1st);

		if (reg_delay_buffer_addr < fromInteger(valueOf(RIO_CODE_1ST_DATA_LEN)-1))
			reg_delay_buffer_addr <= reg_delay_buffer_addr + 1;
		else begin
			//fifo_page_num_par.enq(fifo_page_num.first);
			//fifo_page_num.deq();
			reg_delay_buffer_addr <= 0;
		end
	endrule

	rule bch_encoder_to_splitter2;
		let bch_encoded <- bch_encoder.get_encoded();
		//$display("BCH parity: %b", bch_encoded);
		splitter2.put(bch_encoded);
	endrule

	rule splitter2_to_rs_encoder;
		let split_bch_encoded <- splitter2.getSplit();
		//$display("RS encoder input: [%d] %b", reg_rs_in_cnt,  split_bch_encoded);
		rs_encoder.load_msg_bits(split_bch_encoded);
		if (reg_rs_in_cnt < fromInteger(valueOf(RS_INFO_LEN)-1))
			reg_rs_in_cnt <= reg_rs_in_cnt + 1;
		else
			reg_rs_in_cnt <= 0;
	endrule

	rule rs_encoder_to_rio_encoder_2nd_page_z (fifo_page_num_par.first == 0);
		let rs_encoded <- rs_encoder.get_encoded();
		//$display("RS encoded: %b", rs_encoded);
		rio_encoder_2nd.loadMessage(rs_encoded);
		rio_encoder_2nd.loadPrevEnc(0);
	endrule

	//Reg#(UInt#(6)) reg_rs_encoded_cnt <- mkReg(0);
        rule rs_encoder_to_rio_encoder_2nd_page_nz (fifo_page_num_par.first > 0);
                let rs_encoded <- rs_encoder.get_encoded();
                //$display("RS encoded: %b", rs_encoded);
                rio_encoder_2nd.loadMessage(rs_encoded);
                if (pack(reg_rs_encoded_cnt)[0]==0) begin
                        Bit#(9) prev_enc_buffer_addr = {pack(reg_frm_cnt_par_rd), pack(reg_prev_enc_buffer_addr3)};
                        bram_prev_enc_par_buffer.portA.request.put(makeRequest(False, prev_enc_buffer_addr, 0));
			//$display("Read address (prev_enc_par_buffer) = %d, reg_frm_cnt = %d, %b", prev_enc_buffer_addr, reg_frm_cnt1);

                        if (reg_prev_enc_buffer_addr3 < fromInteger(valueOf(MAX_RIO_2ND_ENCODED_CNT)-1))
                                reg_prev_enc_buffer_addr3 <= reg_prev_enc_buffer_addr3 + 1;
                        else begin
                                reg_prev_enc_buffer_addr3 <= 0;
				if (reg_frm_cnt_par_rd < truncate(reg_max_frm_cnt-1))
					reg_frm_cnt_par_rd <= reg_frm_cnt_par_rd + 1;
				else
					reg_frm_cnt_par_rd <= 0; 
			end
                end
		if (reg_rs_encoded_cnt < fromInteger(valueOf(RS_ENCODED_LEN)-1))
			reg_rs_encoded_cnt <= reg_rs_encoded_cnt + 1;
		else
			reg_rs_encoded_cnt <= 0;
        endrule

        rule get_rio_encoded_2nd_prev_enc (fifo_page_num_par.first > 0);
                let prev_enc <- bram_prev_enc_par_buffer.portA.response.get;
		//$display("Read prev enc: %b", prev_enc);
                splitter3.put(prev_enc);
        endrule
	
	//Reg#(UInt#(6)) reg_rio_encoded_2nd_from_buffer_cnt <- mkReg(0);
	rule input_prev_encoded_rio_encoded_2nd (fifo_page_num_par.first > 0);
		let split_prev_enc_rio_2nd <- splitter3.getSplit();
		if (reg_rio_encoded_2nd_from_buffer_cnt < fromInteger(valueOf(RS_ENCODED_LEN))) begin
			rio_encoder_2nd.loadPrevEnc(split_prev_enc_rio_2nd);
			reg_rio_encoded_2nd_from_buffer_cnt <= reg_rio_encoded_2nd_from_buffer_cnt + 1;
		end 
		else 
			reg_rio_encoded_2nd_from_buffer_cnt <= 0;		
	endrule

	rule rio_encoder_2nd_to_combiner1;
		let rio_encoder_2nd_encoded <- rio_encoder_2nd.getEncodedResult();
		//$display("RIO 2nd encoded: %b", rio_encoder_2nd_encoded);
		if (reg_rio_encoded_2nd_cnt < fromInteger(valueOf(RS_ENCODED_LEN)-1)) begin
			reg_rio_encoded_2nd_cnt <= reg_rio_encoded_2nd_cnt + 1;
                        combiner1.put(rio_encoder_2nd_encoded, False);
			combiner2.put(rio_encoder_2nd_encoded, False);
		end
		else begin
			reg_rio_encoded_2nd_cnt <= 0;
                        combiner1.put(rio_encoder_2nd_encoded, True);
			combiner2.put(rio_encoder_2nd_encoded, True);
		end
	endrule

	(* mutually_exclusive = "combiner1_to_output, output_rio_encoded_1st" *)
	rule combiner1_to_output (!reg_parity_out_done);
		let rio_encoder_2nd_encoded_combined <- combiner1.getCombined();
		fifo_encoded_out.enq(rio_encoder_2nd_encoded_combined);

		if (reg_rio_encoded_2nd_8B_cnt < fromInteger(valueOf(MAX_RIO_2ND_ENCODED_CNT)-1))
			reg_rio_encoded_2nd_8B_cnt <= reg_rio_encoded_2nd_8B_cnt + 1;
		else begin
			reg_rio_encoded_2nd_8B_cnt <= 0;
			reg_parity_out_done <= True;
		end
	endrule

        rule output_rio_encoded_1st;
                let encoded_out <- bram_delay_buffer.portA.response.get;
                fifo_encoded_out.enq(encoded_out);
        endrule


	//Reg#(UInt#(4)) reg_rio_encoded_2nd_32B_cnt <- mkReg(0);
        rule combiner2_to_prev_enc_buffer;
                let rio_encoder_2nd_encoded_combined <- combiner2.getCombined();
                
                Bit#(9) prev_enc_buffer_addr = {pack(reg_frm_cnt_par_wr), pack(reg_rio_encoded_2nd_32B_cnt)};
                bram_prev_enc_par_buffer.portB.request.put(makeRequest(True, prev_enc_buffer_addr, rio_encoder_2nd_encoded_combined));
                
                if (reg_rio_encoded_2nd_32B_cnt < fromInteger(valueOf(MAX_RIO_2ND_ENCODED_CNT)-1))
                        reg_rio_encoded_2nd_32B_cnt <= reg_rio_encoded_2nd_32B_cnt + 1;
                else begin
                        reg_rio_encoded_2nd_32B_cnt <= 0;
			fifo_page_num_par.deq();
			//$display("reg_frm_cnt_prev_enc_wr = %d, page_num = %d", reg_frm_cnt_par_wr, fifo_page_num_par.first);
			if (reg_frm_cnt_par_wr < truncate(reg_max_frm_cnt-1))
				reg_frm_cnt_par_wr <= reg_frm_cnt_par_wr + 1;
			else
                        	reg_frm_cnt_par_wr <= 0;
                end
        endrule


	rule request_rio_encoded_1st (reg_parity_out_done);
                bram_delay_buffer.portA.request.put(makeRequest(False, pack(reg_rio_encoded_1st_cnt), 0));

		if (reg_rio_encoded_1st_cnt < fromInteger(valueOf(RIO_CODE_1ST_DATA_LEN)-1))
			reg_rio_encoded_1st_cnt <= reg_rio_encoded_1st_cnt + 1;
		else begin
			reg_rio_encoded_1st_cnt <= 0;
			reg_parity_out_done <= False;
		end
	endrule
/*
	rule get_rio_encoded_1st_fail_bit_cnt;
		let enc_fail_cnt <- rio_encoder_1st.get_enc_fail_bit_cnt();
		$display("RIO 1st enc. fail cnt = %d", fail_cnt);
		fifo_enc_fail_cnt.enq(enc_fail_cnt);
	endrule
*/
/*
	rule output_rio_encoded_1st;
		let encoded_out <- bram_delay_buffer.portA.response.get;
		fifo_encoded_out.enq(encoded_out);
	endrule
*/	
        method Action putUserdata(Bit#(64) user_data);
		fifo_user_data_in.enq(user_data);
	endmethod

	method Action setPageNum(UInt#(3) page_num);
		rio_encoder_1st.set_page_num(page_num);
		fifo_page_num.enq(page_num);
		//$display("Page:%d @ write path", page_num);
	endmethod

	method Action setMaxFrmCnt(UInt#(5) max_frm_cnt);
		reg_max_frm_cnt <= max_frm_cnt;
	endmethod

        method ActionValue#(Bit#(64)) getEncoded();
		fifo_encoded_out.deq();
		return fifo_encoded_out.first;
	endmethod
	
	method ActionValue#(UInt#(15)) getEncFailBitCnt();
                let enc_fail_cnt <- rio_encoder_1st.get_enc_fail_bit_cnt();
                //$display("RIO 1st enc. fail cnt = %d", fail_cnt);
		//fifo_enc_fail_cnt.deq();
		//return fifo_enc_fail_cnt.first;		
		return enc_fail_cnt;
	endmethod
	
endmodule: mkRIOCodeSchemeWritePath

endpackage: RIO_code_scheme_write_path
