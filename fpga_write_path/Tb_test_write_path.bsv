package Tb;

import FIFO::*;
import FIFOF::*;
import Vector::*;
import RIO_code_scheme_write_path::*;
import RIO_code_scheme_read_path::*;
import Polar_codec_common_revised::*;
import noise_gen::*;

typedef 0 Page_num;
typedef 16 MAX_FRM_CNT;

(* synthesize *)
module mkTb (Empty);
	RIOCodeSchemeWritePathIfc rio_code_write_path <- mkRIOCodeSchemeWritePath;
	RIOCodeSchemeReadPathIfc  rio_code_read_path <- mkRIOCodeSchemeReadPath;

	NoiseGenIfc err_vec_gen_tx <- mkNoiseGen;
	NoiseGenIfc err_vec_gen_rx <- mkNoiseGen;
	
        Reg#(int) cycle <- mkReg(0);
	Reg#(int) rcvd_in_cnt <- mkReg(0);
	Reg#(UInt#(32)) msg_in_cnt <- mkReg(0);
	Reg#(UInt#(32)) msg_out_cnt <- mkReg(0);
	Reg#(UInt#(32)) read_path_out_cnt <- mkReg(0);
	Reg#(UInt#(3)) reg_page_num <- mkReg(0);
	Reg#(UInt#(4)) reg_frm_num <- mkReg(0);
        Reg#(UInt#(3)) reg_page_num1 <- mkReg(0);
        Reg#(UInt#(4)) reg_frm_num1 <- mkReg(0);
        Reg#(UInt#(3)) reg_page_num2 <- mkReg(0);
        Reg#(UInt#(4)) reg_frm_num2 <- mkReg(0);
	Reg#(UInt#(32)) reg_error_cnt <- mkReg(0);


	rule init (cycle == 0);
		rio_code_write_path.setPageNum(reg_page_num);
		rio_code_read_path.setPageNum(reg_page_num);
		err_vec_gen_tx.set_threshold(32'h8000_0000);
		err_vec_gen_rx.set_threshold(32'h8000_0000);
		rio_code_write_path.setMaxFrmCnt(fromInteger(valueOf(MAX_FRM_CNT)));
		cycle <= cycle + 1;	
	endrule

        rule inputMessages (msg_in_cnt < zeroExtend(get_msg_bit_len(reg_page_num))*4 && cycle > 0);
		//Bit#(64) user_data =zeroExtend({pack(reg_frm_num), pack(msg_in_cnt)});
		Bit#(64) user_data <- err_vec_gen_tx.get_err_vec();

		rio_code_write_path.putUserdata(user_data);
		//$display("[%d][%d] %b", cycle, msg_in_cnt, user_data);
                msg_in_cnt <= msg_in_cnt + 1;
        endrule

	rule reset_msg_in_cnt (msg_in_cnt == zeroExtend(get_msg_bit_len(reg_page_num))*4 && cycle > 0);
		msg_in_cnt <= 0;
                //rio_code_read_path.setPageNum(reg_page_num);
		if (reg_frm_num < fromInteger(valueOf(MAX_FRM_CNT)-1)) begin
			reg_frm_num <= reg_frm_num + 1;
			rio_code_write_path.setPageNum(reg_page_num);
		//	$display("[%d]Set page num@write path[%d], frm num %d", cycle, reg_page_num, reg_frm_num+1);
		end
		else begin
			reg_frm_num <= 0;
                        if (reg_page_num < 6) begin
                                reg_page_num <= reg_page_num + 1;
                                rio_code_write_path.setPageNum(reg_page_num + 1);
                  //              $display("[%d]Set page num@write path[%d], frm num %d", cycle, reg_page_num+1, 0);
                        end
                        else begin
                                reg_page_num <= 0;
                                rio_code_write_path.setPageNum(0);
                    //            $display("[%d]Set page num@write path[%d], frm num %d", cycle, 0, 0);
                        end



		end
	endrule

	rule displayEncOut (msg_out_cnt < 288);
		//if (msg_out_cnt >= 100) begin
		let write_path_out <- rio_code_write_path.getEncoded();
		rio_code_read_path.putRcvd(write_path_out);
		//end
		if (msg_out_cnt == 16)
			$display("Write path out: [%d][Page:%d][FRM:%d][%d] %b", cycle, reg_page_num1, reg_frm_num1, msg_out_cnt, write_path_out);
		//if (msg_out_cnt == 255)
		//	msg_out_cnt <= 0;
		//else
			msg_out_cnt <= msg_out_cnt + 1;
	endrule
	
	rule get_enc_fail_cnt;
		let enc_fail_cnt <- rio_code_write_path.getEncFailBitCnt();
		$display("[%d][Page%d]RIO code 1st enc. fail cnt = %d", cycle, reg_page_num1, enc_fail_cnt);
	endrule

        rule reset_msg_out_cnt (msg_out_cnt == 288);
                msg_out_cnt <= 0;
                //rio_code_write_path.setPageNum(reg_page_num);
                //rio_code_read_path.setPageNum(reg_page_num1);                  
                if (reg_frm_num1 < fromInteger(valueOf(MAX_FRM_CNT)-1)) begin
                        reg_frm_num1 <= reg_frm_num1 + 1;
			rio_code_read_path.setPageNum(reg_page_num1);
		//	$display("[%d]Set page num@read path[%d], frm num %d", cycle, reg_page_num1, reg_frm_num1+1);
		end
                else begin
                        reg_frm_num1 <= 0;
			if (reg_page_num1 < 6) begin
                        	reg_page_num1 <= reg_page_num1 + 1;
				rio_code_read_path.setPageNum(reg_page_num1 + 1);
		//		$display("[%d]Set page num@read path[%d], frm num %d", cycle, reg_page_num1+1, 0);
			end
			else begin
                                reg_page_num1 <= 0;
                                rio_code_read_path.setPageNum(0);
                  //              $display("[%d]Set page num@read path[%d], frm num %d", cycle, 0, 0);
			end			
                end
        endrule

	rule displayDecOut (read_path_out_cnt < zeroExtend(get_msg_bit_len(reg_page_num2))*4);
		let read_path_out <- rio_code_read_path.getDecoded();
		Bit#(64) user_data <- err_vec_gen_rx.get_err_vec();
		//Bit#(64) user_data = zeroExtend({pack(reg_frm_num2), pack(read_path_out_cnt)});
		reg_error_cnt <= reg_error_cnt + zeroExtend(countOnes(read_path_out ^ user_data));
                //$display("Read path out: [%d][Page:%d][FRM:%d][%d] %b %d", cycle, reg_page_num2, reg_frm_num2, read_path_out_cnt, read_path_out, countOnes(read_path_out ^ user_data));
                read_path_out_cnt <= read_path_out_cnt + 1;

	endrule

	rule reset_cnt (read_path_out_cnt == zeroExtend(get_msg_bit_len(reg_page_num2))*4);
		read_path_out_cnt <= 0;
		$display("[%d][Page:%d][%d] Read error cnt: %d", cycle, reg_page_num2, reg_frm_num2, reg_error_cnt);
		reg_error_cnt <= 0; 
                if (reg_frm_num2 < fromInteger(valueOf(MAX_FRM_CNT)-1)) begin
                        reg_frm_num2 <= reg_frm_num2 + 1;
                end
                else begin
                        reg_frm_num2 <= 0;
			if (reg_page_num2 < 6)
                        	reg_page_num2 <= reg_page_num2 + 1;
			else
				reg_page_num2 <= 0;
                end
		
	endrule
	
        rule cycleCount (cycle > 0);
                cycle <= cycle + 1;
		if (cycle == 2000000) begin
		//	$display("Cycle: %d", cycle);	
			$finish();
		end
               // $display("%d", cycle);
        endrule


endmodule: mkTb
endpackage: Tb

