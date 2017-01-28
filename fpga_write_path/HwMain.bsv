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

import test_write_path::*;

interface HwMainIfc;
endinterface

module mkHwMain#(PcieUserIfc pcie) 
	(HwMainIfc);

	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;

	Clock pcieclk = pcie.user_clk;
	Reset pcierst = pcie.user_rst;

        Reg#(UInt#(32)) reg_wl_cnt <- mkSyncReg(0, curClk, curRst, pcieclk);
        Reg#(Vector#(7, UInt#(32))) reg_enc_err_cnt <- mkSyncReg(replicate(0), curClk, curRst, pcieclk);

	FIFO#(IOReadReq) fifo_io_read_req <- mkFIFO1(clocked_by pcieclk, reset_by pcierst);

	TestWritePathIfc test_write_path <- mkTestWritePath(clocked_by curClk, reset_by curRst);


        rule save_frm_err_prob;
                let enc_err_prob <- test_write_path.get_enc_err_prob();
                reg_wl_cnt <= enc_err_prob.wl_cnt;
		reg_enc_err_cnt <= enc_err_prob.enc_err_cnt;
        endrule

	rule sendResult;
		// read request handle must be returned with pcie.dataSend
		let r <- pcie.dataReq;
		let addr = (r.addr >> 2);

		// PCIe IO is done at 4 byte granularities
		// lower 2 bits are always zero
		fifo_io_read_req.enq(r);
	endrule
	
	rule send_wl_cnt ((fifo_io_read_req.first.addr >> 2) == 7);
		pcie.dataSend(fifo_io_read_req.first, pack(reg_wl_cnt));
		fifo_io_read_req.deq();
	endrule
	
	for(Integer i=0 ; i<7 ; i=i+1) begin
        	rule send_enc_err ((fifo_io_read_req.first.addr >> 2) == fromInteger(i));
			let enc_err_cnt = reg_enc_err_cnt;
			pcie.dataSend(fifo_io_read_req.first, pack(enc_err_cnt[i]));
			fifo_io_read_req.deq();
        	endrule
	end
	
endmodule
