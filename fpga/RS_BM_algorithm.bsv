package RS_BM_algorithm;
import Vector::*;
import FIFO::*;
import SpecialFIFOs::*;
import RS_common::*;

interface RSBMAlgorithmIfc;
        method Action load_syndrome(SYNDROME syndrome);
        method ActionValue#(POLYNOMIAL) get_err_loc_poly();
	method ActionValue#(POLYNOMIAL) get_err_eval_poly();
endinterface: RSBMAlgorithmIfc

(* synthesize, options = "-no-aggressive-conditions" *)
module mkRSBMAlgorithm(RSBMAlgorithmIfc);
        FIFO#(SYNDROME) fifo_syndrome_in <- mkFIFO1;
        FIFO#(POLYNOMIAL) fifo_err_loc_poly_out <- mkFIFO1;
        FIFO#(POLYNOMIAL) fifo_err_eval_poly_out <- mkFIFO1;

	Reg#(POLY_IDX) reg_L <- mkReg(0);
	Reg#(POLY_IDX) reg_l <- mkReg(0);
	Reg#(POLYNOMIAL) reg_lambda <- mkReg(replicate(0));
	Reg#(POLYNOMIAL) reg_lambda_prev <- mkReg(replicate(0));
        Reg#(POLYNOMIAL) reg_omega <- mkReg(replicate(0));
        Reg#(POLYNOMIAL) reg_omega_prev <- mkReg(replicate(0));
	Reg#(POLY_IDX) reg_j <- mkReg(0);

	Reg#(SYMBOL) reg_d_m <- mkReg(0);
	FIFO#(SYMBOL) fifo_discrepancy <- mkFIFO1;
	FIFO#(POLYNOMIAL) fifo_delta_lambda <- mkFIFO1;
	FIFO#(POLYNOMIAL) fifo_delta_omega <- mkFIFO1;

	rule initialize (reg_j == 0);
		POLYNOMIAL initial_poly = replicate(0);
		initial_poly[0] = 1;
		reg_lambda <= initial_poly;
                reg_lambda_prev <= initial_poly;
                reg_omega <= replicate(0);
                reg_omega_prev <= initial_poly;
		reg_L <= 0;
		reg_l <= 1;
		reg_d_m <= 1;
		reg_j <= 1;
	endrule		

	rule compute_discrepancy (reg_j > 0);
		let syndrome = fifo_syndrome_in.first;
		//$display("[%d] %d, %d, %d, %d, %d, %d, %d, %d", reg_j, syndrome[0],  syndrome[1], syndrome[2], syndrome[3], syndrome[4], syndrome[5], syndrome[6], syndrome[7]);
		UInt#(8) rotate_val = fromInteger(valueOf(DOUBLE_T_RS)) - unpack(pack(reg_j));
                let syndrome_selected = reverse(shiftOutFromN(0, syndrome, rotate_val));
                //$display("Rotate value = %d, %b", rotate_val, syndrome_selected);     
                SYMBOL discrepancy = 0;
                //for (POLY_IDX i=0 ; i<reg_poly_degree_k ; i=i+1) begin
                for (POLY_IDX i=0 ; i<fromInteger(valueOf(DOUBLE_T_RS)) ; i=i+1) begin
                        discrepancy = discrepancy ^ gf_mul_m6(reg_lambda[i], syndrome_selected[i]);
                end	
		//$display("[%d] %d %d", reg_j, discrepancy, reg_L);	
		fifo_discrepancy.enq(discrepancy);
	endrule

	rule update_polynomials_z_d (reg_j > 0 && fifo_discrepancy.first == 0);
		if (reg_j == fromInteger(valueOf(DOUBLE_T_RS))) begin
			fifo_err_loc_poly_out.enq(reg_lambda);
			fifo_err_eval_poly_out.enq(reg_omega);
			fifo_syndrome_in.deq();	
			reg_j <= 0;
		end
		else begin
			reg_l <= reg_l + 1;
			reg_j <= reg_j + 1;
		end
		fifo_discrepancy.deq();
	endrule

        rule update_polynomials_nz (reg_j > 0 && fifo_discrepancy.first != 0);
		let discrepancy = fifo_discrepancy.first;
		SYMBOL factor = gf_mul_m6(discrepancy, gf_inv(reg_d_m));
		//$display("[%d] d*inv(d_m)=%d", reg_j, factor);
		POLYNOMIAL delta_lambda = replicate(0);
		POLYNOMIAL delta_omega = replicate(0);
		for (Integer i=0 ; i<fromInteger(valueOf(DOUBLE_T_RS)) ; i=i+1) begin
			delta_lambda[i] = gf_mul_m6(factor, reg_lambda_prev[i]);
			delta_omega[i] = gf_mul_m6(factor, reg_omega_prev[i]);
		end
		fifo_delta_lambda.enq(delta_lambda);
		fifo_delta_omega.enq(delta_omega);
        endrule

        rule update_polynomials_nz_g (reg_j > 0 && fifo_discrepancy.first != 0 && (reg_L << 1) > reg_j);
		let delta_lambda = shiftOutFromN(0, fifo_delta_lambda.first, reg_l); fifo_delta_lambda.deq();
                let delta_omega = shiftOutFromN(0, fifo_delta_omega.first, reg_l); fifo_delta_omega.deq();
		POLYNOMIAL lambda_tmp = reg_lambda;
		POLYNOMIAL omega_tmp = reg_omega;
		for (Integer i=0 ; i<fromInteger(valueOf(DOUBLE_T_RS)) ; i=i+1) begin
			lambda_tmp[i] = lambda_tmp[i] ^ delta_lambda[i];
			omega_tmp[i] = omega_tmp[i] ^ delta_omega[i];
		end
		reg_lambda <= lambda_tmp;
		reg_omega <= omega_tmp;

                if (reg_j == fromInteger(valueOf(DOUBLE_T_RS))) begin
                        fifo_err_loc_poly_out.enq(lambda_tmp);
                        fifo_err_eval_poly_out.enq(omega_tmp);
			fifo_syndrome_in.deq();
                        reg_j <= 0;
                end
                else begin
                        reg_l <= reg_l + 1;
                        reg_j <= reg_j + 1;
                end
                fifo_discrepancy.deq();
        endrule

        rule update_polynomials_nz_le (reg_j > 0 && fifo_discrepancy.first != 0 && (reg_L << 1) <= reg_j);

                let delta_lambda = shiftOutFromN(0, fifo_delta_lambda.first, reg_l); fifo_delta_lambda.deq();
                let delta_omega = shiftOutFromN(0, fifo_delta_omega.first, reg_l); fifo_delta_omega.deq();
                POLYNOMIAL lambda_tmp = reg_lambda;
                POLYNOMIAL omega_tmp = reg_omega;
                for (Integer i=0 ; i<fromInteger(valueOf(DOUBLE_T_RS)) ; i=i+1) begin
                        lambda_tmp[i] = lambda_tmp[i] ^ delta_lambda[i];
                        omega_tmp[i] = omega_tmp[i] ^ delta_omega[i];
                end
                reg_lambda <= lambda_tmp;
                reg_omega <= omega_tmp;

		reg_lambda_prev <= reg_lambda;
		reg_omega_prev <= reg_omega;

                if (reg_j == fromInteger(valueOf(DOUBLE_T_RS))) begin
                        fifo_err_loc_poly_out.enq(lambda_tmp);
                        fifo_err_eval_poly_out.enq(omega_tmp);
			fifo_syndrome_in.deq();
                        reg_j <= 0;
                end
                else begin
                        reg_l <= 1;
                        reg_j <= reg_j + 1;
			reg_d_m <= fifo_discrepancy.first;
			reg_L <= reg_j - reg_L;
                end
                fifo_discrepancy.deq();
        endrule

        method Action load_syndrome(SYNDROME syndrome);
		fifo_syndrome_in.enq(syndrome);
	endmethod

        method ActionValue#(POLYNOMIAL) get_err_loc_poly();
		let err_loc_poly_out = fifo_err_loc_poly_out.first;
		fifo_err_loc_poly_out.deq();
		return err_loc_poly_out;
	endmethod

        method ActionValue#(POLYNOMIAL) get_err_eval_poly();
		let err_eval_poly_out = fifo_err_eval_poly_out.first;
                fifo_err_eval_poly_out.deq();
                return err_eval_poly_out;
	endmethod

endmodule: mkRSBMAlgorithm

endpackage: RS_BM_algorithm

