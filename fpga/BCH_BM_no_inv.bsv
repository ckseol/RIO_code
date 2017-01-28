package BCH_BM_no_inv;

import FIFO::*;
import SpecialFIFOs::*;
import Vector::*;
import BCH_common::*;

interface BMAlgorithmIfc;
        method Action load_syndrome(SYNDROME syndrome);
        method ActionValue#(POLYNOMIAL) get_err_loc_poly();
endinterface: BMAlgorithmIfc

(* synthesize, options = "-no-aggressive-conditions" *)
module mkBMAlgorithm(BMAlgorithmIfc);
	FIFO#(SYNDROME) fifo_syndrome_in <- mkFIFO1;
	FIFO#(POLYNOMIAL) fifo_err_loc_poly_out <- mkFIFO1;

	Reg#(POLYNOMIAL) reg_sigma_k <- mkRegU;
	Reg#(POLYNOMIAL) reg_sigma_rho <- mkRegU;
	FIFO#(GF_SYM)	 fifo_discrepancy_k <- mkPipelineFIFO;
	Reg#(GF_SYM)	 reg_discrepancy_rho <- mkReg(0);
	Reg#(POLY_IDX)	 reg_poly_degree_k <- mkReg(0);
	Reg#(POLY_IDX)	 reg_two_k_minus_degree <- mkReg(0);
	Reg#(POLY_IDX)	 reg_two_rho_minus_degree <- mkReg(0);
	Reg#(POLY_IDX)	 reg_k <- mkReg(-1);

	FIFO#(POLYNOMIAL) fifo_discrepancy_intermediate <- mkFIFO1;
	FIFO#(POLYNOMIAL) fifo_delta_sigma_k <- mkFIFO1;
	FIFO#(POLYNOMIAL) fifo_d_sigma_rho <- mkFIFO1;

	rule initialize (reg_k == -1);
		POLYNOMIAL init_poly_val = replicate(0);
		init_poly_val[0] = 1;

		reg_sigma_k <= init_poly_val;
		reg_sigma_rho <= init_poly_val;
 
		reg_poly_degree_k <= 0;
		reg_two_k_minus_degree <= 0;

		reg_two_rho_minus_degree <= -1;
		reg_discrepancy_rho <= 1;
		
		reg_k <= reg_k + 1;
	endrule

	rule compute_discrepancy_k_step1 (reg_k >= 0);
		let syndrome = fifo_syndrome_in.first;
		UInt#(6) rotate_val = fromInteger(valueOf(DOUBLE_T_BCH)) - (unpack(pack(reg_k)) << 1) - 1;
		let syndrome_selected = reverse(shiftOutFromN(0, syndrome, rotate_val));
		//$display("Rotate value = %d, %b", rotate_val, syndrome_selected);	
		POLYNOMIAL discrepancy_intermediate = replicate(0);
		//for (POLY_IDX i=0 ; i<reg_poly_degree_k ; i=i+1) begin
                for (POLY_IDX i=0 ; i<fromInteger(valueOf(T_BCH)) ; i=i+1) begin
			discrepancy_intermediate[i] = gf_mul(reg_sigma_k[i], syndrome_selected[i]);
		end
		fifo_discrepancy_intermediate.enq(discrepancy_intermediate);
	endrule

	rule compute_discrepancy_k_step2 (reg_k >= 0);
                let discrepancy_intermediate = fifo_discrepancy_intermediate.first;
		GF_SYM discrepancy_k = foldl(gf_add, 0, discrepancy_intermediate);
		fifo_discrepancy_k.enq(discrepancy_k);
		//$display("[k=%d] Discrepancy_k = %b", reg_k, discrepancy_k);
		//$display("Sigma_k = %b", reg_sigma_k);
		//$display("Polynomial degree = %d", reg_poly_degree_k);
        endrule


	rule update_err_loc_poly_nz_step1 (reg_k >= 0 && fifo_discrepancy_k.first != 0);
		let discrepancy_k = fifo_discrepancy_k.first;
		POLYNOMIAL d_sigma_rho = replicate(0);
		POLYNOMIAL delta_sigma_k = replicate(0);
		for (POLY_IDX i=1 ; i<=fromInteger(valueOf(T_BCH)) ; i=i+1) begin
			d_sigma_rho[i] = gf_mul(reg_sigma_rho[i-1], discrepancy_k);
		end
                for (POLY_IDX i=0 ; i<=fromInteger(valueOf(T_BCH)) ; i=i+1) begin
                        delta_sigma_k[i] = gf_mul(reg_sigma_k[i], reg_discrepancy_rho);
                end	
		//$display("d sigma rho: %b", d_sigma_rho);
		//$display("delta sigma k: %b", delta_sigma_k);
					
		fifo_d_sigma_rho.enq(d_sigma_rho);
		fifo_delta_sigma_k.enq(delta_sigma_k);
	endrule

	function Bool isNonzero (GF_SYM a);
		return (a != 0);
	endfunction

        rule update_err_loc_poly_nz_step2 (reg_k >= 0 && fifo_discrepancy_k.first != 0);
		let d_sigma_rho = fifo_d_sigma_rho.first; fifo_d_sigma_rho.deq();
		let delta_sigma_k = fifo_delta_sigma_k.first; fifo_delta_sigma_k.deq();
		POLYNOMIAL sigma_k_updated = replicate(0);
		for (POLY_IDX i=0 ; i<=fromInteger(valueOf(T_BCH)) ; i=i+1) begin
			sigma_k_updated[i] = gf_add(d_sigma_rho[i], delta_sigma_k[i]);
		end
		let idx_reversed = fromMaybe(?, findIndex(isNonzero, reverse(sigma_k_updated)));
		POLY_IDX poly_degree_k = fromInteger(valueOf(T_BCH)) - zeroExtend(unpack(pack(idx_reversed)));
                //$display("Sigma update: %b", sigma_k_updated);
		//$display("%d, %d", idx_reversed, poly_degree_k);

		reg_sigma_k <= sigma_k_updated;
		reg_poly_degree_k <= poly_degree_k; 

		if (reg_two_k_minus_degree > reg_two_rho_minus_degree) begin
			reg_two_rho_minus_degree <= reg_two_k_minus_degree;
			reg_sigma_rho <= shiftOutFromN(0, reg_sigma_k, 1);
			reg_discrepancy_rho <= fifo_discrepancy_k.first;
		end
		else
			reg_sigma_rho <= shiftOutFromN(0, reg_sigma_rho, 2);
			
		fifo_discrepancy_k.deq();
		fifo_discrepancy_intermediate.deq();
                reg_two_k_minus_degree <= ((reg_k + 1) << 1) - poly_degree_k;
		if (reg_k == fromInteger(valueOf(T_BCH))) begin
			reg_k <= -1;
			fifo_err_loc_poly_out.enq(reg_sigma_k);
			fifo_syndrome_in.deq();
		end
		else
			reg_k <= reg_k + 1;
        endrule

	rule update_err_loc_poly_z (reg_k >= 0 && fifo_discrepancy_k.first == 0);
		POLYNOMIAL reg_sigma_k_updated = reg_sigma_k;
		for (POLY_IDX i=0 ; i<=fromInteger(valueOf(T_BCH)) ; i=i+1) begin
                        reg_sigma_k_updated[i] = gf_mul(reg_sigma_k_updated[i], reg_discrepancy_rho);
                end
		reg_sigma_k <= reg_sigma_k_updated;
		reg_sigma_rho <= shiftOutFromN(0, reg_sigma_rho, 2);
		reg_two_k_minus_degree <= ((reg_k + 1) << 1) - reg_poly_degree_k;
		fifo_discrepancy_intermediate.deq();
		fifo_discrepancy_k.deq();
                if (reg_k == fromInteger(valueOf(T_BCH))) begin
                        reg_k <= -1;
                        fifo_err_loc_poly_out.enq(reg_sigma_k);
                        fifo_syndrome_in.deq();
                end
                else
                        reg_k <= reg_k + 1;
	endrule		

        method Action load_syndrome(SYNDROME syndrome);
		fifo_syndrome_in.enq(syndrome);
	endmethod

        method ActionValue#(POLYNOMIAL) get_err_loc_poly();
		let elp = fifo_err_loc_poly_out.first; 
		fifo_err_loc_poly_out.deq();
		return elp;
	endmethod

endmodule: mkBMAlgorithm

endpackage: BCH_BM_no_inv

