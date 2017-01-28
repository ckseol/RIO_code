import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import FIFOLevel::*;
import Clocks::*;
import Vector::*;

import BRAM::*;
import BRAMFIFO::*;

import PcieCtrl::*;

import DMASplitter::*;

import test_read_path::*;

interface HwMainIfc;
endinterface

module mkHwMain#(PcieUserIfc pcie) 
	(HwMainIfc);

	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;

	Clock pcieclk = pcie.user_clk;
	Reset pcierst = pcie.user_rst;

        Reg#(UInt#(32)) reg_frm_err_cnt <- mkSyncReg(0, curClk, curRst, pcieclk);
        Reg#(UInt#(32)) reg_frm_cnt_l <- mkSyncReg(0, curClk, curRst, pcieclk);
	Reg#(UInt#(32)) reg_frm_cnt_m <- mkSyncReg(0, curClk, curRst, pcieclk);
        //Reg#(UInt#(32)) reg_frm_err_cnt <- mkReg(0, clocked_by curClk, reset_by curRst));
        //Reg#(UInt#(32)) reg_frm_cnt <- mkReg(0, clocked_by curClk, reset_by curRst));

	SyncFIFOIfc#(Bit#(32)) fifo_user_write <- mkSyncFIFO(1, pcieclk, pcierst, curClk);
	FIFO#(IOReadReq) fifo_io_read_req <- mkFIFO1(clocked_by pcieclk, reset_by pcierst);

	TestReadPathIfc test_read_path <- mkTestReadPath(clocked_by curClk, reset_by curRst);

	FIFO#(UInt#(2)) fifo_cmd_w_arg <- mkFIFO1(clocked_by curClk, reset_by curRst);	

        rule process_cmd_set_page (fifo_user_write.first == 1);
		fifo_user_write.deq();
		fifo_cmd_w_arg.enq(1);
              	//test_read_path.set_page_num(truncate(unpack(reg_arg)));
        endrule

	rule process_cmd_set_page1 (fifo_cmd_w_arg.first == 1);
		fifo_cmd_w_arg.deq();
		test_read_path.set_page_num(truncate(unpack(fifo_user_write.first)));
		fifo_user_write.deq();
	endrule

        rule process_cmd_set_err_threshold (fifo_user_write.first == 2);
		fifo_user_write.deq();
		fifo_cmd_w_arg.enq(2);
                //test_read_path.set_err_threshold(unpack(reg_arg));
        endrule

        rule process_cmd_set_err_threshold1 (fifo_cmd_w_arg.first == 2);
		fifo_cmd_w_arg.deq();
                test_read_path.set_err_threshold(unpack(fifo_user_write.first));
		fifo_user_write.deq();
        endrule

        rule process_cmd_start_dec (fifo_user_write.first == 3);
		fifo_user_write.deq();
                test_read_path.start_dec();
        endrule

        rule process_cmd_stop_dec (fifo_user_write.first == 4);
		fifo_user_write.deq();
                test_read_path.stop_dec();
        endrule

        rule process_cmd_reset_sim (fifo_user_write.first == 5);
                fifo_user_write.deq();
                test_read_path.reset_sim();
        endrule

        rule save_frm_err_prob;
                let frm_err_prob = test_read_path.get_frm_err_prob();
		//$display("FRM ERR CNT: %d, FRM CNT: %d", frm_err_prob.frm_err_cnt, frm_err_prob.frm_cnt);
		Bit#(64) frm_cnt = pack(frm_err_prob.frm_cnt);
		reg_frm_err_cnt <= frm_err_prob.frm_err_cnt;
		//reg_frm_cnt u<= frm_err_prob.frm_cnt;
                reg_frm_cnt_l <= unpack(frm_cnt[31:0]);
		reg_frm_cnt_m <= unpack(frm_cnt[63:32]);
                //$display("Frame cnt=%d, frame error cnt=%d", frm_err_prob.frm_cnt, frm_err_prob.frm_err_cnt);
        endrule

	rule sendResult;
		// read request handle must be returned with pcie.dataSend
		let r <- pcie.dataReq;
		let addr = (r.addr >> 2);

		// PCIe IO is done at 4 byte granularities
		// lower 2 bits are always zero
		fifo_io_read_req.enq(r);
/*		
		if (addr == 0) begin
			pcie.dataSend(r, pack(reg_frm_err_cnt));
		end
                else if (addr == 1) begin
                        pcie.dataSend(r, pack(reg_frm_cnt));
                end
		
		else if (addr == 1) begin
			let frm_cnt = pack(reg_frm_cnt);
                        pcie.dataSend(r, frm_cnt[31:0]);		
		end
		else if (addr == 2) begin
                        let frm_cnt = pack(reg_frm_cnt);
                        pcie.dataSend(r, frm_cnt[63:32]);			
		end
		*/
	endrule
	
	rule sendFrmErrCnt ((fifo_io_read_req.first.addr >> 2) == 0);
		pcie.dataSend(fifo_io_read_req.first, pack(reg_frm_err_cnt));
		fifo_io_read_req.deq();
	endrule

        rule sendFrmCntL ((fifo_io_read_req.first.addr >> 2) == 1);
		pcie.dataSend(fifo_io_read_req.first, pack(reg_frm_cnt_l));
		fifo_io_read_req.deq();
        endrule

        rule sendFrmCntM ((fifo_io_read_req.first.addr >> 2) == 2);
                pcie.dataSend(fifo_io_read_req.first, pack(reg_frm_cnt_m));
                fifo_io_read_req.deq();
        endrule

	rule recvWrite;
		let w <- pcie.dataReceive;
		let a = w.addr;
		let d = w.data;
		$display("%d", d);
		fifo_user_write.enq(d);
		
		// PCIe IO is done at 4 byte granularities
		// lower 2 bits are always zero
		/*
		if ( (a>>2) == 0 ) begin
			reg_cmd <= d;
			$display("Cmd: %d", d);
		end
                else if ( (a>>2) == 1 ) begin
                        reg_arg <= d;
                        $display("Arg: %d", d);
                end*/
	
	endrule
	
endmodule
